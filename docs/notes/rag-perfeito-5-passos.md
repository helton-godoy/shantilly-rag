# Como CRIAR um Agente de IA RAG PERFEITO (5 passos)

- **Título:** Como CRIAR um Agente de IA RAG PERFEITO (5 passos)  
- **Canal:** Ronnald Hawk  
- **URL:** https://www.youtube.com/watch?v=LZoLvV7p25A  
- **Duração:** ~34min  
- **Ferramentas citadas:** Python, Supabase, LangChain, LangGraph  
- **Tema central:** Framework em 5 passos para construir um agente RAG robusto, com foco em testes e melhoria iterativa.

---

## Passo 0. Entendendo documentos e criando Q&A

- Antes de qualquer código de RAG:
  - **Entender profundamente os documentos** (domínio, formatos, granularidade).
  - Criar um conjunto de **perguntas e respostas reais (ground truth)**:
    - usado para avaliar retrieve e respostas;  
    - permite medir se o sistema realmente entende o domínio.

---

## Passo 1. ETL, chunking, embeddings e estratégias

- **ETL**
  - Coleta de dados (PDF, web, código, etc.).
  - Limpeza e normalização.

- **Chunking**
  - Cortes em função de seções, parágrafos, tamanho, estrutura lógica.
  - Trade-offs:
    - chunks grandes: mais contexto, mas mais ruído e custo;  
    - chunks pequenos: mais precisão, mas risco de perder o sentido.

- **Embeddings**
  - Escolha de modelo adequada ao domínio e idioma.
  - Padronização de prefixos/instruções (document vs query).

- **Estratégias de busca**
  - vetorial simples;  
  - **busca híbrida** (texto + vetorial);  
  - **HyDE** (Hypothetical Document Embeddings):
    - gerar um documento hipotético com o LLM;  
    - indexar/usar esse texto para melhorar a busca.

---

## Passo 2. Testando e melhorando o Retrieval

- Uso de **LLM as a Judge**:
  - Entrada: query, documentos recuperados, resposta correta (esperada).  
  - Saída: avaliação se o contexto é relevante e suficiente.

- Métricas indiretas:
  - precisão/recall aproximados;  
  - capacidade de comparar diferentes estratégias de retrieval.

- Ciclo típico:
  1. executar retrieval com uma estratégia (ex.: vetorial puro);  
  2. avaliar com LLM as a Judge;  
  3. testar variações (HyDE, híbrida, ajustes de k, filtros);  
  4. escolher combinação de parâmetros que maximiza qualidade.

---

## Passo 3. Testando o agente RAG

- Após calibrar o retrieval, integrar agente + RAG.
- Testar:
  - se o agente usa corretamente as ferramentas;  
  - se respeita o contexto fornecido;  
  - se evita alucinar fatos fora do índice.
- Ideal: automatizar parte desses testes com o conjunto de Q&A do Passo 0.

---

## Passo 4. Engenharia de Prompt e refinamento

- Com retrieval/agent estáveis, refinar prompts para:
  - reforçar uso do contexto;  
  - definir tom/idioma/resposta;  
  - instruir o modelo a admitir quando não há informação suficiente.
- Reaplicar os testes de Q&A e LLM as a Judge após mudanças de prompt.

---

## Ideias-chave reaproveitáveis para o projeto `shantilly-rag`

- **Já alinhado:**
  - pipeline de ETL + chunking + embeddings + indexação (scripts `fetch_sources`, `build_chunks`, `index_qdrant`).

- **Próximos passos sugeridos pelos 5 passos:**
  - criar um conjunto de **Q&A de verdade** sobre o ecossistema Charmbracelet/Shantilly;  
  - implementar um fluxo simples de **LLM as a Judge** para comparar:
    - parâmetros de retrieval (`top_k`, filtros) e estratégias futuras (híbrido/HyDE);  
  - automatizar testes do endpoint `/query` usando essas Q&A.

- **Visão de longo prazo:**
  - integrar esse ciclo de testes em CI/CD (avaliar qualidade de retrieval e resposta em cada mudança relevante do projeto).
