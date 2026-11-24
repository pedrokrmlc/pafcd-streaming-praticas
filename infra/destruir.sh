#!/usr/bin/env bash
# Apaga TUDO (VM, disco, IP, rede). Use no fim da disciplina.
# Baixe antes os notebooks que quiser guardar (Jupyter > botão direito > Download).
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

read -r -p "Isso apaga o grupo $RG e todos os seus dados. Digite APAGAR para confirmar: " RESP
[[ "$RESP" == "APAGAR" ]] || { echo "Cancelado."; exit 0; }
az group delete -n "$RG" --yes --no-wait
echo ">> Exclusão iniciada (leva alguns minutos). Nada mais será cobrado depois disso."
