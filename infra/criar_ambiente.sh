#!/usr/bin/env bash
# Cria a VM do curso. Rode no Azure Cloud Shell (Bash), de dentro da pasta do material:
#   bash infra/criar_ambiente.sh SEU_IP
# Descubra SEU_IP abrindo https://ifconfig.me no navegador do seu computador.
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

MEU_IP="${1:-}"
if [[ ! "$MEU_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "Uso: bash infra/criar_ambiente.sh SEU_IP   (ex.: 177.20.30.40)"
  echo "Descubra seu IP em https://ifconfig.me (no navegador do SEU computador, não no Cloud Shell)."
  exit 1
fi

TOKEN="$(openssl rand -hex 12)"
echo ">> Registrando provedores (só demora na primeira vez)..."
az provider register --namespace Microsoft.Compute --wait >/dev/null
az provider register --namespace Microsoft.Network --wait >/dev/null
az provider register --namespace Microsoft.Storage --wait >/dev/null

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

echo ">> Criando VM $VM ($SIZE). Leva de 2 a 4 minutos..."
az vm create -g "$RG" -n "$VM" \
  --image Ubuntu2404 --size "$SIZE" \
  --admin-username "$ADMIN_USER" --generate-ssh-keys \
  --os-disk-size-gb "$DISK_GB" --storage-sku StandardSSD_LRS \
  --public-ip-sku Standard --nsg-rule NONE \
  --custom-data "$CLOUD_INIT" -o none
rm -f "$CLOUD_INIT"

echo ">> Liberando as portas do curso só para o IP $MEU_IP..."
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n libera-aluno \
  --priority 1000 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes "$MEU_IP/32" --destination-port-ranges $PORTAS -o none

echo ">> Agendando desligamento automático diário (${AUTO_SHUTDOWN_UTC} UTC)..."
az vm auto-shutdown -g "$RG" -n "$VM" --time "$AUTO_SHUTDOWN_UTC" -o none

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
