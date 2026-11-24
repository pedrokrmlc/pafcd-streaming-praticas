#!/usr/bin/env bash
# Mostra de novo os endereços e o token (lidos de dentro da VM).
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

IP="$(ip_publico)"
TOKEN="$(na_vm 'grep JUPYTER_TOKEN /etc/streaming.env | cut -d= -f2' | grep -Eo '[0-9a-f]{24}' | head -1)"
echo "Jupyter : http://$IP:8888/lab?token=$TOKEN"
echo "Kafka UI: http://$IP:8080   (aluno / $TOKEN)"
echo "Grafana : http://$IP:3000   (admin / $TOKEN)"
