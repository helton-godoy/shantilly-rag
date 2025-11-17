import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel
from qdrant_client import QdrantClient

from .models import OllamaEmbeddingsClient, OllamaLLMClient
from .rag_pipeline import rerank, retrieve, rewrite_query


app = FastAPI(title="Shantilly RAG API")


@app.get("/health")
async def health():
    return {"status": "ok"}


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "config"


def _load_collection_name() -> str:
    import yaml

    path = CONFIG_DIR / "collections.yaml"
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    collections = data.get("collections", [])
    if not collections:
        raise RuntimeError("Nenhuma coleção configurada em config/collections.yaml")

    # Por enquanto usamos a primeira coleção como padrão.
    return collections[0]["name"]


QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY") or None
COLLECTION_NAME = _load_collection_name()

qdrant_client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)
embeddings_client = OllamaEmbeddingsClient()
llm_client = OllamaLLMClient()


class QueryMessage(BaseModel):
    role: str
    content: str


class QueryRequest(BaseModel):
    query: str
    history: Optional[List[Dict[str, Any]]] = None


class QueryResponse(BaseModel):
    answer: str
    documents: List[Dict[str, Any]]


def _build_prompt(question: str, docs: List[Dict[str, Any]]) -> str:
    """Monta o prompt para o LLM a partir do contexto recuperado."""

    if not docs:
        context = "(Nenhum documento relevante foi encontrado no índice.)"
    else:
        parts: List[str] = []
        for i, doc in enumerate(docs, start=1):
            meta = doc.get("metadata", {}) or {}
            source = meta.get("source") or meta.get("path") or "desconhecido"
            parts.append(
                f"[Documento {i}]\nFonte: {source}\n\n{doc.get('text', '')}".strip()
            )
        context = "\n\n---\n\n".join(parts)

    system_instructions = (
        "Você é um assistente especializado no ecossistema Charmbracelet, "
        "no projeto Shantilly e em projetos relacionados. Use apenas o contexto "
        "fornecido para responder. Quando não houver informação suficiente, "
        "admita explicitamente e sugira próximos passos. Responda em português "
        "de forma clara e concisa."
    )

    prompt = (
        f"{system_instructions}\n\n"
        f"Contexto:\n{context}\n\n"
        f"Pergunta do usuário: {question}\n\n"
        "Resposta:"
    )
    return prompt


@app.post("/query", response_model=QueryResponse)
async def query(body: QueryRequest) -> QueryResponse:
    """Endpoint principal de consulta RAG.

    1. Reescreve a query (opcional).
    2. Recupera documentos relevantes no Qdrant.
    3. Aplica reranking.
    4. Gera resposta via LLM usando o contexto recuperado.
    """

    history = body.history or []
    effective_query = rewrite_query(history, body.query)

    docs = retrieve(
        query=effective_query,
        client=qdrant_client,
        embeddings=embeddings_client,
        collection_name=COLLECTION_NAME,
    )
    docs = rerank(effective_query, docs)

    prompt = _build_prompt(effective_query, docs)
    answer = llm_client.generate(prompt)

    return QueryResponse(answer=answer, documents=docs)
