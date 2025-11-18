#!/usr/bin/env bash
set -euo pipefail

# Shantilly RAG - Benchmark helper
#
# Uso básico:
#   tools/report/rag_benchmark.sh \
#     --query "O que é o projeto Shantilly?" \
#     --configs "tools/templates/retrieval/retrieval.bench.*.yaml" \
#     --runs 1
#
# Requisitos:
#   - Serviço rag.service instalado e gerenciando o servidor RAG.
#   - Go instalado (para rodar clients/go/cmd/rag-cli).
#   - Configs de retrieval de benchmark existentes em tools/templates/retrieval, por exemplo:
#       tools/templates/retrieval/retrieval.bench.vec40r10.yaml
#       tools/templates/retrieval/retrieval.bench.vec30r6.yaml
#       tools/templates/retrieval/retrieval.bench.vec20r5.yaml
#
# O script irá, para cada config:
#   1. Copiar o arquivo para config/retrieval.yaml.
#   2. Reiniciar o serviço rag.service.
#   3. Aguardar o /health responder OK.
#   4. Executar N vezes o rag-cli -json com a query informada.
#   5. Salvar os resultados JSON em tools/report/bench_results/.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCH_DIR="$ROOT_DIR/tools/report/bench_results"
CONFIG_DIR="$ROOT_DIR/config"
RAG_CLI_DIR="$ROOT_DIR/clients/go"
RAG_CLI_BIN="$ROOT_DIR/bin/rag-cli"
RAG_CLI_FALLBACK="go run ./cmd/rag-cli"
RAG_BASE_URL_DEFAULT="http://127.0.0.1:8001"

JSON_FILES=()

mkdir -p "$BENCH_DIR"

log() {
  echo "[rag_benchmark] $*"
}

usage() {
  cat <<EOF
Uso: $(basename "$0") --query "PERGUNTA" [--configs GLOB] [--runs N] [--csv ARQUIVO]

Parâmetros:
  --query   Pergunta a ser usada em todos os testes (obrigatório).
  --configs Glob de arquivos de config de retrieval (default: tools/templates/retrieval/retrieval.bench.*.yaml).
  --runs    Número de execuções por configuração (default: 1).
  --csv     Arquivo CSV opcional para resumo (variant,run,timestamp,latency_ms,file).

Exemplo:
  $(basename "$0") \
    --query "O que é o projeto Shantilly?" \
    --configs "tools/templates/retrieval/retrieval.bench.*.yaml" \
    --runs 1 \
    --csv tools/report/bench_results/summary.csv
EOF
}

QUERY=""
CONFIGS_GLOB="tools/templates/retrieval/retrieval.bench.*.yaml"
RUNS=1
CSV_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)
      QUERY="$2"; shift 2;;
    --configs)
      CONFIGS_GLOB="$2"; shift 2;;
    --runs)
      RUNS="$2"; shift 2;;
    --csv)
      CSV_OUT="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      log "Parâmetro desconhecido: $1"
      usage
      exit 1;;
  esac
done

if [[ -z "$QUERY" ]]; then
  log "Erro: --query é obrigatório"
  usage
  exit 1
fi

# Expande glob de configs
shopt -s nullglob
CONFIG_FILES=($CONFIGS_GLOB)
shopt -u nullglob

if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
  log "Nenhum arquivo de config encontrado para glob: $CONFIGS_GLOB"
  exit 1
fi

log "Encontradas ${#CONFIG_FILES[@]} configs de retrieval para benchmark"

wait_for_health() {
  local base_url
  base_url="${RAG_BASE_URL:-$RAG_BASE_URL_DEFAULT}"
  local url="$base_url/health"

  log "Aguardando saúde do servidor em $url"
  for i in {1..30}; do
    if curl -s "$url" | grep -q '"status"'; then
      log "Servidor saudável (health OK)"
      return 0
    fi
    sleep 2
  done
  log "Timeout aguardando /health em $url"
  return 1
}

for cfg in "${CONFIG_FILES[@]}"; do
  cfg_basename="$(basename "$cfg")"
  # Ex.: retrieval.bench.vec40r10.yaml -> vec40r10
  variant="${cfg_basename#retrieval.bench.}"
  variant="${variant%.yaml}"

  log "=================================================="
  log "Config: $cfg (variant=$variant)"

  # Copia config para retrieval.yaml
  log "Copiando $cfg para $CONFIG_DIR/retrieval.yaml"
  cp "$cfg" "$CONFIG_DIR/retrieval.yaml"

  log "Reiniciando serviço rag.service"
  sudo systemctl restart rag.service

  wait_for_health

  for ((run=1; run<=RUNS; run++)); do
    timestamp="$(date +%Y%m%d_%H%M%S)"
    out_file="$BENCH_DIR/${variant}_run${run}_$timestamp.json"

    log "[variant=$variant run=$run] Executando rag-cli -json"

    if [[ -x "$RAG_CLI_BIN" ]]; then
      # Usa o binário compilado se estiver disponível
      RAG_BASE_URL="$RAG_BASE_URL_DEFAULT" "$RAG_CLI_BIN" -timeout 600 -json "$QUERY" > "$out_file"
    else
      # Fallback: usa go run a partir de clients/go
      (
        cd "$RAG_CLI_DIR"
        # Usa timeout alto para evitar corte prematuro em CPU-only
        RAG_BASE_URL="$RAG_BASE_URL_DEFAULT" $RAG_CLI_FALLBACK -timeout 600 -json "$QUERY"
      ) > "$out_file"
    fi

    JSON_FILES+=("$out_file")
    log "[variant=$variant run=$run] Resultado salvo em $out_file"
  done

done

if [[ -n "$CSV_OUT" ]]; then
  log "Gerando resumo CSV em $CSV_OUT"
  {
    echo "variant,run,timestamp,latency_ms,file"
    for f in "${JSON_FILES[@]}"; do
      base="$(basename "$f")"   # ex.: vec30r6_run1_20251118_100015.json
      variant="${base%%_run*}"    # antes de _run
      rest="${base#*_run}"       # apos _run -> 1_2025...
      run="${rest%%_*}"          # antes do proximo _ -> 1
      ts="${rest#*_}"            # apos run_ -> 2025...
      ts="${ts%.json}"           # remove .json
      latency="$(grep -m1 '"latency_ms"' "$f" | tr -cd '0-9')"
      echo "$variant,$run,$ts,$latency,$f"
    done
  } > "$CSV_OUT"
  log "Resumo CSV gerado em $CSV_OUT"
fi

log "Benchmark concluído. Resultados em: $BENCH_DIR"
