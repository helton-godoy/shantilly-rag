# Shantilly RAG – Arquitetura Atual

## 1. Visão geral

O Shantilly RAG é um pipeline de *Retrieval-Augmented Generation* focado em documentar e explorar o ecossistema Charmbracelet (Bubble Tea, Bubbles, Lip Gloss, Gum, etc.), com:

- Ingestão de fontes (repos Git) → `scripts/fetch_sources.py`
- Chunking + metadados → `scripts/build_chunks.py`
- Indexação vetorial em Qdrant → `scripts/index_qdrant.py`
- Servidor FastAPI com endpoint `/query` → `server/app.py`
- Embeddings + LLM via Ollama (nomic-embed-text / phi3:medium) → `server/models.py`
- Avaliação RAG com LLM juiz → `scripts/eval_rag.py` + `tests/rag/qa_dataset.jsonl`
- Ferramentas de automação, instalação e wizard interativo → `tools/`

---

## 2. Estrutura de diretórios (alto nível)

Principais pastas na raiz do repositório:

- `server/`
  - `app.py` – aplicação FastAPI, endpoints `/health` e `/query`.
  - `models.py` – abstrações `EmbeddingsClient` / `LLMClient` e implementações para Ollama.
  - `rag_pipeline.py` – funções `retrieve`, `rerank`, `rewrite_query` usadas pelo endpoint `/query`.

- `scripts/`
  - `fetch_sources.py` – clona/atualiza repositórios Git de interesse para `data/raw/`.
  - `build_chunks.py` – lê fontes em `data/raw/` e produz `data/chunks/*.jsonl` com textos e metadados.
  - `index_qdrant.py` – cria/recria coleção no Qdrant e indexa chunks com embeddings.
  - `eval_rag.py` – roda avaliação RAG usando dataset de Q&A e um modelo juiz via Ollama.
  - `refresh_all.sh` – script auxiliar para rodar as etapas básicas em sequência (se desejado).

- `tests/rag/`
  - `qa_dataset.jsonl` – dataset de perguntas/respostas usado pelo avaliador.

- `config/` (não listado aqui mas usado pelo código)
  - `collections.yaml` – define coleções do Qdrant (nome, `vector_size`, `distance`, `on_disk`).
  - `embedding.yaml` – provedor e modelo de embedding (ex. `provider: ollama`, `model: nomic-embed-text`).
  - `retrieval.yaml` – parâmetros de retrieval/rerank (top_k, alfa para híbrido, etc.).

- `tools/`
  - `admin/` – orquestração e UX.
  - `install/` – scripts de instalação (Qdrant, RAG service, gum).
  - `report/` – scripts de relatório de hardware.
  - `templates/` – templates estáticos (services systemd, completions do gum).

- `docs/`
  - `rag/` – documentação de arquitetura atual (este arquivo) e docs futuros.
  - `notes/` – notas conceituais de RAG, engenharia de contexto, etc.
  - `gum/` – documentação vendorizada do projeto gum.

### 2.1. Visão lógica: core RAG, ferramentas e clientes

- **Core RAG (engine e dados)**
  - `server/`, `scripts/`, `config/`, `data/`, `tests/rag/`, `docs/rag/`.

- **Ferramentas e automação em torno do RAG**
  - `tools/admin/`, `tools/install/`, `tools/report/`, `tools/templates/`.

- **Clientes e integrações**
  - `clients/` (por exemplo, cliente Go `rag-cli` e futuros TUIs/SDKs).

Essa visão separa o que é o "motor" do RAG (pipeline, servidor e dados) das ferramentas operacionais e dos clientes que consomem a API, mantendo a estrutura física atual do repositório.

---

## 3. Pipeline de dados

### 3.1. Ingestão de fontes (`fetch_sources.py`)

- Lê `config/sources.yaml` (quando existir) com lista de repos/URLs.
- Clona ou atualiza repositórios Git para `data/raw/github/<owner>/<repo>`.
- Pensado para ser idempotente: se o repo já existe, faz `git fetch` / `git pull`.

### 3.2. Chunking (`build_chunks.py`)

- Percorre `data/raw/` aplicando filtros de arquivo e regras de chunking.
- Gera `data/chunks/charmbracelet_shantilly_knowledge.jsonl` no formato:

  ```json
  {"text": "...", "metadata": {"source": "...", "path": "...", ...}}
  ```

- Essa base é a entrada principal para a indexação.

### 3.3. Indexação no Qdrant (`index_qdrant.py`)

