# Shantilly RAG

Repositório dedicado para o **RAG (Retrieval-Augmented Generation)** que vai concentrar:

- Documentação e códigos do ecossistema **Charmbracelet** (Bubble Tea, Bubbles, Lip Gloss, Gum, etc.).
- Projetos derivados (stickers, bubbleboxer, wrappers, etc.).
- Outras bibliotecas Go usadas ou consideradas em projetos como o **Shantilly**.

O objetivo é ter uma **base de conhecimento unificada**, atualizável de forma automatizada, que possa ser usada por modelos de IA locais ou remotos (incluindo modelos menos capazes) para auxiliar no desenvolvimento.

## Visão geral do pipeline

O pipeline é separado em três etapas principais:

1. **Fetching**
   - Clona/atualiza repositórios do GitHub e baixa documentos externos.
   - Configurado via `config/sources.yaml`.

2. **Chunking + Metadados**
   - Converte os arquivos brutos em *chunks* semânticos com metadados ricos.
   - Saída em `data/chunks/*.jsonl`.

3. **Indexação no Qdrant**
   - Gera embeddings usando modelos locais (ex.: via Ollama) ou remotos.
   - Faz *upsert* no Qdrant (local ou remoto), na coleção definida em `config/collections.yaml`.

Sobre esse pipeline construímos um servidor RAG em `server/` que implementa:

- **Hybrid search** (busca vetorial + textual).
- **Reranking** dos resultados.
- **Query rewriting** para perguntas em contexto de conversa.

Posteriormente poderemos evoluir para **Graph/Agentic RAG** reutilizando os mesmos metadados.

## Estrutura do repositório

- `config/`
  - Arquivos de configuração do pipeline (fontes, coleções, embeddings, retrieval).
- `data/`
  - `raw/`: dados brutos baixados (repos, markdown, etc.).
  - `chunks/`: chunks + metadados em JSONL.
- `scripts/`
  - Scripts de automação para *fetch*, chunking e indexação.
- `server/`
  - Servidor RAG (API HTTP) para consultas.
- `.github/workflows/`
  - Workflows de CI para manter o corpus atualizado e validar configurações.

## Requisitos iniciais

- Python 3.11+
- Qdrant (local ou remoto)
- Opcional: Ollama instalado para embeddings/LLM locais

Instalação de dependências:

```bash
pip install -r requirements.txt
```

## Uso local (v0)

1. Configurar as fontes em `config/sources.yaml`.
2. Executar:

```bash
python scripts/fetch_sources.py
python scripts/build_chunks.py
python scripts/index_qdrant.py --rebuild
```

3. Subir o servidor RAG (quando implementado):

```bash
uvicorn server.app:app --host 0.0.0.0 --port 8001 --reload
```

## Uso por agentes LLM

Agentes LLM e integrações automatizadas podem consumir o Shantilly RAG de duas formas principais:

- **API HTTP**: `POST http://127.0.0.1:8001/query`
- **CLI Go**: `rag-cli -json "O que é o projeto Shantilly?"`

Para detalhes completos do contrato de uso por agentes (schema JSON, metadados de documentos, boas práticas), consulte `docs/rag/agent_contract.md`.

Notas importantes para agentes/integrações:

- Consultas podem ter **latência alta** (por exemplo, 60–130s) dependendo do modelo/estrutura de retrieval.
- O cliente `rag-cli` possui uma flag `-timeout` (em segundos) e usa por padrão **300s** de timeout por requisição.
- Passar `-timeout 0` desativa o timeout no cliente; o orquestrador/agente deve então aplicar seu próprio timeout externo, se necessário.

## Comandos de administração

Para operadores humanos, os principais comandos de administração são expostos via `Makefile` (atalhos para `tools/admin/rag_cli.sh`):

- `make ingest`              – executa ingestão completa (fetch_sources, build_chunks, index_qdrant).
- `make dev`                 – sobe o servidor FastAPI (uvicorn) com a stack pronta.
- `make eval`                – roda o avaliador RAG (`scripts/eval_rag.py`).
- `make bootstrap`           – equivalente a `ingest + eval`.
- `make wizard`              – abre o wizard interativo com gum.
- `make install-qdrant`      – instala/atualiza o Qdrant local.
- `make install-rag-service` – instala/ativa o serviço systemd do servidor RAG.
- `make install-act`         – instala o `act` para rodar GitHub Actions localmente.

Detalhes completos da arquitetura, pipeline e scripts de administração podem ser encontrados em `docs/rag/architecture.md`.

## CI/CD no GitHub

Workflows em `.github/workflows/` permitem:

- Atualizar o corpus bruto e os chunks periodicamente ou sob demanda.
- Validar que scripts e configurações continuam consistentes.

A indexação em Qdrant normalmente é feita **fora** da CI (em ambiente controlado) usando `scripts/index_qdrant.py`.
