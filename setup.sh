#!/usr/bin/env bash
# =====================================================================
# Script:      setup.sh
# Autor:       Axel Tadeo Daniels Ceballos
# Curso:       Programación Lógica y Funcional (TecNM Campus Tijuana)
# Actividad:   Tema 24: Logística y Transporte Concurrente de Personas
# Propósito:   Aprovisionamiento y configuración automatizada para VM Linux
#              (Ubuntu 22.04/24.04 LTS, Debian 12, AWS Academy EC2)
# =====================================================================

set -e

echo "============================================================="
echo "   INSTALACIÓN Y CONFIGURACIÓN — TRANSTIJUNA OTP (TEMA 24)  "
echo "   Autor: Axel Tadeo Daniels Ceballos · TecNM Campus Tijuana"
echo "============================================================="

# 1. Detección de privilegios y distribución
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" != "Linux" ] && [ "$OS_TYPE" != "Darwin" ]; then
    echo "[-] Sistema operativo no compatible: $OS_TYPE. Se recomienda Linux o macOS."
fi

echo "[+] Paso 1/4: Verificando dependencias del sistema..."

# Verificar si erlang y build-essential están instalados
if ! command -v erl &> /dev/null || ! command -v erlc &> /dev/null; then
    echo "[!] Erlang/OTP no encontrado en el sistema. Instalando..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y erlang erlang-eunit build-essential curl git
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy --noconfirm erlang base-devel curl git
    elif command -v brew &> /dev/null; then
        brew install erlang
    else
        echo "[-] Gestor de paquetes no reconocido. Instala Erlang/OTP manualmente: https://www.erlang.org/downloads"
        exit 1
    fi
else
    echo "[+] Erlang/OTP detectado correctamente:"
    erl -eval 'io:format("    Release OTP: ~s (BEAM emulator ~s)~n", [erlang:system_info(otp_release), erlang:system_info(version)]), halt().' -noshell
fi

# 2. Verificar compilador make
if ! command -v make &> /dev/null; then
    echo "[!] make no encontrado. Instalando..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y build-essential
    fi
fi

# 3. Compilación de módulos Erlang
echo "[+] Paso 2/4: Compilando módulos Erlang en ebin/..."
mkdir -p ebin
make compile

# 4. Verificación de tests EUnit
echo "[+] Paso 3/4: Ejecutando suite de pruebas automatizadas EUnit..."
make test

# 5. Finalización
echo "[+] Paso 4/4: Configuración completada con éxito."
echo ""
echo "============================================================="
echo " ¡PROYECTO LISTO PARA EJECUCIÓN!"
echo " Para iniciar el sistema y servidor web ejecuta:"
echo "   ./run.sh"
echo " O para ver la demostración interactiva en consola:"
echo "   ./test_demo.sh"
echo "============================================================="
