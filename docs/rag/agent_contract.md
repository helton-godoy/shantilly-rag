# Contrato de uso do Shantilly RAG para agentes LLM

Este documento descreve **como agentes LLM** (ou ferramentas automatizadas) devem consumir o Shantilly RAG, via:

- API HTTP (`POST /query`)
- CLI Go (`rag-cli -json`)

## 0. Contexto na arquitetura

Na organização atual do repositório (detalhada em `docs/rag/architecture.md`), temos:

- **Core RAG (engine e dados)**: `server/`, `scripts/`, `config/`, `data/`, `tests/rag/`, `docs/rag/`.
- **Ferramentas e automação**: `tools/admin/`, `tools/install/`, `tools/report/`, `tools/templates/`.
- **Clientes e integrações**: `clients/` (por exemplo, o cliente Go `rag-cli` e futuros TUIs/SDKs).

Este contrato de agente descreve como clientes (via HTTP direto ou via `rag-cli -json`) devem interagir com o servidor RAG e interpretar os campos de resposta para uso em fluxos de agentes LLM.

Assume-se que:

- O pipeline de ingestão já foi executado pelo operador humano (ou automação) e a coleção do Qdrant está pronta.
- O serviço RAG está acessível no ambiente onde o agente roda, via `RAG_BASE_URL` (default `http://127.0.0.1:8001`).

Agentes **não são responsáveis** por instalar ou subir Qdrant, Ollama ou o serviço FastAPI; devem apenas consumir as interfaces expostas.

## 1. Endpoint HTTP `/query`

### 1.1. Request

Por padrão, o servidor RAG é exposto em `http://127.0.0.1:8001` (ou no valor de `RAG_BASE_URL`, se definido).
A URL completa típica é:

```http
POST http://127.0.0.1:8001/query
Content-Type: application/json
```

```json
{
  "query": "pergunta em linguagem natural",
  "history": [
    { "role": "user", "content": "mensagem anterior" },
    { "role": "assistant", "content": "resposta anterior" }
  ]
}
```

- **query**: pergunta atual.
- **history** (opcional): histórico de conversa. Hoje é ignorado pelo servidor (é ecoado, mas não muda a busca), mas pode ser usado futuramente para query rewriting. Agentes podem enviar esse campo, porém **não devem depender** de efeitos de memória ou reescrita de query na versão atual.

### 1.2. Response

```json
{
  "answer": "resposta em linguagem natural",
  "documents": [
    {
      "id": 123,
      "score": 0.68,
      "text": "trecho de documento relevante",
      "metadata": {
        "source": "github:helton-godoy/shantilly:/docs/prd.md",
        "path": "github/helton-godoy/shantilly/docs/prd.md",
        "library": "shantilly",
        "type": "doc",
        "lang": "en",
        "tags": ["architecture", "runtime", "tui"]
      }
    }
  ]
}
```

### 1.3. Erros e códigos HTTP

- Em caso de sucesso, o servidor retorna `200 OK` com o JSON no formato acima.
- Em caso de erro interno (por exemplo, falha ao consultar o Qdrant ou o Ollama), o FastAPI normalmente responde com `500` e um corpo JSON contendo um campo `detail` com a mensagem de erro.
- Erros de rede (timeout, conexão recusada, DNS, etc.) não produzem resposta HTTP; o agente deve tratá-los como **serviço indisponível** e decidir se tenta novamente ou falha graciosamente.

#### Campos importantes de `documents.metadata`

Agentes devem, preferencialmente, usar:

- **`source`** (`string`)
  - Identificador compacto da origem, incluindo repositório e, às vezes, caminho lógico.
  - Exemplo: `github:helton-godoy/shantilly:/docs/prd.md`.
  - Útil para citar a fonte em respostas e para navegação de código/docs.

- **`path`** (`string`)
  - Caminho relativo dentro da origem (normalmente um repo Git espelhado).
  - Exemplo: `github/helton-godoy/shantilly/docs/prd.md`.
  - Use este campo para mapear de volta para arquivos reais.

- **`library`** (`string`)
  - Nome lógico da “biblioteca” ou projeto.
  - Exemplo: `shantilly`.
  - Útil para ambientes com múltiplos projetos indexados.

