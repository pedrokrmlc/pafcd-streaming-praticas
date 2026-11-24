#!/usr/bin/env bash
# Desaloca a VM: para de cobrar CPU/RAM. Disco e IP continuam (custo pequeno, ver docs/custos.md).
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

echo ">> Desligando (desalocando) $VM..."
az vm deallocate -g "$RG" -n "$VM" -o none
echo ">> Pronto. Seus notebooks e tópicos ficam salvos. Para voltar: bash infra/ligar.sh"
