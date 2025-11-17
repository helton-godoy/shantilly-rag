#!/bin/bash

RELATORIO="relatorio_pci_amigavel.txt"
echo "Relatório de Hardware PCI - $(date)" > "$RELATORIO"
echo "==========================================" >> "$RELATORIO"
echo "" >> "$RELATORIO"

# Função para traduzir a classe para um título amigável
class_to_title() {
    case "$1" in
        "Multimedia audio controller") echo "DISPOSITIVOS DE ÁUDIO";;
        "Network controller") echo "REDE SEM FIO (Wi-Fi)";;
        "Ethernet controller") echo "REDE COM FIO (Ethernet)";;
        "VGA compatible controller") echo "PLACA DE VÍDEO INTEGRADA";;
        "3D controller") echo "PLACA DE VÍDEO DEDICADA";;
        "USB controller") echo "CONTROLADOR USB";;
        "Serial bus controller") echo "CONTROLADOR SERIAL/I2C/SPI";;
        "Signal processing controller") echo "CONTROLADOR DE SINAL";;
        "Communication controller") echo "CONTROLADOR DE COMUNICAÇÃO";;
        "RAID bus controller") echo "CONTROLADOR RAID";;
        "Non-Volatile memory controller") echo "CONTROLADOR DE ARMAZENAMENTO NVMe";;
        "SATA controller") echo "CONTROLADOR SATA";;
        "RAM memory") echo "MEMÓRIA RAM COMPARTILHADA";;
        "Host bridge") echo "PONTE DO PROCESSADOR";;
        "System peripheral") echo "PERIFÉRICO DO SISTEMA";;
        "PCI bridge") echo "PONTE PCI EXPRESS";;
        "ISA bridge") echo "PONTE ISA";;
        "SMBus") echo "CONTROLADOR SMBus";;
        *) echo "DISPOSITIVO DESCONHECIDO";;
    esac
}

# Lê a saída do lspci -vmm linha por linha
while IFS= read -r line; do
    if [[ $line == Slot:* ]]; then
        slot=$(echo "${line#Slot:}" | xargs)
    fi

    if [[ $line == Class:* ]]; then
        class=$(echo "${line#Class:}" | xargs)
        titulo=$(class_to_title "$class")

        echo "==================================================" >> "$RELATORIO"
        echo "      $titulo" >> "$RELATORIO"
        echo "==================================================" >> "$RELATORIO"
        echo "" >> "$RELATORIO"

        lspci -vvv -s "$slot" >> "$RELATORIO"
        echo "" >> "$RELATORIO"
    fi
done < <(lspci -vmm)

echo "Relatório gerado com sucesso em: $RELATORIO"