import json
import os
from pathlib import Path

import requests
from qdrant_client import QdrantClient
from qdrant_client.http import models as rest


ROOT = Path(__file__).resolve().parents[1]
CHUNKS_DIR = ROOT / "data" / "chunks"
CONFIG_DIR = ROOT / "config"


def get_qdrant_client() -> QdrantClient:
    url = os.getenv("QDRANT_URL", "http://localhost:6333")
    api_key = os.getenv("QDRANT_API_KEY") or None
    return QdrantClient(url=url, api_key=api_key)


def load_collections_config():
    import yaml

    path = CONFIG_DIR / "collections.yaml"
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}

def load_embedding_config():
    import yaml

    path = CONFIG_DIR / "embedding.yaml"
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def embed(texts, expected_dim=None):
    """Stub para embeddings.

    Em uma próxima etapa vamos conectar com o Ollama ou outro provider.
    Por enquanto, levanta um erro claro para evitar uso acidental.
    """
    cfg = load_embedding_config()
    provider = cfg.get("provider", "ollama")
    if provider != "ollama":
        raise RuntimeError(f"Provider de embeddings não suportado: {provider!r}")

    model = cfg.get("model", "nomic-embed-text")
    base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
    url = f"{base_url}/api/embeddings"

    vectors = []
    for idx, text in enumerate(texts):
        resp = requests.post(
            url,
            json={"model": model, "prompt": text},
            timeout=60,
        )
        if resp.status_code != 200:
            raise RuntimeError(
                f"Falha ao obter embedding via Ollama (status {resp.status_code}) "
                f"para item {idx}: {resp.text}"
            )
        data = resp.json()
        vec = data.get("embedding")
        if vec is None:
            raise RuntimeError(
                "Resposta de embeddings do Ollama não contém campo 'embedding'"
            )
        if expected_dim is not None and len(vec) != expected_dim:
            raise RuntimeError(
                f"Dimensão do embedding ({len(vec)}) diferente do esperado ({expected_dim})."
            )

        vectors.append(vec)

    return vectors


def main() -> None:
    cfg = load_collections_config()
    collections = cfg.get("collections", [])
    if not collections:
        raise SystemExit("Nenhuma coleção configurada em config/collections.yaml")

    client = get_qdrant_client()

    for col in collections:
        name = col["name"]
        vector_size = col["vector_size"]

        print(f"[index] Coleção: {name}")

        client.recreate_collection(
            collection_name=name,
            vectors_config=rest.VectorParams(
                size=vector_size,
                distance=rest.Distance.COSINE,
            ),
        )

        chunks_path = CHUNKS_DIR / f"{name}.jsonl"
        if not chunks_path.exists():
            print(f"  Arquivo de chunks não encontrado: {chunks_path}")
            continue

        records = []
        with chunks_path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                data = json.loads(line)
                records.append(data)

        texts = [f"search_document: {r['text']}" for r in records]
        vectors = embed(texts, expected_dim=vector_size)

        points = []
        for idx, (rec, vec) in enumerate(zip(records, vectors)):
            payload = dict(rec["metadata"])
            payload["text"] = rec["text"]

            points.append(
                rest.PointStruct(
                    id=idx,
                    vector=vec,
                    payload=payload,
                )
            )

        client.upsert(collection_name=name, points=points)
        print(f"  Indexação concluída: {len(points)} pontos")


if __name__ == "__main__":
    main()
