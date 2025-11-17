#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_STACK="$ROOT_DIR/tools/admin/rag_cli.sh"

log() {
  echo "[rag_wizard] $*"
}

# Procura gum no PATH ou em ./bin/gum
find_gum() {
  if command -v gum >/dev/null 2>&1; then
    echo "gum"
    return 0
  fi
  if [ -x "$ROOT_DIR/bin/gum" ]; then
    echo "$ROOT_DIR/bin/gum"
    return 0
  fi
  return 1
}

main_menu() {
  clear
  local gum
  if ! gum=$(find_gum); then
    log "gum não encontrado. Instale gum (https://github.com/charmbracelet/gum) ou coloque o binário em ./bin/gum."
    log "Depois rode: ./tools/admin/rag_wizard.sh"
    exit 1
  fi

  "$gum" style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "Shantilly RAG - Wizard"

  local choice
  choice=$(
    "$gum" choose --padding "2 4" \
      --header "Escolha uma opção:" \
      "1) Onboarding inicial" \
      "2) Preparar/atualizar base (ingest)" \
      "3) Subir servidor dev" \
      "4) Rodar avaliação RAG" \
      "5) Instalar Qdrant local" \
      "6) Instalar serviço dev (systemd)" \
      "7) Sair"
  ) || exit 0

  case "$choice" in
    "1) Onboarding inicial")
      onboarding_flow
      ;;
    "2) Preparar/atualizar base (ingest)")
      "$RUN_STACK" ingest
      ;;
    "3) Subir servidor dev")
      "$RUN_STACK" dev
      ;;
    "4) Rodar avaliação RAG")
      "$RUN_STACK" eval
      ;;
    "5) Instalar Qdrant local")
      "$RUN_STACK" install-qdrant
      ;;
    "6) Instalar serviço dev (systemd)")
      "$RUN_STACK" install-rag-service
      ;;
    *)
      clear
      exit 0
      ;;
  esac
}

onboarding_flow() {
  local gum
  gum=$(find_gum)

  "$gum" spin --title "Checando/inicializando ambiente Python" -- \
    "$RUN_STACK" ingest || return 1

  "$gum" confirm "Deseja instalar/configurar serviço dev (systemd) agora?" && \
    "$RUN_STACK" install-rag-service || true

  "$gum" confirm "Deseja rodar uma avaliação RAG agora?" && \
    "$RUN_STACK" eval || true
}

main_menu
