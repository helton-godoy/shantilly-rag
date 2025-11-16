import json
from pathlib import Path
from typing import Dict, Iterable, List


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
CHUNKS_DIR = ROOT / "data" / "chunks"


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def iter_text_files() -> Iterable[Path]:
    for path in RAW_DIR.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".md", ".txt", ".go"}:
            yield path


def simple_chunk(text: str, max_chars: int = 2000) -> List[str]:
    """Chunking simples por tamanho fixo de caracteres.

    Posteriormente podemos evoluir para chunking por seções/títulos.
    """
    chunks: List[str] = []
    start = 0
    n = len(text)
    while start < n:
        end = min(start + max_chars, n)
        chunks.append(text[start:end])
        start = end
    return chunks


def build_metadata(path: Path) -> Dict:
    rel = path.relative_to(RAW_DIR)
    parts = list(rel.parts)

    source = str(rel)
    library = None
    type_ = "doc"

    if parts and parts[0] == "github" and len(parts) >= 3:
        owner = parts[1]
        repo = parts[2]
        library = repo
        source = f"github:{owner}/{repo}:/" + "/".join(parts[3:])

    return {
        "source": source,
        "library": library,
        "type": type_,
        "path": "/".join(parts),
        "lang": "en",  # por enquanto default; poderemos detectar idioma depois
        "tags": [],
    }


def main() -> None:
    ensure_dir(CHUNKS_DIR)
    out_path = CHUNKS_DIR / "charmbracelet_shantilly_knowledge.jsonl"

    with out_path.open("w", encoding="utf-8") as out_f:
        for file_path in iter_text_files():
            text = file_path.read_text(encoding="utf-8", errors="ignore")
            if not text.strip():
                continue

            meta = build_metadata(file_path)
            chunks = simple_chunk(text)

            for chunk in chunks:
                record = {
                    "text": chunk,
                    "metadata": meta,
                }
                out_f.write(json.dumps(record, ensure_ascii=False) + "\n")

    print(f"Chunks escritos em {out_path}")


if __name__ == "__main__":
    main()
