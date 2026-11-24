#!/usr/bin/env bash
# Envia para a VM o material desta pasta (por exemplo, a versão nova que o professor mandou).
# Arquivos NOVOS são adicionados; arquivos que já existem na VM (como os notebooks que você
# editou) NÃO são sobrescritos; se houver conflito, nada é alterado. Use --sobrescrever para substituir tudo.
#   bash infra/atualizar_material.sh
#   bash infra/atualizar_material.sh --sobrescrever
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/config.sh

MODO="--skip-old-files"
[[ "${1:-}" == "--sobrescrever" ]] && MODO="--overwrite"

if git remote get-url origin >/dev/null 2>&1; then
  if [[ "$MODO" == "--overwrite" ]]; then
    na_vm "cd /opt/streaming && git fetch -q origin && git reset -q --hard origin/HEAD && chown -R 1000:1000 notebooks && echo MATERIAL ATUALIZADO: && git log --oneline -1"
  else
    na_vm "cd /opt/streaming && if git pull -q --ff-only; then chown -R 1000:1000 notebooks; echo MATERIAL ATUALIZADO: && git log --oneline -1; else echo; echo 'NAO ATUALIZADO: voce alterou arquivos na VM (por exemplo, notebooks salvos com saidas).'; echo 'Para substituir pelos do repositorio, rode: bash infra/atualizar_material.sh --sobrescrever'; fi"
  fi
else
  URL="$(enviar_pacote)"
  na_vm "curl -fsSL --retry 5 '$URL' | tar xz $MODO -C /opt/streaming && chown -R 1000:1000 /opt/streaming/notebooks && echo MATERIAL ATUALIZADO"
fi
echo ">> Pronto. Atualize a página do Jupyter."
