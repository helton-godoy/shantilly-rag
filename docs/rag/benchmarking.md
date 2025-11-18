# Benchmark de Shantilly RAG

Este documento descreve como executar benchmarks de latência/qualidade do Shantilly RAG em diferentes hardwares, usando:

- Templates de configuração de *retrieval* em `tools/templates/retrieval/`.
- O script de benchmark `tools/report/rag_benchmark.sh`.
- O cliente Go `rag-cli`.

A ideia é medir quanto tempo cada configuração leva para responder a uma query (ou conjunto de queries) e comparar as variações de `vector.top_k` e `rerank.top_k` para escolher a melhor combinação para o seu equipamento.

---

## 1. Templates de configuração de retrieval

Existem três templates de exemplo em `tools/templates/retrieval/`:

- `tools/templates/retrieval/retrieval.bench.vec40r10.yaml`
- `tools/templates/retrieval/retrieval.bench.vec30r6.yaml`
- `tools/templates/retrieval/retrieval.bench.vec20r5.yaml`

Eles variam os parâmetros:

- `retrieval.vector.top_k`
- `retrieval.rerank.top_k`

### 1.1. vec40r10

```yaml
retrieval:
  vector:
    top_k: 40
  text:
    top_k: 40
  hybrid:
    alpha: 0.6  # peso do score vetorial em relação ao textual
  rerank:
    enabled: true
    top_k: 10
    # modelo de reranking poderá ser local (via Ollama) ou outro provider

query_rewrite:
  enabled: true
  max_history_turns: 5
```

### 1.2. vec30r6 (próximo do default atual)

```yaml
retrieval:
  vector:
    top_k: 30
  text:
    top_k: 40
  hybrid:
    alpha: 0.6  # peso do score vetorial em relação ao textual
  rerank:
    enabled: true
    top_k: 6
    # modelo de reranking poderá ser local (via Ollama) ou outro provider

query_rewrite:
  enabled: true
  max_history_turns: 5
```

### 1.3. vec20r5 (mais agressivo em latência)

```yaml
retrieval:
  vector:
    top_k: 20
  text:
    top_k: 40
  hybrid:
    alpha: 0.6  # peso do score vetorial em relação ao textual
  rerank:
    enabled: true
    top_k: 5
    # modelo de reranking poderá ser local (via Ollama) ou outro provider

query_rewrite:
  enabled: true
  max_history_turns: 5
```

Você pode criar mais templates copiando um desses arquivos e ajustando os valores de `top_k`.

> **Dica:** mantenha um nome descritivo no arquivo, por exemplo `retrieval.bench.vec32r8.yaml`, para que o script de benchmark consiga derivar um identificador da variação automaticamente.

---

## 2. Script de benchmark: `rag_benchmark.sh`

Script: `tools/report/rag_benchmark.sh`

Função:

- Para cada arquivo de config de benchmark:
  - Copia o arquivo para `config/retrieval.yaml`.
  - Reinicia o serviço `rag.service`.
  - Aguarda o endpoint `/health` ficar OK.
  - Executa o cliente Go `rag-cli -json` com a query informada.
  - Salva o resultado JSON em `tools/report/bench_results/`.

### 2.1. Pré-requisitos

- Serviço `rag.service` instalado e funcionando (via `tools/admin/rag_cli.sh install-rag-service`).
- Go instalado (para rodar `clients/go/cmd/rag-cli`).
- Templates de retrieval criados em `tools/templates/retrieval/` (como os três exemplos acima).

Dê permissão de execução ao script uma vez:

```bash
cd ~/git/shantilly-rag
chmod +x tools/report/rag_benchmark.sh
```

### 2.2. Uso básico

Exemplo de benchmark com as três variações de exemplo e uma query, gerando também um CSV de resumo:

```bash
cd ~/git/shantilly-rag

./tools/report/rag_benchmark.sh \
  --query "O que é o projeto Shantilly?" \
  --configs "tools/templates/retrieval/retrieval.bench.*.yaml" \
  --runs 1 \
  --csv tools/report/bench_results/summary.csv
```

Parâmetros:

- `--query` (obrigatório): pergunta a ser usada em todos os testes.
- `--configs`: glob de arquivos de config (default: `tools/templates/retrieval/retrieval.bench.*.yaml`).
- `--runs`: número de execuções por config (default: `1`).
- `--csv`: arquivo CSV opcional para resumo (ex.: `tools/report/bench_results/summary.csv`).