- Lê `config/collections.yaml` para saber:
  - nome da coleção (`charmbracelet_shantilly_knowledge`),
  - `vector_size` (768, compatível com `nomic-embed-text`),
  - função de distância (`cosine`).
- Usa `QDRANT_URL` (ou `http://localhost:6333` por padrão) para conectar ao Qdrant.
- Para cada coleção:
  1. `recreate_collection` com `VectorParams(size, distance)`.
  2. Carrega `data/chunks/<coleção>.jsonl`.
  3. Gera embeddings chamando `embed(texts, expected_dim=vector_size)`, que usa a API `/api/embeddings` do Ollama com:
     - prefixo `search_document: `,
     - modelo configurado em `config/embedding.yaml` (ex. `nomic-embed-text`).
  4. `upsert` de pontos em Qdrant com:
     - vetor,
     - payload contendo `text` e `metadata`.

---

## 4. Runtime e API

### 4.1. Servidor FastAPI (`server/app.py`)

- Inicializa um `FastAPI()` com:
  - `/health` – endpoint simples de health check.
  - `/query` (POST) – corpo definido por `QueryRequest` (texto da query + histórico opcional).
- `/query` faz:
  1. `rewrite_query(history, query)` – hoje um stub simples (pode evoluir).
  2. `retrieve` – busca vetorial no Qdrant.
  3. `rerank` – reordenamento básico baseado no score (comportamento configurável via `retrieval.yaml`).
  4. Constrói um prompt com contexto (trechos dos docs retornados) e a pergunta.
  5. Chama o LLM via `OllamaLLMClient.generate(prompt)`.
  6. Retorna resposta + documentos usados (`QueryResponse`).

### 4.2. Clientes de embedding e LLM (`server/models.py`)

- `OllamaEmbeddingsClient`:
  - Lê `config/embedding.yaml` para descobrir o modelo (ex. `nomic-embed-text`).
  - Usa `OLLAMA_BASE_URL` ou `http://127.0.0.1:11434`.
  - Chama `/api/embeddings` do Ollama para uma lista de textos, retornando lista de vetores.

- `OllamaLLMClient`:
  - Usa `OLLAMA_CHAT_MODEL` (ex. `phi3:medium`) ou um default.
  - Chama `/api/chat` do Ollama com `stream: false`.
  - Retorna `message.content` como string.

### 4.3. Pipeline de retrieval (`server/rag_pipeline.py`)

- `retrieve(query, client, embeddings, collection_name)`:
  - Aplica prefixo `search_query: ` à query.
  - Gera embedding.
  - Chama `client.search` no Qdrant com `limit=top_k` (de `config/retrieval.yaml`).
  - Retorna docs no formato `{id, score, text, metadata}`.

- `rerank(query, docs)`:
  - Se `rerank.enabled` estiver `true` em `retrieval.yaml`, ordena por `score` e corta em `top_k`.
  - Hoje é um rerank simples (pode evoluir para LLM ou reranker dedicado).

- `rewrite_query(history, query)`:
  - Stub atual (pode ser evoluído para usar histórico ou técnicas de Query Rewriting).

---

## 5. Ferramentas, automação e UX

### 5.1. CLI de administração (`tools/admin/rag_cli.sh`)

Subcomandos principais:

- `ingest` – garante venv + serviços + modelos Ollama e roda:
  - `scripts/fetch_sources.py`
  - `scripts/build_chunks.py`
  - `scripts/index_qdrant.py`

- `dev` – prepara ambiente e sobe servidor FastAPI com `uvicorn`.
- `eval` – prepara ambiente e roda `scripts/eval_rag.py`.
- `bootstrap` – `ingest` + `eval` numa tacada só.
- `install-qdrant` – delega para `tools/install/install_qdrant.sh`.
- `install-rag-service` – delega para `tools/install/install_rag.sh`.

### 5.2. Wizard com gum (`tools/admin/rag_wizard.sh`)

- Usa `gum` (via PATH ou `./bin/gum`) para criar um menu interativo:
  - Onboarding inicial (ingest + opção de instalar serviço + opção de rodar eval).
  - Rodar ingest isolado.
  - Subir servidor dev.
  - Rodar avaliação RAG.
  - Instalar Qdrant local.
  - Instalar serviço dev (systemd).

- É uma camada de UX por cima do `rag_cli.sh` (não reimplementa a lógica).

### 5.3. Scripts de instalação (`tools/install/`)

