#!/bin/bash
set -e

echo "🧹 Очистка тестовых данных и настроек приложения X-project..."
DATA_DIR="$HOME/Library/Application Support/XProject"

if [ -d "$DATA_DIR" ]; then
    rm -rf "$DATA_DIR"
    echo "  ✔ Удалена директория конфигурации: $DATA_DIR"
fi

# Очистка UserDefaults
defaults delete com.xproject.client 2>/dev/null || true
echo "  ✔ Сброшены системные настройки UserDefaults (com.xproject.client)"

# Очистка системных прокси если они оставались активными
for service in "Wi-Fi" "Thunderbolt Bridge" "Ethernet" "iPhone USB"; do
    networksetup -setwebproxystate "$service" off 2>/dev/null || true
    networksetup -setsecurewebproxystate "$service" off 2>/dev/null || true
    networksetup -setsocksfirewallproxystate "$service" off 2>/dev/null || true
done
echo "  ✔ Прокси-настройки сетевых служб macOS приведены в исходное состояние"

echo "✨ Все настройки, конфигурация, подписки и серверы успешно очищены!"
echo "🚀 Теперь можно тестировать приложение с чистого листа."
