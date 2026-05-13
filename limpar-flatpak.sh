#!/bin/bash

# Script para limpeza segura do cache/objects do Flatpak
# Sem forçar reinstalação de aplicativos

echo "=== LIMPEZA SEGURA DO FLATPAK ==="
echo ""

# 1. Verificar espaço atual
echo "📊 Espaço atual do Flatpak:"
du -sh /var/lib/flatpak/repo/objects 2>/dev/null || echo "Pasta não encontrada"
echo ""

# 2. Limpeza oficial do Flatpak (remove apenas objetos não utilizados)
echo "🧹 Limpando objetos não referenciados (método oficial)..."
flatpak repair --user
flatpak repair --system

# 3. Remover runtimes e aplicativos não usados
echo ""
echo "🗑️  Removendo runtimes e aplicativos não utilizados..."
flatpak uninstall --unused --assumeyes

# 4. Limpar cache de downloads
echo ""
echo "📦 Limpando cache de downloads..."
flatpak uninstall --unused --delete-data --assumeyes
rm -rf ~/.cache/flatpak/*

# 5. Otimizar repositório (desduplicação segura)
echo ""
echo "⚡ Otimizando repositório..."
flatpak repair --repos --verify-summary

# 6. Opção extra: limpeza manual segura (apenas objetos não referenciados)
echo ""
echo "🔍 Verificando objetos órfãos..."
flatpak list --runtime --columns=application > /tmp/flatpak-apps.txt

# 7. Mostrar resultado da limpeza
echo ""
echo "✅ Limpeza concluída!"
echo ""
echo "📊 Espaço após limpeza:"
du -sh /var/lib/flatpak/repo/objects 2>/dev/null || echo "Pasta não encontrada"
echo ""
echo "📱 Aplicativos instalados:"
flatpak list --app
echo ""
echo "⚙️  Runtimes instalados:"
flatpak list --runtime