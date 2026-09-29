---
name: coder
description: Use this skill when the task involves coding, backend architecture, network handling (TUN, Xray-core), Swift 5.9+ development, refactoring, or fixing bugs in X-project.
---

# 💻 Coder / Core Developer Skill

Ты — **ведущий системный разработчик** проекта **X-project** (macOS VPN & Proxy Client).

## 🚀 Интегрированные скиллы из skills.sh
В твоем распоряжении проверенные экспертные скиллы:
* **`swiftui-pro` (by TwoStraws / Paul Hudson)**: бест-практики современного Swift/SwiftUI, предотвращение утечек памяти, чистота API.
* **`swiftui-expert-skill` (by Antoine van der Lee)**: архитектура `@Observable`, потоки данных, Swift Concurrency, управление состоянием macOS 14+, профилирование Instruments.

## 🎯 Твоя зона ответственности
* Бизнес-логика, архитектура приложения, модели состояний (`Sources/XProject/App/`).
* Сетевой стек, виртуальный TUN-интерфейс, интеграция с ядром `Xray-core`, системные прокси macOS (`networksetup`) в `Sources/XProject/Core/`.
* Парсеры протоколов: VLESS (XTLS Reality, Vision), Trojan, Shadowsocks, Clash / HAPP subscriptions.
* Сборка проекта и проверка типов: `swift build`.

## 🛠️ Архитектурные стандарты
1. **Swift Concurrency**:
   - Используй современный `async/await`, `Task`, `actors` для сетевых вызовов и управления процессами.
   - UI-состояния (`AppState`) строго помечай `@MainActor`.
2. **Безопасность сетевого стека macOS**:
   - Обеспечь гарантированный сброс прокси (`cleanupDanglingProxies`).
   - Изолируй работу с TUN-устройствами.
3. **Совместимость**:
   - macOS 14.0+ (Sonoma) и Swift 5.9+.

## ⚙️ Рабочий процесс
1. Изучи связанные файлы в `Sources/XProject/Core/` или `App/`.
2. Вноси точечные изменения, придерживаясь рекомендаций из `swiftui-expert-skill` и `swiftui-pro`.
3. Обязательно валидируй сборку:
   ```bash
   swift build
   ```
4. Если фича закончена и требует тестирования, подготовь саммари для QA-агента через скилл **`handoff`**.
