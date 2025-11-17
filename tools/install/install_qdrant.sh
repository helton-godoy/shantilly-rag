#!/bin/bash

# Script de instalação e configuração do Qdrant (build local + systemd)
#
# Uso típico:
#   chmod +x tools/install/install_qdrant.sh
#   ./tools/install/install_qdrant.sh
#
# Reexecutar o script é seguro: ele é idempotente em relação ao usuário 'qdrant'
# e recria configuração/serviço conforme definido aqui.

# Saia imediatamente se um comando falhar
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- ETAPA 1: INSTALAR AS DEPENDÊNCIAS ---
echo "--- Atualizando pacotes e instalando dependências de build ---"
sudo apt-get update
sudo apt-get install -y curl git libclang-dev protobuf-compiler

# Instalar o rustup
if ! command -v rustup &>/dev/null; then
	echo "--- Instalando o rustup ---"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	source "$HOME/.cargo/env"
fi

# Certificar-se de que o toolchain Rust está atualizado
echo "--- Atualizando o Rust ---"
rustup update
rustup default stable

# --- ETAPA 2: COMPILAR O QDRANT ---
echo "--- Preparando código-fonte do Qdrant ---"
QDRANT_DIR="/home/$(whoami)/git/qdrant"
mkdir -p /home/"$(whoami)"/git

if [ -d "$QDRANT_DIR/.git" ]; then
	echo "--- Reutilizando repositório Qdrant existente em $QDRANT_DIR ---"
	cd "$QDRANT_DIR"
	git fetch --all --tags
	git pull --ff-only || git pull
else
	echo "--- Clonando repositório Qdrant ---"
	git clone https://github.com/qdrant/qdrant.git "$QDRANT_DIR"
	cd "$QDRANT_DIR"
fi

echo "--- Compilando Qdrant (cargo build --release --bin qdrant) ---"
cargo build --release --bin qdrant

# --- ETAPA 3: CONFIGURAR O SERVIÇO SYSTEMD ---
echo "--- Configurando o serviço systemd do Qdrant ---"

# Criar usuário e diretório de dados
if ! id qdrant &>/dev/null; then
	sudo useradd --system --no-create-home --shell /bin/false qdrant
fi
sudo mkdir -p /var/lib/qdrant
sudo chown -R qdrant:qdrant /var/lib/qdrant

# Copiar o binário para /usr/local/bin
# Se o serviço já estiver em execução, pare antes de atualizar o binário
if systemctl is-active --quiet qdrant.service; then
	echo "--- Parando serviço Qdrant para atualizar binário ---"
	sudo systemctl stop qdrant.service
fi
sudo cp "$QDRANT_DIR/target/release/qdrant" /usr/local/bin/

# Criar diretório para o arquivo de configuração e o arquivo
sudo mkdir -p /etc/qdrant
sudo tee /etc/qdrant/config.yaml >/dev/null <<EOF
# Configuração do serviço de rede
service:
  # O host em que o Qdrant irá ouvir. 
  # Use '127.0.0.1' para acesso apenas local; '0.0.0.0' o torna acessível de qualquer interface de rede.
  host: 127.0.0.1
  # Porta para a API HTTP
  http_port: 6333
  # Porta para a API gRPC (geralmente mais eficiente)
  grpc_port: 6334
  # Define um limite para o tamanho das requisições, útil para uploads de grandes dados
  max_request_size_mb: 64
  # Ativa o CORS para permitir requisições de diferentes domínios.
  # Se você estiver usando um proxy reverso como Nginx, pode desabilitar aqui.
  enable_cors: true
  # Se você quiser ativar a autenticação por API key, descomente a linha abaixo.
  # A chave deve ser enviada no cabeçalho 'api-key'.
  # api_key: "SUA_CHAVE_SECRETA_AQUI"

# Configurações de armazenamento de dados
storage:
  # Caminho para armazenar os dados de coleções, índices, etc.
  storage_path: /var/lib/qdrant
  # Caminho para armazenar os snapshots (backups).
  # snapshots_path: /var/backups/qdrant
  # Opções avançadas para armazenamento de payload. 
  # on_disk_payload: false salva payload na RAM para melhor performance.
  on_disk_payload: true

# Configurações de logging
log_level: INFO # Nível de detalhamento do log (DEBUG, INFO, WARN, ERROR)
# Você também pode configurar o Qdrant para escrever logs em um arquivo:
# logger:
#  on_disk:
#    enabled: true
#    log_file: /var/log/qdrant/qdrant.log
#    rotation_size_mb: 200 # Rotacionar arquivo de log ao atingir 200MB
#    rotation_period: 1w # Rotacionar semanalmente

# Configurações de performance
performance:
  # Número máximo de threads de busca, útil para controlar o consumo de CPU.
  # Se estiver nulo, usará o máximo disponível.
  max_search_threads: null
  # Limite de threads de otimização, útil para restringir operações intensivas.
  max_optimization_threads: null

EOF

# Criar o arquivo de serviço systemd
TEMPLATE_SERVICE="$ROOT_DIR/tools/templates/service/qdrant.service"
if [ ! -f "$TEMPLATE_SERVICE" ]; then
	echo "[install_qdrant] Template de serviço não encontrado: $TEMPLATE_SERVICE" >&2
	exit 1
fi

echo "--- Instalando unidade systemd do Qdrant a partir de template ---"
sudo cp "$TEMPLATE_SERVICE" /etc/systemd/system/qdrant.service

# --- ETAPA 4: INICIAR E HABILITAR O SERVIÇO ---
echo "--- Iniciando e habilitando o serviço Qdrant ---"
sudo systemctl daemon-reload
sudo systemctl enable qdrant.service
sudo systemctl restart qdrant.service
sudo systemctl status qdrant.service --no-pager || true

echo "--- A instalação do Qdrant foi concluída com sucesso! ---"
echo "Você pode verificar o serviço com 'sudo systemctl status qdrant.service'."
echo "Para verificar o servidor, use 'curl http://127.0.0.1:6333/'."
