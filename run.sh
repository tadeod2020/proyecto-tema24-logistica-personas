#!/usr/bin/env bash
# =====================================================================
# Script:      run.sh
# Autor:       Axel Tadeo Daniels Ceballos
# Curso:       Programación Lógica y Funcional (TecNM Campus Tijuana)
# Actividad:   Tema 24: Logística y Transporte Concurrente de Personas
# =====================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Asegurar compilación previa
if [ ! -f "ebin/logistica_app.beam" ]; then
    echo "[+] Compilando proyecto..."
    make compile
fi

echo "============================================================="
echo "   INICIANDO TRANSTIJUNA OTP — SISTEMA CONCURRENTE (TEMA 24)"
echo "   Autor: Axel Tadeo Daniels Ceballos · TecNM Campus Tijuana"
echo "============================================================="
echo ""
echo " -> Servidor Web & REST API: http://localhost:8080/"
echo " -> Shell Erlang interactivo disponible."
echo ""
echo " Comandos útiles en el shell de Erlang:"
echo "   1> logistica_gestor:listar_unidades()."
echo "   2> logistica_gestor:solicitar_viaje(\"Ana\", otay, centro)."
echo "   3> logistica_gestor:avanzar_unidad(unidad_1)."
echo "   4> logistica_gestor:provocar_crash(unidad_1). %% Demostrar 'let it crash'"
echo "   5> observer:start().                          %% Interfaz gráfica BEAM"
echo "   6> q().                                       %% Salir de Erlang"
echo ""
echo "============================================================="

exec erl -pa ebin -eval 'application:start(sasl), application:start(logistica).'
