#!/bin/bash

if [ -z "$1" ]; then
    echo "Uso: $0 <expresion_algebraica> [modo_opt: normal|optimized]"
    exit 1
fi

EXPRESION="$1"
# Si no se pasa el segundo argumento, por defecto usamos "normal"
OPT_MODE="${2:-normal}"
EXECUTABLE="./prueba3D"

if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: No se encuentra el binario en '$EXECUTABLE'."
    exit 1
fi

if [ "$OPT_MODE" != "normal" ] && [ "$OPT_MODE" != "optimized" ]; then
    echo "Error: El modo de optimización debe ser 'normal' o 'optimized'."
    exit 1
fi

rm -f tiempos.txt
touch tiempos.txt

echo "=== Iniciando batería de pruebas en modo: [$OPT_MODE] ==="

for puntos in 100 200 350 500 650 750; do
    subrectas=$((puntos / 2))
    sample_subrectas=4
    sample_linea=4

    if [ "$OPT_MODE" = "optimized" ]; then
        # --- MODO OPTIMIZED: Compara Parallel Normal vs Parallel Optimized ---
        
        # 1. Ejecución Paralela Normal
        resultado_par_norm=$($EXECUTABLE "$EXPRESION" "$puntos" "$subrectas" "$sample_subrectas" "$sample_linea" "parallel" "normal" | tail -n 1)
        if [ ! -z "$resultado_par_norm" ]; then
            echo "$resultado_par_norm" >> tiempos.txt
        fi

        # 2. Ejecución Paralela Optimizada
        resultado_par_opt=$($EXECUTABLE "$EXPRESION" "$puntos" "$subrectas" "$sample_subrectas" "$sample_linea" "parallel" "optimized" | tail -n 1)
        if [ ! -z "$resultado_par_opt" ]; then
            echo "$resultado_par_opt" >> tiempos.txt
        fi
        
        echo "Batería Parallel (Normal vs Optimized) para entrada $puntos completa"

    else
        # --- MODO NORMAL: Compara Secuencial vs Parallel Normal ---
        
        # 1. Ejecución Secuencial
        resultado_sec=$($EXECUTABLE "$EXPRESION" "$puntos" "$subrectas" "$sample_subrectas" "$sample_linea" "sec" "normal" | tail -n 1)
        if [ ! -z "$resultado_sec" ]; then
            echo "$resultado_sec" >> tiempos.txt
        fi
        
        # 2. Ejecución Paralela Normal
        resultado_par_norm=$($EXECUTABLE "$EXPRESION" "$puntos" "$subrectas" "$sample_subrectas" "$sample_linea" "parallel" "normal" | tail -n 1)
        if [ ! -z "$resultado_par_norm" ]; then
            echo "$resultado_par_norm" >> tiempos.txt
        fi
        
        echo "Batería Estándar (Secuencial vs Parallel) para entrada $puntos completa"
    fi
done

echo "=== Pruebas completadas ==="
cat tiempos.txt
