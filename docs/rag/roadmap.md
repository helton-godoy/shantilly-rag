# Shantilly RAG – Roadmap de Evolução

Este documento resume os próximos passos planejados para o Shantilly RAG, com foco em:

- **Reduzir a barreira de entrada para agentes LLM**.
- **Tornar o comportamento mais observável e previsível**.
- **Evoluir o pipeline em direção à visão documentada** (retrieval híbrido, query rewriting, avaliação contínua).

Os itens estão organizados em **curto**, **médio** e **longo prazo**.

---

## 1. Curto prazo

Foco: consolidar o v1 como RAG vetorial robusto, com boa DX para agentes.

### 1.1 Query rewriting v1

- **Motivação**: hoje `rewrite_query` é um stub; perguntas de follow-up não se beneficiam do histórico.
- **Ideia**:
  - Implementar uma versão simples de query rewriting que usa apenas as últimas `N` interações (
    `history`) para condensar a pergunta atual.
  - Usar LLM (via Ollama) ou heurísticas simples para gerar a `effective_query`.
  - Ter fallback claro: se der erro ou o rewriting for desconfiável, usar a `query` original.
- **Arquivos principais**:
  - `server/rag_pipeline.py` (`rewrite_query`).
  - Opcionalmente um helper dedicado em `server/`.
- **Critérios de sucesso**:
  - Queries de follow-up em cenários simples (ex.: sobre Bubble Tea / arquitetura Shantilly) melhoram na prática.
  - Benchmarks e/ou `scripts/eval_rag.py` mostram ganho em um subconjunto de perguntas conversacionais.

### 1.2 Health check estendido

- **Motivação**: `GET /health` atual só diz `{"status": "ok"}`; não reflete Qdrant, Ollama, coleção, etc.
- **Ideia**:
  - Adicionar um endpoint (por exemplo, `/health/full`) que teste:
    - Conectividade ao Qdrant e existência da coleção principal.
    - Conectividade ao Ollama e presença dos modelos configurados.
    - Opcional: uma query de teste mínima no índice.
- **Arquivos principais**:
  - `server/app.py` (novas rotas / helpers).
  - Possível reutilização de código de `scripts/index_qdrant.py` e `server/models.py`.
- **Critérios de sucesso**:
  - Operadores e agentes conseguem distinguir rapidamente entre “API viva” e “stack saudável”.

### 1.3 Script simples de diagnóstico da stack

- **Motivação**: troubleshooting hoje depende de conhecimento manual sobre systemd, Qdrant, Ollama, etc.
- **Ideia**:
  - Criar um script único, por exemplo `tools/diagnostics/check_stack.sh`, que:
    - Verifica status de serviços (Qdrant, RAG, Ollama) quando disponíveis.
    - Faz requisições a `/health` e `/health/full`.
    - Opcional: executa uma query de teste usando `rag-cli -json`.
- **Critérios de sucesso**:
  - Um operador consegue rodar um único comando e ter um resumo claro do estado da stack.

### 1.4 Testes de integração básicos

- **Motivação**: hoje a avaliação ocorre principalmente via scripts manuais (`eval_rag.py`, benchmarks).
- **Ideia**:
  - Adicionar alguns testes de integração **mínimos**, por exemplo em `tests/integration/`:
    - Verificar que `/health` responde com 200.
    - Verificar que `/query` responde para uma pergunta simples quando o stack está preparado.
  - Priorizar casos “happy-path” e erros mais comuns.
- **Critérios de sucesso**:
  - CI (ou execução local) consegue detectar quebras óbvias no endpoint `/query`.

### 1.5 Presets de retrieval e docs para agentes

- **Estado atual**: já existem templates de retrieval (ex.: `vec24r6`) e documentação para agentes (`agent_contract.md`).
- **Próximos passos**:
  - Consolidar 2–3 presets de retrieval claramente nomeados (ex.: `minimal`, `balanced`, `quality`).
  - Documentar, em `docs/rag/benchmarking.md` e `docs/rag/agent_contract.md`, quando usar cada preset.
- **Critérios de sucesso**:
  - Benchmarks documentados por preset.
  - Agentes conseguem escolher um preset com base em latência vs. qualidade.

---

## 2. Médio prazo

Foco: aproximar-se da visão de híbrido/avaliação, reforçar confiança e governança.

