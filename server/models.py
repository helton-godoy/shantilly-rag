"""Modelos e abstrações para integração com LLM/embeddings.

Aqui poderemos implementar clients para:
- Ollama (LLM e embeddings locais).
- Outros providers (OpenAI, etc.), se desejado.
"""

from typing import List


class EmbeddingsClient:
    def embed(self, texts: List[str]) -> List[List[float]]:
        raise NotImplementedError


class LLMClient:
    def generate(self, prompt: str) -> str:
        raise NotImplementedError
