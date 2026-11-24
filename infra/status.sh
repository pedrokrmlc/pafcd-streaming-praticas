#!/usr/bin/env bash
# Mostra se o ambiente terminou de subir e o estado dos containers.
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

echo ">> Estado da VM: $(az vm get-instance-view -g "$RG" -n "$VM" --query "instanceView.statuses[1].displayStatus" -o tsv)"
na_vm 'if [ -f /opt/streaming/.pronto ]; then echo "AMBIENTE PRONTO"; else echo "Ainda montando... (cloud-init: $(cloud-init status | tr -d "\n"))"; fi
cd /opt/streaming/ambiente 2>/dev/null && docker compose ps --format "table {{.Name}}\t{{.Status}}"'
