#!/usr/bin/env bash
set -euo pipefail

# Gera um relatório Markdown simples a partir do summary.csv do benchmark.
# Uso:
#   tools/report/rag_benchmark_report.sh tools/report/bench_results/summary.csv > docs/rag/benchmark_run.md

CSV_PATH="${1:-}" || true

if [[ -z "$CSV_PATH" ]]; then
  echo "Uso: $(basename "$0") CAMINHO_DO_SUMMARY_CSV" >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "Erro: arquivo CSV não encontrado: $CSV_PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HW_SUMMARY=""
if [[ -x "$SCRIPT_DIR/rag_benchmark_hw_summary.sh" ]]; then
  HW_SUMMARY="$($SCRIPT_DIR/rag_benchmark_hw_summary.sh 2>/dev/null || true)"
fi

# Ignora a linha de cabeçalho e acumula estatísticas por variante.
# Formato esperado:
# variant,run,timestamp,latency_ms,status,file

awk -F, -v hw="$HW_SUMMARY" 'NR>1 {
  variant=$1; run=$2; ts=$3; lat=$4; status=$5;
  if (!(variant in seen)) {
    seen[variant]=1;
    ok_count[variant]=0;
    sum_lat[variant]=0;
    min_lat[variant]=0;
    has_error[variant]=0;
  }
  if (status=="ok" && lat != "") {
    ok_count[variant]++;
    sum_lat[variant]+=lat;
    if (min_lat[variant]==0 || lat<min_lat[variant]) {
      min_lat[variant]=lat;
    }
  }
  if (status=="error") {
    has_error[variant]=1;
  }
}
END {
  printf("# Relatório de benchmark do Shantilly RAG\n\n");
  printf("## Resumo\n\n");
  printf("Este relatório resume os resultados do benchmark do Shantilly RAG a partir do arquivo CSV: `%s`.\n\n", ARGV[1]);

  if (hw != "") {
    printf("### Hardware do benchmark\n\n");
    printf("%s\n\n", hw);
  }

  printf("## Resultados por variante\n\n");
  printf("| Variante | Execuções OK | Latência mínima (ms) | Latência média (ms) | Latência média (humana) | Erros? |\n");
  printf("|---------|--------------|----------------------|---------------------|--------------------------|--------|\n");

  for (v in seen) {
    ok=ok_count[v];
    min=min_lat[v];
    avg="-";
    avg_human="-";
    if (ok>0) {
      avg_ms=sum_lat[v]/ok;
      avg=avg_ms;
      sec=avg_ms/1000;
      mins=int(sec/60);
      secs=sec-(mins*60);
      avg_human=sprintf("%dm %.1fs", mins, secs);
    }
    err = has_error[v] ? "sim" : "não";
    if (min==0) { min="-"; }
    if (avg=="-") {
      printf("| %s | %d | %s | %s | %s | %s |\n", v, ok, min, avg, avg_human, err);
    } else {
      printf("| %s | %d | %s | %.0f | %s | %s |\n", v, ok, min, avg, avg_human, err);
    }
  }

  printf("\n## Conclusão preliminar\n\n");
  printf("- Variantes com **execuções apenas com erro** (`Execuções OK = 0`) provavelmente são inviáveis neste hardware ou com a configuração atual de modelos.\n");
  printf("- Entre as variantes com execuções OK, considere adotar como padrão aquela que oferece o melhor equilíbrio entre latência média e ausência de erros.\n");
  printf("- Para uma análise mais rica (incluindo qualidade de resposta), use os arquivos JSON apontados na coluna \"file\" do CSV junto com um avaliador humano ou um LLM juiz.\n");
}
' "$CSV_PATH"
