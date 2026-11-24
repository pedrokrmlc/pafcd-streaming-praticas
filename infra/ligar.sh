#!/usr/bin/env bash
# Liga a VM no início da aula. Os containers sobem sozinhos (restart: unless-stopped).
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

echo ">> Ligando $VM..."
az vm start -g "$RG" -n "$VM" -o none
IP="$(ip_publico)"
echo ">> VM ligada. Aguarde ~1 minuto para os containers subirem."
echo "   Jupyter: http://$IP:8888/lab   Kafka UI: http://$IP:8080   Grafana: http://$IP:3000"
echo "   Mudou de rede (casa/faculdade)? Rode: bash infra/liberar_ip.sh SEU_NOVO_IP"
