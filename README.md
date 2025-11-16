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
uvicorn server.app:app --reload
```

## CI/CD no GitHub

Workflows em `.github/workflows/` permitem:

- Atualizar o corpus bruto e os chunks periodicamente ou sob demanda.
- Validar que scripts e configurações continuam consistentes.

A indexação em Qdrant normalmente é feita **fora** da CI (em ambiente controlado) usando `scripts/index_qdrant.py`.