- **`type`** (`string`)
  - Tipo de conteúdo.
  - Exemplos típicos: `doc`, `code`.
  - Ajuda agentes a diferenciar entre documentação, código-fonte, etc.

- **`lang`** (`string`)
  - Idioma principal do trecho.
  - Valores esperados: `en`, `pt`, etc.
  - Ajuda a decidir em qual idioma responder ou quais trechos priorizar.

- **`tags`** (`array` de `string`, opcional)
  - Palavras-chave associadas ao trecho (pode estar ausente).
  - Exemplo: `["architecture", "runtime", "tui"]`.

Agentes devem tratar campos **ausentes** de forma robusta (assumir valor desconhecido) e nunca depender de um subconjunto específico como obrigatório.

## 2. CLI Go: `rag-cli -json`

O binário `rag-cli` expõe um modo voltado para agentes via flag `-json`.

### 2.1. Uso

```bash
rag-cli -json "O que é o projeto Shantilly?"
```

Saída (exemplo simplificado):

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
        "source": "github:helton-godoy/shantilly:/docs/chats/SHANTILLY RUNTIME 02 - BMad.md",
        "path": "github/helton-godoy/shantilly/docs/chats/SHANTILLY RUNTIME 02 - BMad.md",
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

### 2.2. Campos da resposta JSON do `rag-cli`

- **`question`** (`string`)
  - Pergunta enviada pelo usuário/agente.

- **`answer`** (`string`)
  - Resposta gerada pelo RAG (já em linguagem natural, tipicamente em português para perguntas em PT-BR).

- **`documents`** (`array` de `Document`)
  - Mesma estrutura do endpoint HTTP `/query`.
  - Contém `id`, `score`, `text` e `metadata` conforme descrito na seção anterior.

- **`latency_ms`** (`integer`)
  - Tempo total, em milissegundos, desde o envio da requisição até o recebimento da resposta do servidor.
  - Útil para monitorar desempenho e decidir se é necessário ajustar parâmetros de retrieval ou timeout.

### 2.3. Integração recomendada para agentes

- Preferir o uso de `rag-cli -json` quando o agente:
  - Não tem acesso direto à API HTTP (ex.: ambiente isolado).
  - Está orquestrando ferramentas via shell.

- Preferir o endpoint HTTP `/query` quando:
  - O agente está rodando em um ambiente que permite chamadas HTTP diretas.
  - Deseja controle completo sobre timeouts, batching, etc.

### 2.4. Saída, logs e códigos de erro

- No modo `-json`, o `rag-cli` imprime **apenas JSON** em `stdout` (sem prefixos ou logs misturados).
- Mensagens de erro e diagnósticos são impressos em `stderr`.
- Em caso de sucesso, o processo termina com código de saída `0`.
- Em caso de falha (erro ao chamar o servidor RAG, ao decodificar a resposta ou ao serializar o JSON), o processo imprime uma mensagem em `stderr` e termina com código de saída diferente de zero.

Agentes devem:

- Ler o JSON apenas de `stdout`.
- Tratar qualquer código de saída diferente de zero como falha da ferramenta, usando `stderr` apenas para diagnóstico (não para responder ao usuário final).

## 3. Boas práticas para agentes LLM

1. **Citar fontes**
   - Sempre que responder usando dados do RAG, inclua referências ao menos de `source` e `path` dos documentos mais relevantes.

2. **Evitar alucinações**
   - Tratar `documents` como *fonte de verdade*.
   - Se não houver documentos relevantes, responder explicitamente que não há informação suficiente.

3. **Usar idioma do usuário**
   - Quando `lang` dos trechos for misto, priorizar trechos no idioma do usuário.

4. **Não depender de um único campo**
   - A combinação de `source`, `path`, `type`, `lang` e `tags` é estável, mas algum campo pode estar ausente para determinados documentos.

Com esse contrato, agentes LLM podem consumir o Shantilly RAG de maneira previsível, tanto via HTTP direto quanto via CLI Go (`rag-cli -json`), com acesso estruturado às fontes e à latência da consulta.
