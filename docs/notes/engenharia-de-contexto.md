# Engenharia de Contexto: A Chave para Construir Agentes de IA Profissionais

- **Título:** Engenharia de Contexto: A Chave para Construir Agentes de IA Profissionais  
- **Canal:** Ronnald Hawk  
- **URL:** https://www.youtube.com/watch?v=aMJUnOeOs2k  
- **Duração:** ~19min10s  
- **Ferramentas citadas:** Python, LangGraph, RAG, memória semântica  
- **Tema central:** Como ir além de prompt engineering e controlar janela de contexto, memória e sumarização para evitar agentes que "esquecem" (efeito Dory).

---

## 1. O que é Engenharia de Contexto

- Disciplina que complementa a **engenharia de prompt**:
  - decide **quais informações entram no prompt**, quando e em qual forma;  
  - controla histórico, memória e contexto de maneira explícita.

- Problema alvo:
  - modelos com janelas grandes podem "se distrair";  
  - mais contexto nem sempre = melhores respostas.

---

## 2. Fraqueza das LLMs com contexto longo

- Limitações naturais:
  - janela de contexto finita (tokens);  
  - atenção distribuída sobre todo o contexto.
- Sintomas:
  - LLM ignora detalhes importantes do começo da conversa;  
  - usa trechos irrelevantes;  
  - aumenta custo sem garantir ganho de qualidade.

---

## 3. Engenharia de Contexto e RAG

- RAG como mecanismo de **seleção de contexto**:
  - indexar documentos de forma estruturada;  
  - fazer retrieval seletivo em vez de enviar todos os dados.

- Boas práticas:
  - embeddings adequados;  
  - chunking coerente (manter unidade semântica);  
  - tuning de `k`, filtros, e eventualmente busca híbrida.

---

## 4. Engenharia de Contexto e Memória Semântica

- Memória semântica:
  - armazenamento de fatos importantes ao longo do tempo;  
  - recuperada via busca semântica (vector DB).

- Exemplos de uso:
  - preferências do usuário;  
  - decisões importantes;  
  - resumos de sessões passadas.

---

## 5. Engenharia de Contexto e sumarização de histórico

- Em vez de guardar a conversa inteira, usar **sumarização incremental**:
  - resumos por sessão;  
  - resumos por tópico;  
  - atualizações periódicas.

- Em orquestradores como LangGraph:
  - nós e edges determinam quando resumir, salvar em memória, ou descartar.

---

## Ideias-chave reaproveitáveis para o projeto `shantilly-rag`

- **Nível 1 (atual):**
  - RAG puro sobre documentação/código, com Qdrant + Nomic + Ollama.

- **Nível 2 (próxima evolução):**
  - introduzir uma camada de **memória semântica** usando Qdrant para:
    - registrar interações importantes com usuários;  
    - permitir que o sistema "lembre" decisões e preferências.

- **Nível 3 (futuro):**
  - implementar **sumarização de histórico** e engenharia de contexto avançada:  
    - resumos de conversas longas;  
    - seleção inteligente de trechos de histórico para entrar no prompt;  
    - possivelmente usar LangGraph ou pipeline equivalente para explicitar esse fluxo.

- Essas notas podem servir como guia conceitual para futuras features de:
  - memória de sessão;  
  - histórico consolidado de conhecimento;  
  - agentes de longo prazo construídos sobre o `shantilly-rag`.
