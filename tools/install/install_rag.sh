#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_NAME="rag.service"
SERVICE_SRC="$ROOT_DIR/tools/templates/service/$SERVICE_NAME"
SERVICE_DST="/etc/systemd/system/$SERVICE_NAME"

if [ ! -f "$SERVICE_SRC" ]; then
  echo "[install_rag_service] Arquivo de serviço não encontrado: $SERVICE_SRC" >&2
  exit 1
fi

echo "[install_rag_service] Copiando $SERVICE_SRC para $SERVICE_DST (requer sudo)"
sudo cp "$SERVICE_SRC" "$SERVICE_DST"

echo "[install_rag_service] Recarregando systemd"
sudo systemctl daemon-reload

echo "[install_rag_service] Habilitando e iniciando $SERVICE_NAME"
sudo systemctl enable --now "$SERVICE_NAME"

echo "[install_rag_service] Status do serviço:"
sudo systemctl status "$SERVICE_NAME" --no-pager
