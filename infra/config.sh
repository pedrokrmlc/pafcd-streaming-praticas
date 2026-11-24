# Configuração compartilhada pelos scripts de infraestrutura.
# Qualquer valor pode ser sobrescrito com variável de ambiente, por exemplo:
#   LOCATION=westus2 bash infra/criar_ambiente.sh 200.150.10.20

RG="${RG:-rg-streaming}"                 # grupo de recursos (apagar o grupo apaga tudo)
VM="${VM:-vm-streaming}"                 # nome da VM
LOCATION="${LOCATION:-eastus2}"          # região (veja docs/solucao_de_problemas.md se der erro de política)
SIZE="${SIZE:-Standard_B2ms}"            # 2 vCPU / 8 GB RAM (primeira tentativa)
# Se o tamanho pedido estiver sem capacidade, o script tenta estes (todos com 2 vCPU / 8 GB):
TAMANHOS_ALTERNATIVOS="Standard_B2as_v2 Standard_B2s_v2 Standard_D2as_v5 Standard_D2s_v5 Standard_D2as_v4 Standard_D2s_v4"
ADMIN_USER="${ADMIN_USER:-aluno}"
DISK_GB="${DISK_GB:-32}"
AUTO_SHUTDOWN_UTC="${AUTO_SHUTDOWN_UTC:-0300}"   # 03:00 UTC = 00:00 em Brasília
NSG="${VM}NSG"
PORTAS="8888 8080 3000 4040-4045"        # Jupyter, Kafka UI, Grafana, Spark UI

# Executa um comando dentro da VM sem SSH (usa o agente da própria Azure).
na_vm() {
  az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
    --scripts "$1" --query "value[0].message" -o tsv
}

ip_publico() {
  az vm show -d -g "$RG" -n "$VM" --query publicIps -o tsv
}

# ---- Envio do material sem repositório Git ------------------------------------
# O material é empacotado (sem a pasta gabaritos/), enviado para um Storage Account
# privado dentro do mesmo grupo de recursos e baixado pela VM com um link temporário (SAS).
storage_nome() {
  # nome único e estável por assinatura (3-24 caracteres, minúsculas e números)
  echo "streaming$(az account show --query id -o tsv | md5sum | cut -c1-12)"
}

# Empacota a pasta atual, envia e imprime a URL temporária de download (válida por 1 dia).
enviar_pacote() {
  local sa key exp arq
  sa="$(storage_nome)"
  if ! az storage account show -n "$sa" -g "$RG" -o none 2>/dev/null; then
    echo ">> Criando armazenamento $sa para o material..." >&2
    az provider register --namespace Microsoft.Storage --wait >/dev/null
    az storage account create -n "$sa" -g "$RG" -l "$LOCATION" --sku Standard_LRS \
      --min-tls-version TLS1_2 --allow-blob-public-access false -o none
  fi
  key="$(az storage account keys list -n "$sa" -g "$RG" --query "[0].value" -o tsv)"
  az storage container create --account-name "$sa" --account-key "$key" -n material -o none
  arq="$(mktemp --suffix .tgz)"
  tar czf "$arq" --exclude=./gabaritos --exclude=./.git --exclude='*.zip' -C "$(pwd)" .
  echo ">> Enviando material ($(du -h "$arq" | cut -f1))..." >&2
  az storage blob upload --account-name "$sa" --account-key "$key" -c material -n material.tgz \
    -f "$arq" --overwrite -o none --only-show-errors
  rm -f "$arq"
  exp="$(date -u -d '+1 day' '+%Y-%m-%dT%H:%MZ')"
  local sas
  sas="$(az storage blob generate-sas --account-name "$sa" --account-key "$key" -c material \
    -n material.tgz --permissions r --expiry "$exp" --https-only -o tsv)"
  echo "https://$sa.blob.core.windows.net/material/material.tgz?$sas"
}

# ---- Região permitida ----------------------------------------------------------
# Assinaturas como a Azure for Students só aceitam algumas regiões (política
# "Allowed resource deployment regions"). Devolve as regiões permitidas, uma por linha
# (vazio = sem restrição encontrada).
regioes_permitidas() {
  local todas
  todas="$(az account list-locations --query "[].name" -o tsv)"
  az policy assignment list --disable-scope-strict-match --query "[].parameters" -o json 2>/dev/null \
    | TODAS="$todas" python3 -c '
import json, os, sys
todas = set(os.environ["TODAS"].split())
achadas = set()
def andar(x):
    if isinstance(x, dict):
        for v in x.values(): andar(v)
    elif isinstance(x, list):
        for v in x: andar(v)
    elif isinstance(x, str) and x.lower() in todas:
        achadas.add(x.lower())
andar(json.load(sys.stdin) or [])
print("\n".join(sorted(achadas)))'
}

# Regiões candidatas, na ordem de tentativa: LOCATION primeiro, depois as outras permitidas.
regioes_candidatas() {
  local permitidas r
  permitidas="$(regioes_permitidas)"
  echo "$LOCATION"
  [[ -z "$permitidas" ]] && return
  for r in brazilsouth eastus eastus2 southcentralus centralus westus2 westus3 northcentralus canadacentral $permitidas; do
    grep -qx "$r" <<<"$permitidas" && echo "$r"
  done | awk -v l="$LOCATION" '$0 != l && !seen[$0]++' | head -4
}

# Apaga o que uma tentativa de criar a VM deixou pela metade (mantém o armazenamento do material).
limpar_vm_parcial() {
  local tipo ids
  for tipo in Microsoft.Compute/virtualMachines Microsoft.Compute/disks Microsoft.Network/networkInterfaces \
              Microsoft.Network/publicIPAddresses Microsoft.Network/networkSecurityGroups Microsoft.Network/virtualNetworks; do
    ids="$(az resource list -g "$RG" --resource-type "$tipo" --query "[].id" -o tsv)"
    [[ -n "$ids" ]] && az resource delete --ids $ids -o none 2>/dev/null || true
  done
}

# Escolhe LOCATION: mantém a pedida se for permitida; senão, a primeira permitida da lista de preferência.
escolher_regiao() {
  local permitidas preferidas r
  permitidas="$(regioes_permitidas)"
  if [[ -z "$permitidas" ]] || grep -qx "$LOCATION" <<<"$permitidas"; then
    return
  fi
  preferidas="brazilsouth eastus eastus2 southcentralus centralus westus2 westus3 northcentralus canadacentral"
  for r in $preferidas; do
    if grep -qx "$r" <<<"$permitidas"; then LOCATION="$r"; break; fi
  done
  if ! grep -qx "$LOCATION" <<<"$permitidas"; then LOCATION="$(head -1 <<<"$permitidas")"; fi
  echo ">> Sua assinatura só permite: $(tr '\n' ' ' <<<"$permitidas")" >&2
  echo ">> Usando a região $LOCATION" >&2
}