### 2.1 POC de busca híbrida

- **Motivação**: a visão do projeto menciona busca híbrida (vetorial + textual), mas hoje só há busca vetorial.
- **Ideia** (POC):
  - Explorar abordagens para combinar sinal textual (ex.: outro backend, ou heurísticas sobre payload) com o resultado vetorial.
  - Começar pequeno, em modo opcional, para comparar com o modo puramente vetorial.
- **Critérios de sucesso**:
  - Demonstração isolada de cenários em que o híbrido traz ganho real.
  - Decisão informada sobre incorporar (ou não) o híbrido à rota principal `/query`.

### 2.2 Validador simples de configurações

- **Motivação**: configurações YAML incorretas hoje falham tarde (runtime).
- **Ideia**:
  - Criar um script (por exemplo, `tools/validate_config.py`) que:
    - Carrega `config/*.yaml` com Pydantic (ou similar).
    - Verifica presença de campos obrigatórios e ranges básicos.
  - Opcional: integrar como subcomando de `rag_cli.sh` ou alvo do `Makefile`.
- **Critérios de sucesso**:
  - Configurações inválidas são detectadas antes de subir o servidor ou rodar ingest.

### 2.3 Expansão do dataset de QA

- **Motivação**: o dataset atual em `tests/rag/qa_dataset.jsonl` cobre um conjunto inicial de perguntas.
- **Ideia**:
  - Adicionar casos:
    - Conversacionais / follow-up.
    - Edge cases (arquitetura TUI, YAML complexo, etc.).
    - Multilíngues (EN/PT).
  - Usar esse dataset expandido em `scripts/eval_rag.py`.
- **Critérios de sucesso**:
  - O dataset reflete melhor o uso real esperado por agentes.

### 2.4 Métricas básicas e baselines

- **Motivação**: já existem benchmarks (`tools/report/bench_results/`), mas os baselines ainda não estão consolidados.
- **Ideia**:
  - Consolidar os resultados atuais em um documento, por exemplo `docs/rag/baselines.md`, indicando:
    - Latência típica por preset de retrieval.
    - Taxa de sucesso/erro em cenários padrão.
  - Opcional: iniciar logging simples de latência por requisição no servidor.
- **Critérios de sucesso**:
  - Mudanças em modelos/configurações podem ser comparadas com números de referência claros.

---

## 3. Longo prazo

Foco: maturidade de produto, governança e colaboração avançada com agentes.

### 3.1 Hot reload seletivo de configurações

- **Ideia**:
  - Permitir recarregar algumas configurações (por exemplo, parâmetros de retrieval) sem reiniciar todo o serviço.
  - Exigir cuidado especial com consistência (ex.: mudanças de coleção Qdrant podem continuar exigindo restart completo).
- **Risco**:
  - Aumenta a complexidade do runtime; recomendado apenas após estabilizar os fluxos básicos.

### 3.2 Métricas avançadas e feedback de agentes

- **Ideia**:
  - Ir além de latência/erros e coletar:
    - Sinais de relevância/diversidade (por exemplo, via LLM-judge).
    - Feedback explícito de agentes (endpoint simples para “thumbs up/down”, tags de erro percebido, etc.).
  - Opcional: expor métricas em formato apropriado para Prometheus/Grafana.

### 3.3 Evoluções no cliente Go e SDKs

- **Possibilidades**:
  - Expandir o `rag-cli` com:
    - Streaming de respostas.
    - Retry com backoff.
    - Modo benchmark embutido.
  - Eventualmente, criar SDKs leves para outras linguagens (Python, TypeScript) com helpers de timeout/retry e parsing de `documents`.

---

## 4. Relação com a documentação existente

- **`docs/rag/architecture.md`**: descreve o estado atual da arquitetura, incluindo a seção "Estado atual vs visão futura".
- **`docs/rag/agent_contract.md`**: contrato de uso para agentes (HTTP e `rag-cli -json`), Quick Start e troubleshooting básico.
- **`docs/rag/benchmarking.md`**: explica como rodar e interpretar benchmarks de retrieval.

Este roadmap deve ser mantido vivo à medida que novas iterações forem concluídas (por exemplo, marcando itens como concluídos, ligando para novos documentos de design ou para resultados de benchmark atualizados).
