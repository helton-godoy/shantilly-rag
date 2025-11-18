# Relatório de benchmark do Shantilly RAG

## Resumo

Este relatório resume os resultados do benchmark do Shantilly RAG a partir do arquivo CSV: `tools/report/bench_results/2025-11-18-run01/summary.csv`.

### Hardware do benchmark

- Sistema: Ubuntu 24.04.3 LTS
- CPU: AMD Ryzen 7 5700 (8 cores físicos / 16 threads)
- RAM: 31Gi de memória instalada
- GPUs:
  - Advanced Micro Devices, Inc. [AMD/ATI] Lexa PRO [Radeon 540/540X/550/550X / RX 540X/550/550X]

## Resultados por variante

| Variante | Execuções OK | Latência mínima (ms) | Latência média (ms) | Latência média (humana) | Erros? |
|---------|--------------|----------------------|---------------------|--------------------------|--------|
| vec40r10 | 1 | 147672 | 147672 | 2m 27.7s | não |
| vec30r6 | 1 | 292794 | 292794 | 4m 52.8s | não |
| vec20r5 | 1 | 298772 | 298772 | 4m 58.8s | não |

## Conclusão preliminar

- Variantes com **execuções apenas com erro** (`Execuções OK = 0`) provavelmente são inviáveis neste hardware ou com a configuração atual de modelos.
- Entre as variantes com execuções OK, considere adotar como padrão aquela que oferece o melhor equilíbrio entre latência média e ausência de erros.
- Para uma análise mais rica (incluindo qualidade de resposta), use os arquivos JSON apontados na coluna "file" do CSV junto com um avaliador humano ou um LLM juiz.
