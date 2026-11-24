#!/usr/bin/env bash
# Roda um comando dentro da VM, sem SSH. Exemplos usados nas aulas:
#   bash infra/vm.sh "docker stop kafka2"      # derruba um broker
#   bash infra/vm.sh "docker start kafka2"     # religa
#   bash infra/vm.sh "docker compose -f /opt/streaming/ambiente/docker-compose.yml logs --tail 50 jupyter"
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

[[ $# -ge 1 ]] || { echo 'Uso: bash infra/vm.sh "comando"'; exit 1; }
na_vm "$*"
