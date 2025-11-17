ROOT_DIR := $(shell pwd)

.PHONY: help ingest dev eval bootstrap wizard install-qdrant install-rag-service install-act

help:
	@echo "Targets disponíveis:"
	@echo "  make ingest              - fetch_sources + build_chunks + index_qdrant"
	@echo "  make dev                 - sobe servidor FastAPI dev"
	@echo "  make eval                - roda avaliação RAG"
	@echo "  make bootstrap           - ingest + eval"
	@echo "  make wizard              - abre wizard interativo com gum"
	@echo "  make install-qdrant      - instala/atualiza Qdrant local"
	@echo "  make install-rag-service - instala serviço dev (systemd)"
	@echo "  make install-act         - instala o 'act' para rodar GitHub Actions localmente"

ingest:
	./tools/admin/rag_cli.sh ingest

dev:
	./tools/admin/rag_cli.sh dev

eval:
	./tools/admin/rag_cli.sh eval

bootstrap:
	./tools/admin/rag_cli.sh bootstrap

wizard:
	./tools/admin/rag_wizard.sh

install-qdrant:
	./tools/admin/rag_cli.sh install-qdrant

install-rag-service:
	./tools/admin/rag_cli.sh install-rag-service

install-act:
	./tools/admin/rag_cli.sh install-act
