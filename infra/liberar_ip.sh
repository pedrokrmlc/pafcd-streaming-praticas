#!/usr/bin/env bash
# Atualiza o IP autorizado a acessar a VM (use quando trocar de rede).
#   bash infra/liberar_ip.sh SEU_NOVO_IP
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

MEU_IP="${1:-}"
[[ "$MEU_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || { echo "Uso: bash infra/liberar_ip.sh SEU_IP (veja em https://ifconfig.me)"; exit 1; }
az network nsg rule update -g "$RG" --nsg-name "$NSG" -n libera-aluno \
  --source-address-prefixes "$MEU_IP/32" -o none
echo ">> Acesso liberado para $MEU_IP."
