import json
import os
from pathlib import Path

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


def embed(texts):
    """Stub para embeddings.

    Em uma próxima etapa vamos conectar com o Ollama ou outro provider.
    Por enquanto, levanta um erro claro para evitar uso acidental.
    """
    raise RuntimeError("Embeddings não configurados ainda. Implemente a função embed().")


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

        texts = [r["text"] for r in records]
        vectors = embed(texts)

        points = []
        for idx, (rec, vec) in enumerate(zip(records, vectors)):
            points.append(
                rest.PointStruct(
                    id=idx,
                    vector=vec,
                    payload=rec["metadata"],
                )
            )

        client.upsert(collection_name=name, points=points)
        print(f"  Indexação concluída: {len(points)} pontos")


if __name__ == "__main__":
    main()