O script irá:

1. Iterar por todos os arquivos que casam com o glob (`retrieval.bench.vec40r10.yaml`, `retrieval.bench.vec30r6.yaml`, etc.).
2. Para cada arquivo:
   - Copiar para `config/retrieval.yaml`.
   - Reiniciar `rag.service`.
   - Aguardar o `/health` ficar OK.
   - Rodar `rag-cli -json` com timeout alto (600s) para evitar corte em CPU-only.
   - Salvar o JSON em `tools/report/bench_results/`.

Os arquivos de saída terão nomes como:

- `tools/report/bench_results/vec40r10_run1_20251118_095800.json`
- `tools/report/bench_results/vec30r6_run1_20251118_100015.json`
- `tools/report/bench_results/vec20r5_run1_20251118_100230.json`

O prefixo (`vec40r10`, etc.) vem do nome do arquivo de config.

---

## 3. Conteúdo dos arquivos de resultado

Cada arquivo JSON de resultado é a saída do `rag-cli -json`, com o seguinte formato:

```json
{
  "question": "O que é o projeto Shantilly?",
  "answer": "Shantilly é um projeto...",
  "documents": [
    {
      "id": 1307,
      "score": 0.68,
      "text": "trecho relevante...",
      "metadata": {
        "source": "github:helton-godoy/shantilly:/docs/prd.md",
        "path": "github/helton-godoy/shantilly/docs/prd.md",
        "library": "shantilly",
        "type": "doc",
        "lang": "en",
        "tags": ["runtime", "architecture"]
      }
    }
  ],
  "latency_ms": 112345
}
```

Campos importantes:

- `latency_ms`: tempo total da requisição (em milissegundos).
- `documents`: contexto usado para gerar a resposta (com fontes e metadados).

A combinação do nome do arquivo (ex.: `vec30r6_run1_...`) com `latency_ms` permite comparar diretamente o custo/benefício de cada configuração.

---

## 4. Como interpretar os resultados

### 4.1. Latência

Para cada variação (`vec40r10`, `vec30r6`, `vec20r5`):

1. Observe os valores de `latency_ms` em cada run.
2. Se você rodar com `--runs > 1`, calcule a média por variação.

Em geral:

- Valores menores de `top_k` tendem a reduzir `latency_ms`, pois:
  - Menos documentos são buscados e rerankeados.
  - Menos texto é enviado ao LLM.

### 4.2. Qualidade

Latência não é tudo. Leia a `answer` e verifique se:

- A resposta está completa e correta o suficiente para o seu uso.
- As `documents` listadas fazem sentido (PRD, docs de arquitetura, código relevante, etc.).

Pode ser que uma configuração com `top_k` maior traga contexto mais rico em alguns casos, ao custo de alguns segundos a mais.

### 4.3. Escolhendo o melhor ajuste para seu hardware

Uma abordagem prática:

1. Escolha um conjunto de queries representativas do seu uso real (ex.: 3–5 perguntas).
2. Rode o benchmark para cada variação de config com essas queries.
3. Para cada variação, avalie:
   - Média de `latency_ms` por query.
   - Qualidade subjetiva das respostas.
4. Escolha a combinação que oferece o melhor equilíbrio entre:
   - Tempo aceitável para o seu fluxo (por exemplo, <60s por resposta).
   - Qualidade/contexto suficiente para agentes LLM e humanos.

Depois de escolher a variação favorita, você pode:

- Copiar o template correspondente para `config/retrieval.yaml` como configuração padrão.
- Reexecutar `sudo systemctl restart rag.service` para adotá-la em produção.

---

## 5. Benchmarks personalizados

Para criar benchmarks personalizados:

1. Crie novos arquivos de config em `tools/templates/retrieval/` com o padrão `retrieval.bench.*.yaml`.
2. Ajuste `vector.top_k` e `rerank.top_k` conforme desejar.
3. Rode o script com um glob que inclua seus novos arquivos, por exemplo:

```bash
./tools/report/rag_benchmark.sh \
  --query "Explique o Epic 1 do runtime TUI" \
  --configs "tools/templates/retrieval/retrieval.bench.vec*.yaml" \
  --runs 2 \
  --csv tools/report/bench_results/summary_epic1.csv
```

Isso permite que cada usuário adapte os benchmarks ao seu hardware (CPU/GPU, memória disponível) e tenha uma base robusta de dados para decidir a melhor configuração de retrieval para seu ambiente.
