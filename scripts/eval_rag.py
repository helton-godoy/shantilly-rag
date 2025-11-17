import json
import os
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests


ROOT = Path(__file__).resolve().parents[1]
QA_PATH = ROOT / "tests" / "rag" / "qa_dataset.jsonl"


def load_qa_dataset(path: Path) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    if not path.exists():
        raise SystemExit(f"Dataset de Q&A não encontrado em {path}")

    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            data = json.loads(line)
            items.append(data)
    return items


def call_rag_api(base_url: str, question: str) -> Tuple[str, List[Dict[str, Any]]]:
    url = base_url.rstrip("/") + "/query"
    resp = requests.post(
        url,
        json={"query": question, "history": []},
        timeout=120,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"Falha ao chamar RAG API ({resp.status_code}): {resp.text}")

    data = resp.json()
    answer = data.get("answer", "")
    docs = data.get("documents", []) or []
    return answer, docs


def call_llm_judge(
    base_url: str,
    model: str,
    question: str,
    reference_answer: str,
    model_answer: str,
) -> Dict[str, Any]:
    url = base_url.rstrip("/") + "/api/chat"

    system_prompt = (
        "Você é um avaliador de qualidade de respostas em um sistema RAG. "
        "Receberá uma pergunta do usuário, uma resposta de referência (ideal) "
        "e a resposta gerada pelo modelo. Seu trabalho é julgar se a resposta "
        "do modelo é aceitável dado o enunciado e a resposta de referência. "
        "Considere corretas respostas que cobrem os pontos essenciais, mesmo "
        "que com formulação diferente. Emita seu veredito em JSON estrito, no "
        "seguinte formato: {\"verdict\": \"correct\" ou \"incorrect\", \"reason\": \"explicação curta\"}."
    )

    user_content = (
        "Pergunta do usuário:\n" + question.strip() + "\n\n"
        "Resposta de referência (ideal):\n" + reference_answer.strip() + "\n\n"
        "Resposta do modelo RAG:\n" + model_answer.strip() + "\n\n"
        "Agora emita apenas o JSON pedido."
    )

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        "stream": False,
    }

    resp = requests.post(url, json=payload, timeout=180)
    if resp.status_code != 200:
        raise RuntimeError(
            f"Falha ao chamar LLM judge via Ollama (status {resp.status_code}): {resp.text}"
        )

    data = resp.json()
    message = data.get("message") or {}
    content = (message.get("content") or "").strip()

    try:
        verdict = json.loads(content)
        if not isinstance(verdict, dict):
            raise ValueError("JSON de veredito não é um objeto")
        return verdict
    except Exception:
        # Fallback simples: considerar incorreto se parsing falhar
        return {"verdict": "incorrect", "reason": "Falha ao interpretar a saída do juiz."}


def evaluate() -> None:
    rag_base_url = os.getenv("RAG_BASE_URL", "http://127.0.0.1:8000")
    ollama_base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    judge_model = os.getenv("OLLAMA_JUDGE_MODEL", os.getenv("OLLAMA_CHAT_MODEL", "phi3:medium"))

    print(f"RAG_BASE_URL: {rag_base_url}")
    print(f"OLLAMA_BASE_URL (judge): {ollama_base_url}")
    print(f"Modelo do juiz: {judge_model}")

    qa_items = load_qa_dataset(QA_PATH)
    print(f"Carregadas {len(qa_items)} questões do dataset.")

    total = 0
    correct = 0
    results: List[Dict[str, Any]] = []

    for item in qa_items:
        total += 1
        question = item["question"]
        reference_answer = item["answer"]

        print("\n----------------------------------------")
        print(f"[Q{total}] {question}")

        model_answer, docs = call_rag_api(rag_base_url, question)
        verdict = call_llm_judge(
            base_url=ollama_base_url,
            model=judge_model,
            question=question,
            reference_answer=reference_answer,
            model_answer=model_answer,
        )

        is_correct = verdict.get("verdict") == "correct"
        if is_correct:
            correct += 1

        results.append(
            {
                "question": question,
                "reference_answer": reference_answer,
                "model_answer": model_answer,
                "judge_verdict": verdict,
                "documents": docs,
            }
        )

        print(f"Veredito: {verdict.get('verdict')} - {verdict.get('reason')}")

    accuracy = correct / total if total else 0.0
    print("\n========================================")
    print(f"Total de questões: {total}")
    print(f"Corretas segundo o juiz: {correct}")
    print(f"Acurácia aproximada: {accuracy:.2%}")

    out_path = ROOT / "tests" / "rag" / "eval_results.jsonl"
    with out_path.open("w", encoding="utf-8") as f:
        for r in results:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"Resultados detalhados salvos em {out_path}")


if __name__ == "__main__":
    evaluate()
