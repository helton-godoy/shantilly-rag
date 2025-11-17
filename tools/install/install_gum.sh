#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[install_gum] $*"
}

if ! command -v apt-get >/dev/null 2>&1; then
  log "Este script é destinado a sistemas baseados em Debian (Debian/Ubuntu/Deepin) com apt-get."
  exit 1
fi

if command -v gum >/dev/null 2>&1; then
  log "gum já está instalado em $(command -v gum). Nada a fazer."
  exit 0
fi

log "Configurando repositório Charm (gum)"

sudo mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/charm.gpg ]; then
  log "Baixando chave GPG do repositório Charm"
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
else
  log "Chave GPG já existe em /etc/apt/keyrings/charm.gpg, reutilizando."
fi

CHARM_LIST="/etc/apt/sources.list.d/charm.list"
if [ ! -f "$CHARM_LIST" ] || ! grep -q "https://repo.charm.sh/apt" "$CHARM_LIST" 2>/dev/null; then
  log "Registrando repositório APT da Charm em $CHARM_LIST"
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee "$CHARM_LIST" >/dev/null
else
  log "Repositório Charm já está configurado em $CHARM_LIST, reutilizando."
fi

log "Atualizando índices APT"
sudo apt-get update

log "Instalando pacote gum via APT"
sudo apt-get install -y gum

log "Instalação do gum concluída. Versão instalada: $(gum --version || echo 'desconhecida')"
