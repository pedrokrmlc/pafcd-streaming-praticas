# Configuração compartilhada pelos scripts de infraestrutura.
# Qualquer valor pode ser sobrescrito com variável de ambiente, por exemplo:
#   LOCATION=westus2 bash infra/criar_ambiente.sh 200.150.10.20

RG="${RG:-rg-streaming}"                 # grupo de recursos (apagar o grupo apaga tudo)
VM="${VM:-vm-streaming}"                 # nome da VM
LOCATION="${LOCATION:-eastus2}"          # região (veja docs/solucao_de_problemas.md se der erro de política)
SIZE="${SIZE:-Standard_B2ms}"            # 2 vCPU / 8 GB RAM. Alternativas: Standard_D2as_v5, Standard_D2s_v5
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
