"""Pipeline RAG (consulta) - a ser implementado.

Responsabilidades previstas:
- Query rewriting (condensar contexto de conversa em uma query seca para busca).
- Hybrid retrieval (vetorial + textual).
- Reranking dos resultados.
- Montagem do contexto final para o modelo de linguagem.
"""

from pathlib import Path
from typing import Any, Dict, List

from qdrant_client import QdrantClient

from .models import EmbeddingsClient


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "config"


def _load_retrieval_config() -> Dict[str, Any]:
    import yaml

    path = CONFIG_DIR / "retrieval.yaml"
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


RETRIEVAL_CFG = _load_retrieval_config()


def rewrite_query(history: List[Dict[str, Any]], query: str) -> str:
    """Reescreve a query do usuário usando o histórico de conversa.

    Futuro: usar um LLM para condensar a pergunta com base no histórico.
    Por enquanto, apenas retorna a query original.
    """
    return query


def retrieve(
    query: str,
    client: QdrantClient,
    embeddings: EmbeddingsClient,
    collection_name: str,
) -> List[Dict[str, Any]]:
    """Faz a busca inicial em Qdrant.

    Implementação atual: busca vetorial simples usando o embedding da query.
    Os parâmetros são lidos de config/retrieval.yaml (seção retrieval.vector.top_k).
    """

    vector_top_k = (
        RETRIEVAL_CFG.get("retrieval", {})
        .get("vector", {})
        .get("top_k", 40)
    )

    query_vec = embeddings.embed([f"search_query: {query}"])[0]

    results = client.search(
        collection_name=collection_name,
        query_vector=query_vec,
        limit=vector_top_k,
        with_payload=True,
        with_vectors=False,
    )

    docs: List[Dict[str, Any]] = []
    for r in results:
        payload = r.payload or {}
        text = payload.get("text", "")
        metadata = {k: v for k, v in payload.items() if k != "text"}

        docs.append(
            {
                "id": r.id,
                "score": r.score,
                "text": text,
                "metadata": metadata,
            }
        )

    return docs


def rerank(query: str, docs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Reranking dos documentos retornados.

    Implementação atual: apenas ordena por score do Qdrant e aplica o top_k
    configurado em retrieval.rerank.top_k (se enabled=true).
    Futuro: integrar modelo de reranking dedicado.
    """

    rerank_cfg = RETRIEVAL_CFG.get("rerank", {})
    if not rerank_cfg.get("enabled", False):
        return docs

    top_k = rerank_cfg.get("top_k", len(docs))
    docs_sorted = sorted(docs, key=lambda d: d.get("score", 0.0), reverse=True)
    return docs_sorted[:top_k]
