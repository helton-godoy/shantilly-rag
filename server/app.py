from fastapi import FastAPI


app = FastAPI(title="Shantilly RAG API")


@app.get("/health")
async def health():
    return {"status": "ok"}


# TODO: implementar endpoint /query usando o pipeline RAG em rag_pipeline.py
