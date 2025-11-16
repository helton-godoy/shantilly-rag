"""Pipeline RAG (consulta) - a ser implementado.

Responsabilidades previstas:
- Query rewriting (condensar contexto de conversa em uma query seca para busca).
- Hybrid retrieval (vetorial + textual).
- Reranking dos resultados.
- Montagem do contexto final para o modelo de linguagem.
"""

from typing import Any, Dict, List


def rewrite_query(history: List[Dict[str, Any]], query: str) -> str:
    """Reescreve a query do usuário usando o histórico de conversa.

    Implementação futura: chamar um LLM (ex.: via Ollama) para condensar a pergunta.
    Por enquanto, apenas retorna a query original.
    """
    return query


def retrieve(query: str) -> List[Dict[str, Any]]:
    """Faz a busca inicial em Qdrant (hybrid retrieval).

    Implementação futura: combinar busca vetorial + textual.
    """
    raise NotImplementedError


def rerank(query: str, docs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Reranking dos documentos retornados.

    Implementação futura: usar modelo de reranking local/remoto.
    """
    return docs
