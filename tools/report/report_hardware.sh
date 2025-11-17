#!/bin/bash

# ==============================================================================
#
# Script de Informações do Sistema v6.0 (Compatível com Debian)
#
# Descrição: Versão robusta com verificação de dependências centralizada
#            para garantir a execução em sistemas baseados em Debian.
#
# ==============================================================================

# --- CONFIGURAÇÕES DE APRESENTAÇÃO ---
HEADER_COLOR='\033[1;36m' # Ciano Brilhante
TITLE_COLOR='\033[1;33m'  # Amarelo Brilhante
VALUE_COLOR='\033[0;37m'  # Branco
ERROR_COLOR='\033[1;31m'  # Vermelho Brilhante
NC='\033[0m'              # Sem Cor (reset)

TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80) # Define 80 como padrão se tput falhar

# --- 1. VERIFICAÇÃO DE DEPENDÊNCIAS ---

# Mapeia comandos para os pacotes Debian necessários
declare -A DEPS
DEPS=(
    ["dmidecode"]="dmidecode"
    ["lspci"]="pciutils"
    ["lsusb"]="usbutils"
    ["xrandr"]="x11-xserver-utils"
    ["aplay"]="alsa-utils"
    ["xinput"]="xinput"
    ["column"]="bsdmainutils"
)

missing_packages=()
echo "Verificando dependências..."
for cmd in "${!DEPS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        package=${DEPS[$cmd]}
        # Evita adicionar pacotes duplicados à lista
        if [[ ! " ${missing_packages[@]} " =~ " ${package} " ]]; then
            missing_packages+=("$package")
        fi
    fi
done

