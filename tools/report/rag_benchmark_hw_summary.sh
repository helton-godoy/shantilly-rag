#!/usr/bin/env bash
set -euo pipefail

# Resumo compacto de hardware para uso em relatórios de benchmark (formato Markdown).

# Sistema operacional
if [[ -r /etc/os-release ]]; then
  OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')
else
  OS_NAME=$(uname -s)" "$(uname -r)
fi

# CPU
CPU_MODEL=""
CPU_THREADS=""
CPU_CORES=""
if command -v lscpu >/dev/null 2>&1; then
  # Força saída em inglês para ter rótulos estáveis, com fallback para locale atual
  LSC_OUT="$(LC_ALL=C lscpu 2>/dev/null || lscpu 2>/dev/null || true)"

  CPU_MODEL="$(echo "$LSC_OUT" | awk -F: '/Model name:/ {gsub(/^ +/, "", $2); print $2; exit}')"
  CPU_THREADS="$(echo "$LSC_OUT" | awk -F: '/^CPU\(s\):/ {gsub(/^ +/, "", $2); print $2; exit}')"
  CPU_CORES="$(echo "$LSC_OUT" | awk -F: '/Core\(s\) per socket:/ {gsub(/^ +/, "", $2); print $2; exit}')"
fi

# Memória
MEM_TOTAL=""
if command -v free >/dev/null 2>&1; then
  MEM_TOTAL="$(LC_ALL=C free -h | awk '/^Mem:/ {print $2; exit}')"
fi

# GPUs
GPU_LIST=""
if command -v lspci >/dev/null 2>&1; then
  GPU_LIST=$(lspci | grep -i 'vga\|3d\|display' | sed 's/.*controller: //I' | sed 's/ (rev .*)//') || true
fi

echo "- Sistema: ${OS_NAME:-desconhecido}"

if [[ -n "$CPU_MODEL" ]]; then
  EXTRA=""
  if [[ -n "$CPU_CORES" ]]; then
    EXTRA+="${CPU_CORES} cores físicos"
  fi
  if [[ -n "$CPU_THREADS" ]]; then
    if [[ -n "$EXTRA" ]]; then EXTRA+=" / "; fi
    EXTRA+="${CPU_THREADS} threads"
  fi
  if [[ -n "$EXTRA" ]]; then
    echo "- CPU: $CPU_MODEL (${EXTRA})"
  else
    echo "- CPU: $CPU_MODEL"
  fi
fi

if [[ -n "$MEM_TOTAL" ]]; then
  echo "- RAM: ${MEM_TOTAL} de memória instalada"
fi

if [[ -n "$GPU_LIST" ]]; then
  echo "- GPUs:"
  while IFS= read -r gpu; do
    [[ -z "$gpu" ]] && continue
    echo "  - $gpu"
  done <<< "$GPU_LIST"
fi
