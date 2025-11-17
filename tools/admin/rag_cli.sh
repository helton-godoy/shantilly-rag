#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
PYTHON_BIN="python3"

export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
export RAG_BASE_URL="${RAG_BASE_URL:-http://127.0.0.1:8000}"

log() {
  echo "[rag_cli] $*"
}

ensure_venv() {
  if [ ! -d "$VENV_DIR" ]; then
    log "Criando venv em $VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  fi
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  log "Instalando dependências do requirements.txt"
  pip install -r "$ROOT_DIR/requirements.txt" >/dev/null
}

ensure_services() {
  log "Garantindo que qdrant.service está ativo"
  if ! systemctl is-active --quiet qdrant.service; then
    sudo systemctl start qdrant.service
  fi
  log "Garantindo que ollama.service está ativo"
  if ! systemctl is-active --quiet ollama.service; then
    sudo systemctl start ollama.service
  fi
}

ensure_ollama_models() {
  local embedding_model chat_model

  if ! command -v ollama >/dev/null 2>&1; then
    log "Ollama não encontrado no PATH. Instale com:"
    log "  curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
  fi

  embedding_model="$(EMBED_CFG_PATH="$ROOT_DIR/config/embedding.yaml" python - << 'EOF'
import os
import yaml

cfg_path = os.environ.get('EMBED_CFG_PATH')
if not cfg_path or not os.path.exists(cfg_path):
    # Fallback seguro se o arquivo de config não existir
    print('nomic-embed-text')
else:
    with open(cfg_path, 'r', encoding='utf-8') as f:
        cfg = yaml.safe_load(f) or {}
    print(cfg.get('model', 'nomic-embed-text'))
EOF
)"

  chat_model="${OLLAMA_CHAT_MODEL:-phi3:medium}"

  log "Checando modelo de embedding no Ollama: $embedding_model"
  if ! ollama list 2>/dev/null | grep -q "^$embedding_model"; then
    log "Baixando modelo de embedding: $embedding_model"
    ollama pull "$embedding_model"
  fi

  log "Checando modelo de chat no Ollama: $chat_model"
  if ! ollama list 2>/dev/null | grep -q "^$chat_model"; then
    log "Baixando modelo de chat: $chat_model"
    ollama pull "$chat_model"
  fi
}

ingest() {
  ensure_venv
  ensure_services
  ensure_ollama_models

  log "Rodando fetch_sources.py"
  python "$ROOT_DIR/scripts/fetch_sources.py"

  log "Rodando build_chunks.py"
  python "$ROOT_DIR/scripts/build_chunks.py"

  log "Rodando index_qdrant.py"
  python "$ROOT_DIR/scripts/index_qdrant.py"
}

run_server() {
  ensure_venv
  ensure_services
  ensure_ollama_models

  log "Subindo servidor FastAPI em $RAG_BASE_URL (uvicorn)"
  exec uvicorn server.app:app --host 0.0.0.0 --port "${RAG_BASE_URL##*:}" --reload
}

run_eval() {
  ensure_venv
  ensure_services
  ensure_ollama_models

  log "Rodando avaliador RAG (scripts/eval_rag.py)"
  python "$ROOT_DIR/scripts/eval_rag.py"
}

usage() {
  cat <<EOF
Uso: $(basename "$0") <comando>

Comandos:
  ingest    Executa ingestão completa (fetch_sources, build_chunks, index_qdrant)
  dev       Sobe o servidor FastAPI (uvicorn) com stack pronta
  eval      Executa scripts/eval_rag.py com stack pronta
  bootstrap Equivalente a: ingest + eval
  install-qdrant        Instala ou atualiza o Qdrant local (tools/install/install_qdrant.sh)
  install-rag-service   Instala/ativa serviço systemd para servidor dev (tools/install/install_rag.sh)
  install-act           Instala o 'act' para rodar GitHub Actions localmente (tools/install/install_act.sh)
EOF
}

bootstrap() {
  ingest
  run_eval
}

cmd="${1:-}"
case "$cmd" in
  ingest)
    shift
    ingest "$@"
    ;;
  dev)
    shift
    run_server "$@"
    ;;
  eval)
    shift
    run_eval "$@"
    ;;
  bootstrap)
    shift
    bootstrap "$@"
    ;;
  install-qdrant)
    shift
    "$ROOT_DIR/tools/install/install_qdrant.sh" "$@"
    ;;
  install-rag-service)
    shift
    "$ROOT_DIR/tools/install/install_rag.sh" "$@"
    ;;
  install-act)
    shift
    "$ROOT_DIR/tools/install/install_act.sh" "$@"
    ;;
  ""|-h|--help)
    usage
    ;;
  *)
    log "Comando desconhecido: $cmd"
    usage
    exit 1
    ;;
esac