# Se houver pacotes faltando, exibe uma mensagem de ajuda e sai
if [ ${#missing_packages[@]} -gt 0 ]; then
    clear
    echo -e "${ERROR_COLOR}ERRO: Ferramentas necessárias não encontradas.${NC}"
    echo "Para garantir que o script funcione corretamente, algumas dependências precisam ser instaladas."
    echo ""
    echo "Por favor, execute o seguinte comando para instalá-las:"
    echo -e "${TITLE_COLOR}sudo apt update && sudo apt install -y ${missing_packages[*]}${NC}"
    echo ""
    echo "Após a instalação, execute o script novamente."
    exit 1
fi
echo "Todas as dependências estão satisfeitas."
sleep 1 # Pequena pausa para o usuário ler a mensagem

# --- FUNÇÕES AUXILIARES ---
print_separator() {
    printf "${HEADER_COLOR}%.s─${NC}" $(seq 1 $TERMINAL_WIDTH)
    echo ""
}

# --- FUNÇÕES DE GERAÇÃO DE CONTEÚDO ---
# (As funções agora assumem que todos os comandos existem)

generate_system_info() {
    echo -e "${TITLE_COLOR}--- Sistema ---${NC}"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Sistema Operacional" "$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Hostname" "$(hostname)"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Kernel" "$(uname -r)"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Arquitetura" "$(uname -m)"
}

generate_computer_info() {
    echo -e "${TITLE_COLOR}--- Computador ---${NC}"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Fabricante" "$(sudo dmidecode -s system-manufacturer 2>/dev/null)"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Modelo" "$(sudo dmidecode -s system-product-name 2>/dev/null)"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Número de Série" "$(sudo dmidecode -s system-serial-number 2>/dev/null)"
    echo "" # Linha vazia para alinhamento
}

generate_cpu_info() {
    echo -e "${TITLE_COLOR}--- Processador (CPU) ---${NC}"
    CPU_INFO=$(lscpu)
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Modelo" "$(echo "$CPU_INFO" | grep 'Model name:' | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Frequência Máxima" "$(echo "$CPU_INFO" | grep 'CPU max MHz:' | cut -d ':' -f 2 | sed 's/^[ \t]*//' | awk '{printf "%.2f GHz", $1/1000}')"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Núcleos Físicos" "$(echo "$CPU_INFO" | grep 'Core(s) per socket:' | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Total de Threads" "$(echo "$CPU_INFO" | grep '^CPU(s):' | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Cache L3" "$(echo "$CPU_INFO" | grep 'L3 cache:' | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
}

generate_memory_info() {
    echo -e "${TITLE_COLOR}--- Memória (RAM) ---${NC}"
    mapfile -t mem_info < <(free -h | grep Mem)
    mem_total=$(echo "${mem_info[0]}" | awk '{print $2}')
    mem_used=$(echo "${mem_info[0]}" | awk '{print $3}')
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Total Instalada" "$mem_total"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Em Uso" "$mem_used"
    echo "" # Linhas vazias para alinhar com a caixa da CPU
    echo ""
    echo ""
}

generate_board_info() {
    echo -e "${TITLE_COLOR}--- Placa-mãe ---${NC}"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Fabricante" "$(sudo dmidecode -s baseboard-manufacturer 2>/dev/null)"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Modelo" "$(sudo dmidecode -s baseboard-product-name 2>/dev/null)"
}

generate_bios_info() {
    echo -e "${TITLE_COLOR}--- BIOS ---${NC}"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Versão" "$(sudo dmidecode -s bios-version 2>/dev/null)"
    printf "  %-20s: ${VALUE_COLOR}%s${NC}\n" "Data" "$(sudo dmidecode -s bios-release-date 2>/dev/null)"
}

generate_gpu_info() {
    echo -e "${TITLE_COLOR}--- Dispositivos Gráficos (GPU) ---${NC}"
    lspci | grep -i 'vga\|3d\|display' | while read -r line; do
      printf "  ${VALUE_COLOR}- %s${NC}\n" "$(echo "$line" | cut -d ':' -f3 | sed 's/ (rev [^)]*)//' | sed 's/^[ \t]*//')"
    done
}

generate_monitor_info() {
    echo -e "${TITLE_COLOR}--- Monitores Conectados ---${NC}"
    xrandr --query | grep " connected" | while read -r line; do
        printf "  ${VALUE_COLOR}- %s${NC}\n" "$(echo "$line" | cut -d' ' -f1,3-)"
    done
}

generate_network_info() {
    echo -e "${TITLE_COLOR}--- Rede ---${NC}"
    printf "  ${VALUE_COLOR}Hardware:${NC}\n"
    lspci | grep -i 'ethernet\|network' | while read -r line; do
        printf "    ${VALUE_COLOR}- %s${NC}\n" "$(echo "$line" | cut -d ':' -f3 | sed 's/ (rev [^)]*)//' | sed 's/^[ \t]*//')"
    done
    printf "\n  ${VALUE_COLOR}Interfaces:${NC}\n"
    ip -brief a | while read -r line; do
        printf "    ${VALUE_COLOR}%s${NC}\n" "$line"
    done
}

generate_audio_info() {
    echo -e "${TITLE_COLOR}--- Áudio ---${NC}"
    printf "  ${VALUE_COLOR}Hardware:${NC}\n"
    lspci | grep -i audio | while read -r line; do
      printf "    ${VALUE_COLOR}- %s${NC}\n" "$(echo "$line" | cut -d ':' -f3 | sed 's/ (rev [^)]*)//' | sed 's/^[ \t]*//')"
    done
    printf "\n  ${VALUE_COLOR}Dispositivos de Saída:${NC}\n"
    aplay -l | grep 'card' | while read -r line; do
         printf "    ${VALUE_COLOR}%s${NC}\n" "$line"
    done
}

generate_storage_info() {
    echo -e "${TITLE_COLOR}--- Armazenamento (Discos e Partições) ---${NC}"
    # A opção --bytes força a saída em bytes, que é mais consistente para 'column'
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT --bytes | column -t
}

generate_usb_info() {
    echo -e "${TITLE_COLOR}--- Dispositivos USB ---${NC}"
    lsusb
}

generate_input_info() {
    echo -e "${TITLE_COLOR}--- Dispositivos de Entrada ---${NC}"
    xinput list
}


# --- FUNÇÃO PRINCIPAL DE LAYOUT ---

clear
HEADER_TEXT="RELATÓRIO DE HARDWARE (COMPATÍVEL COM DEBIAN)"
printf "${HEADER_COLOR}%*s${NC}\n" $(((${#HEADER_TEXT} + TERMINAL_WIDTH) / 2)) "$HEADER_TEXT"
echo ""

# --- Layout em Colunas ---
paste -d '\0' <(generate_system_info) <(generate_computer_info)
print_separator
paste -d '\0' <(generate_cpu_info) <(generate_memory_info)
print_separator
paste -d '\0' <(generate_board_info) <(generate_bios_info)
print_separator
paste -d '\0' <(generate_gpu_info) <(generate_monitor_info)
print_separator
# A seção de Rede/Áudio pode ter tamanhos variados, então usamos um separador para garantir o alinhamento
paste -d '\0' <(generate_network_info) <(generate_audio_info)
print_separator

# --- Seções de Largura Completa ---
generate_storage_info
print_separator
generate_usb_info
print_separator
generate_input_info
print_separator

echo -e "${HEADER_COLOR}Fim do Relatório.${NC}"
echo ""