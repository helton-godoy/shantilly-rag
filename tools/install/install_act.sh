#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )/../.." && pwd)"

log() {
  echo "[install_act] $*"
}

# Se houver um binário vendorizado em ./bin/act, considere-o como instalado
if [ -x "$ROOT_DIR/bin/act" ]; then
  log "act encontrado em $ROOT_DIR/bin/act. Nada a instalar."
  log "Dica: adicione \"$ROOT_DIR/bin\" ao seu PATH para usar esse binário diretamente."
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log "Este script é destinado a sistemas baseados em Debian (Debian/Ubuntu/Deepin) com apt-get."
  exit 1
fi

if command -v act >/dev/null 2>&1; then
  log "act já está instalado em $(command -v act). Nada a fazer."
  exit 0
fi

log "Instalando dependências básicas (curl, ca-certificates) se necessário"
sudo apt-get update
sudo apt-get install -y curl ca-certificates

log "Baixando e executando script oficial de instalação do act (nektos/act)"
# Referência: https://github.com/nektos/act (instalação via install.sh)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

if command -v act >/dev/null 2>&1; then
  log "Instalação do act concluída. Versão instalada: $(act --version || echo 'desconhecida')"
else
  log "Falha ao localizar o binário 'act' após a execução do install.sh. Verifique o log acima."
  exit 1
fi
