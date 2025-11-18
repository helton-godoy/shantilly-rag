# Relatório de benchmark do Shantilly RAG

## Resumo

Este relatório resume os resultados do benchmark do Shantilly RAG a partir do arquivo CSV: `tools/report/bench_results/summary.csv`.

## Resultados por variante

| Variante | Execuções OK | Latência mínima (ms) | Latência média (ms) | Erros? |
|---------|--------------|----------------------|---------------------|--------|
| vec30r6 | 1 | 238396 | 238396 | não |
| vec20r5 | 1 | 143390 | 143390 | não |

## Conclusão preliminar

- Variantes com **execuções apenas com erro** (`Execuções OK = 0`) provavelmente são inviáveis neste hardware ou com a configuração atual de modelos.
- Entre as variantes com execuções OK, considere adotar como padrão aquela que oferece o melhor equilíbrio entre latência média e ausência de erros.
- Para uma análise mais rica (incluindo qualidade de resposta), use os arquivos JSON apontados na coluna "file" do CSV junto com um avaliador humano ou um LLM juiz.
