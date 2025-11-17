"""Modelos e abstrações para integração com LLM/embeddings.

Aqui poderemos implementar clients para:
- Ollama (LLM e embeddings locais).
- Outros providers (OpenAI, etc.), se desejado.
"""

import os
from pathlib import Path
from typing import List

import requests


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "config"


class EmbeddingsClient:
    def embed(self, texts: List[str]) -> List[List[float]]:
        raise NotImplementedError


class LLMClient:
    def generate(self, prompt: str) -> str:
        raise NotImplementedError


def load_embedding_config():
    import yaml

    path = CONFIG_DIR / "embedding.yaml"
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


class OllamaEmbeddingsClient(EmbeddingsClient):
    def __init__(self, base_url: str | None = None, model: str | None = None) -> None:
        cfg = load_embedding_config()
        self.base_url = (base_url or os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")).rstrip("/")
        self.model = model or cfg.get("model", "nomic-embed-text")

    def embed(self, texts: List[str]) -> List[List[float]]:
        url = f"{self.base_url}/api/embeddings"
        vectors: List[List[float]] = []
        for idx, text in enumerate(texts):
            resp = requests.post(
                url,
                json={"model": self.model, "prompt": text},
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
                raise RuntimeError("Resposta de embeddings do Ollama não contém campo 'embedding'")
            vectors.append(vec)
        return vectors


class OllamaLLMClient(LLMClient):
    def __init__(self, base_url: str | None = None, model: str | None = None) -> None:
        self.base_url = (base_url or os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")).rstrip("/")
        self.model = model or os.getenv("OLLAMA_CHAT_MODEL", "phi3:medium")

    def generate(self, prompt: str) -> str:
        url = f"{self.base_url}/api/chat"
        payload = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
        }
        resp = requests.post(url, json=payload, timeout=120)
        if resp.status_code != 200:
            raise RuntimeError(
                f"Falha ao gerar resposta via Ollama (status {resp.status_code}): {resp.text}"
            )
        data = resp.json()
        message = data.get("message") or {}
        content = message.get("content")
        if not content:
            raise RuntimeError("Resposta do Ollama não contém conteúdo em 'message.content'")
        return content
