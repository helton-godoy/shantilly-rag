# Agentic RAG: THINK and CREATE like a PRO

- **Título:** Agentic RAG: THINK and CREATE like a PRO  
- **Canal:** Ronnald Hawk  
- **URL:** https://www.youtube.com/watch?v=m6Q9x678myU  
- **Duração:** ~15m30s  
- **Público-alvo:** devs, empreendedores e iniciantes em RAG / agentes de IA  
- **Tema central:** Por que diferentes ferramentas (Cursor, LangChain) adotam abordagens opostas de busca semântica, e como isso evolui para o conceito de *Agentic RAG*.

---

## 1. Motivação e contexto

- Muitos tutoriais mostram RAG de forma simplificada ou “errada”, sem:
  - ajustar cuidadosamente chunking e embeddings;
  - testar recuperação e qualidade de resposta;
  - usar agentes com múltiplas ferramentas.
- Ferramentas como **Cursor** e **LangChain** implementam estratégias bem diferentes de busca semântica:
  - Cursor: foco em busca vetorial “clássica” por similaridade.
  - LangChain: foco em evitar chunking mal feito, uso de estruturas mais ricas (por ex. retrievers compostos, agentes que escolhem a ferramenta).

---

## 2. O que é Agentic RAG

- Combinação de:
  - **RAG clássico:** indexar → buscar contexto → gerar resposta.
  - **Agentes de IA:** que podem:
    - escolher ferramentas (retrievers, funções, APIs);
    - ajustar parâmetros (k, filtros, estratégia de busca) em tempo de execução;
    - executar passos múltiplos (planejar → buscar → refletir → responder).
- Ideia central:
  - Em vez de um pipeline rígido, ter um *agente* que sabe “como” buscar e “quando” usar cada ferramenta.
  - Agentic RAG = *RAG + controle inteligente do fluxo*.

---

## 3. A solução do Cursor (Semantic Search)

- Usa majoritariamente **busca semântica vetorial**:
  - indexa código e docs em um índice vetorial;
  - consulta é embutida e comparada por similaridade.
- Benefícios:
  - Simplicidade de implementação;
  - resultado razoável para muitos casos.
- Limitações discutidas:
  - chunking ingênuo;
  - falta de controle fino sobre quais trechos são usados no contexto;
  - pouca lógica “condicional” (tudo via ranking de similaridade).

---

## 4. A solução do LangChain (evitando chunking ingênuo)

- LangChain oferece:
  - múltiplos tipos de retrievers (parent/child, multi-vector, etc.);
  - fluxos mais complexos (chains, agents).
- Objetivo:
  - **reduzir o impacto negativo de chunking mal escolhido**, usando
    - estruturas hierárquicas,
    - combinações de buscas,
    - ferramentas adicionais (por ex. chamada de API, leitura incremental, etc.).
- O vídeo destaca como isso se aproxima de Agentic RAG:
  - o pipeline deixa de ser “uma consulta → um ranking”;
  - passa a ser um conjunto de passos orquestrados por um agente.

---

## 5. Exemplo de estrutura de Agentic RAG (visão geral de código)

1. **Entendimento da tarefa**  
   - interpretar a pergunta do usuário;  
   - decidir quais fontes/coleções usar.

2. **Planejamento do agente**  
   - escolher ferramenta(s) de busca (vetorial, híbrida, HyDE, etc.);  
   - definir parâmetros (k, filtros, score threshold).

3. **Execução de retrieval**  
   - executar uma ou mais buscas;  
   - combinar resultados.

4. **Raciocínio sobre o contexto**  
   - processar o contexto em múltiplos passos (Chain-of-Thought, ferramentas de raciocínio).

5. **Geração da resposta final**  
   - aplicar um prompt bem definido;  
   - opcionalmente explicar fontes ou passos.

---

## 6. Monetização e aplicações práticas

- Caminhos citados:
  - agentes especializados (jurídico, negócios, desenvolvimento, etc.);
  - soluções B2B de automação e análise;
  - camada de inteligência em produtos SaaS.

---

## 7. Ideias-chave reaproveitáveis para o projeto `shantilly-rag`

- Agentic RAG como **fase 2** do projeto:  
  primeiro, RAG sólido; depois, agentes que escolhem estratégias de busca.
- Importância de:
  - múltiplos retrievers/estratégias (vetorial, híbrida, HyDE);
  - ajuste dinâmico de parâmetros (k, filtros) com base na tarefa;  
  - separar claramente etapas de planejamento, busca e raciocínio.
