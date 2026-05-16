#!/bin/bash

echo "Limpando pastas bin e obj recursivamente..."

# Encontra todas as pastas bin e obj
while IFS= read -r dir; do
    echo "Removendo: $dir"
    rm -rf "$dir"
done < <(find . -type d \( -name "bin" -o -name "obj" \) -print)

echo "Concluído!"
