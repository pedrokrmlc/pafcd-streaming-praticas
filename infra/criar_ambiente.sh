#!/usr/bin/env bash
# Cria a VM do curso. Rode no Azure Cloud Shell (Bash), de dentro da pasta do material:
#   bash infra/criar_ambiente.sh SEU_IP
# Descubra SEU_IP abrindo https://api.ipify.org no navegador do seu computador.
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

MEU_IP="${1:-}"
if [[ ! "$MEU_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "Uso: bash infra/criar_ambiente.sh SEU_IP   (ex.: 177.20.30.40)"
  echo "Descubra seu IP em https://api.ipify.org (no navegador do SEU computador, não no Cloud Shell)."
  exit 1
fi

TOKEN="$(openssl rand -hex 12)"
echo ">> Registrando provedores (só demora na primeira vez)..."
az provider register --namespace Microsoft.Compute --wait >/dev/null
az provider register --namespace Microsoft.Network --wait >/dev/null
az provider register --namespace Microsoft.Storage --wait >/dev/null

echo ">> Verificando as regiões permitidas na sua assinatura..."
escolher_regiao

# Um grupo vazio que sobrou de uma tentativa anterior em outra região é apagado
if [[ "$(az group exists -n "$RG")" == "true" ]]; then
  LOC_ATUAL="$(az group show -n "$RG" --query location -o tsv)"
  if [[ "$LOC_ATUAL" != "$LOCATION" ]]; then
    if [[ "$(az resource list -g "$RG" --query "length(@)" -o tsv)" == "0" ]]; then
      echo ">> Apagando o grupo vazio $RG que ficou em $LOC_ATUAL (tentativa anterior)..."
      az group delete -n "$RG" --yes
    else
      echo "O grupo $RG já existe em $LOC_ATUAL e tem recursos. Rode 'bash infra/destruir.sh' antes ou use LOCATION=$LOC_ATUAL."
      exit 1
    fi
  fi
fi

echo ">> Criando grupo de recursos $RG em $LOCATION..."
az group create -n "$RG" -l "$LOCATION" -o none

# De onde a VM vai pegar o material: repositório Git (se houver) ou pacote enviado daqui
REPO_URL="${REPO_URL:-$(git remote get-url origin 2>/dev/null || true)}"
if [[ -n "$REPO_URL" ]]; then
  echo ">> A VM vai clonar o repositório $REPO_URL"
  OBTER="git clone --depth 1 '$REPO_URL' /opt/streaming"
else
  echo ">> Sem repositório Git: enviando esta pasta para a Azure"
  URL_PACOTE="$(enviar_pacote)"
  OBTER="mkdir -p /opt/streaming && curl -fsSL --retry 5 '$URL_PACOTE' | tar xz -C /opt/streaming"
fi

CLOUD_INIT="$(mktemp)"
TOKEN="$TOKEN" ADMIN="$ADMIN_USER" OBTER="$OBTER" python3 - infra/cloud-init.tpl.yaml > "$CLOUD_INIT" <<'PY'
import os, sys
s = open(sys.argv[1]).read()
s = s.replace("__TOKEN__", os.environ["TOKEN"]).replace("__ADMIN__", os.environ["ADMIN"])
s = s.replace("__OBTER_MATERIAL__", "      set -e\n      " + os.environ["OBTER"])
print(s, end="")
PY

# Tenta tamanhos e regiões até achar capacidade disponível
CRIADA=""
LOG_VM="$(mktemp)"
for REGIAO in $(regioes_candidatas); do
  for TAM in $(echo "$SIZE $TAMANHOS_ALTERNATIVOS" | tr ' ' '\n' | awk '!seen[$0]++'); do
    echo ">> Tentando VM $TAM em $REGIAO (leva de 1 a 4 minutos)..."
    if az vm create -g "$RG" -n "$VM" -l "$REGIAO" \
        --image Ubuntu2404 --size "$TAM" \
        --admin-username "$ADMIN_USER" --generate-ssh-keys \
        --os-disk-size-gb "$DISK_GB" --storage-sku StandardSSD_LRS \
        --public-ip-sku Standard --nsg "$NSG" --nsg-rule NONE \
        --custom-data "$CLOUD_INIT" -o none --only-show-errors >"$LOG_VM" 2>&1; then
      CRIADA="$TAM em $REGIAO"; break 2
    fi
    if grep -qE "SkuNotAvailable|Capacity|QuotaExceeded|OperationNotAllowed|AllocationFailed|ZonalAllocationFailed|RequestDisallowedByAzure|NotAvailableForSubscription" "$LOG_VM"; then
      echo "   indisponível ($(grep -oE "SkuNotAvailable|QuotaExceeded|OperationNotAllowed|AllocationFailed|RequestDisallowedByAzure|NotAvailableForSubscription" "$LOG_VM" | head -1)); tentando a próxima opção"
      limpar_vm_parcial
    else
      echo "Erro inesperado ao criar a VM:"; tail -20 "$LOG_VM"; rm -f "$LOG_VM" "$CLOUD_INIT"; exit 1
    fi
  done
done
rm -f "$LOG_VM"
if [[ -z "$CRIADA" ]]; then
  rm -f "$CLOUD_INIT"
  echo "Nenhuma combinação de tamanho e região tinha capacidade agora. Tente de novo em alguns minutos."
  exit 1
fi
echo ">> VM criada: $CRIADA"
rm -f "$CLOUD_INIT"

echo ">> Liberando as portas do curso só para o IP $MEU_IP..."
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n libera-aluno \
  --priority 1000 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes "$MEU_IP/32" --destination-port-ranges $PORTAS -o none

echo ">> Agendando desligamento automático diário (${AUTO_SHUTDOWN_UTC} UTC)..."
az vm auto-shutdown -g "$RG" -n "$VM" --time "$AUTO_SHUTDOWN_UTC" --location "$REGIAO" -o none

IP="$(ip_publico)"
cat <<EOF

=====================================================================
 VM criada! O ambiente ainda está sendo montado lá dentro
 (instala Docker e constrói as imagens): espere de 8 a 12 minutos.
 Acompanhe com:  bash infra/status.sh

 Jupyter Lab : http://$IP:8888/lab?token=$TOKEN
 Kafka UI    : http://$IP:8080      (usuário: aluno  | senha: $TOKEN)
 Grafana     : http://$IP:3000      (usuário: admin  | senha: $TOKEN)

 ANOTE O TOKEN: $TOKEN
 (se perder, rode: bash infra/mostrar_acesso.sh)

 Ao final de CADA aula:  bash infra/desligar.sh
=====================================================================
EOF