- `install_qdrant.sh`:
  - Instala dependências de build (curl, git, libclang, protobuf-compiler).
  - Instala/atualiza Rust (rustup).
  - Clona ou atualiza `github.com/qdrant/qdrant` em `~/git/qdrant`.
  - Compila `qdrant` em `target/release/qdrant`.
  - Cria usuário `qdrant`, diretório `/var/lib/qdrant`, config `/etc/qdrant/config.yaml`.
  - Copia binário para `/usr/local/bin/qdrant`.
  - Copia template `tools/templates/service/qdrant.service` para `/etc/systemd/system/qdrant.service`.
  - Dá `daemon-reload`, `enable`, `restart` e mostra status.

- `install_rag.sh`:
  - Copia `tools/templates/service/rag.service` para `/etc/systemd/system/rag.service`.
  - Dá `daemon-reload`, `enable --now` e mostra status.

- `install_gum.sh`:
  - Destinado a Debian/Ubuntu/Deepin.
  - Configura repositório APT da Charm em `/etc/apt/sources.list.d/charm.list`.
  - Instala o pacote `gum` via `apt-get`.

- `install_act.sh`:
  - Destinado a Debian/Ubuntu/Deepin.
  - Instala dependências básicas (curl, ca-certificates).
  - Baixa e executa o script oficial de instalação do `act` (nektos/act) a partir do GitHub.
  - Deixa o binário `act` disponível no PATH para rodar GitHub Actions localmente.

### 5.4. Makefile

- Atalhos:

  ```make
  make ingest              # ./tools/admin/rag_cli.sh ingest
  make dev                 # ./tools/admin/rag_cli.sh dev
  make eval                # ./tools/admin/rag_cli.sh eval
  make bootstrap           # ./tools/admin/rag_cli.sh bootstrap
  make wizard              # ./tools/admin/rag_wizard.sh
  make install-qdrant      # ./tools/admin/rag_cli.sh install-qdrant
  make install-rag-service # ./tools/admin/rag_cli.sh install-rag-service
  make install-act         # ./tools/admin/rag_cli.sh install-act
  ```

---

## 6. Serviços e runtime no sistema

### 6.1. Qdrant

- Instalado e gerenciado via `install_qdrant.sh`.
- Unidade systemd: `tools/templates/service/qdrant.service`.
- Config padrão em `/etc/qdrant/config.yaml`.
- Exposição local em `127.0.0.1:6333` (HTTP) e `127.0.0.1:6334` (gRPC).

### 6.2. Ollama

- Instalado separadamente via script oficial `curl -fsSL https://ollama.com/install.sh | sh`.
- Serviço systemd e binário gerenciados pelos instaladores do próprio Ollama.
- Em runtime, o projeto usa:
  - `OLLAMA_BASE_URL` (default `http://127.0.0.1:11434`).
  - Modelos: `nomic-embed-text` (embedding) e `phi3:medium` (LLM / juiz).

### 6.3. Servidor RAG (FastAPI)

- Template de unidade: `tools/templates/service/rag.service`.
- Instalado via `tools/install/install_rag.sh` + `rag_cli.sh install-rag-service`.
- Usa o Python do venv do repositório para rodar `uvicorn server.app:app` na porta 8000.

---

## 7. Fluxos típicos de uso

### 7.1. Primeira vez na máquina

1. Instalar Qdrant (build local + systemd):

   ```bash
   ./tools/admin/rag_cli.sh install-qdrant
   # ou
   make install-qdrant
   ```

2. Instalar gum (se quiser usar o wizard):

   ```bash
   ./tools/install/install_gum.sh
   ```

3. Preparar base (ingest):

   ```bash
   ./tools/admin/rag_cli.sh ingest
   # ou
   make ingest
   ```

4. Opcionalmente, instalar serviço dev do RAG:

   ```bash
   ./tools/admin/rag_cli.sh install-rag-service
   # ou
   make install-rag-service
   ```

### 7.2. Uso diário

- Subir servidor dev manualmente (se não estiver usando systemd):

  ```bash
  ./tools/admin/rag_cli.sh dev
  # ou
  make dev
  ```

- Rodar avaliação RAG:

  ```bash
  ./tools/admin/rag_cli.sh eval
  # ou
  make eval
  ```

- Usar wizard interativo:

  ```bash
  ./tools/admin/rag_wizard.sh
  # ou
  make wizard
  ```

---

Este documento deve ser o ponto de partida para entender **como o Shantilly RAG está organizado hoje**. Mudanças futuras na arquitetura (ex.: reranking avançado, retrieval híbrido, memória semântica, Agentic RAG) podem ser registradas em arquivos adicionais dentro de `docs/rag/` (por exemplo, `design_hybrid_retrieval.md`, `semantic_memory.md`, `agentic_plan.md`).
