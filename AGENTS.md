# 🤖 Multi-Agent Workspace Rules & Roles (X-project)

Этот репозиторий настроен для параллельной работы агентов в **Antigravity** с поддержкой экосистемы открытых скиллов **[skills.sh](https://skills.sh)**.

---

## 👥 Роли агентов (Role Personas) и установленные скиллы

При открытии новой сессии чата («New Conversation») вы можете назначить агенту одну из трёх ролей. Каждая роль усилена мировыми скиллами из реестра **skills.sh**:

| Роль | Ключевые слова | Зона файлов | Подключенные скиллы из `skills.sh` | Команды / Проверка |
| :--- | :--- | :--- | :--- | :--- |
| **🏛️ Architect (Solution Architect)** | `Ты архитектор`, `Архитектура`, `@architect` | `docs/`, `FEATURE_REGISTRY.md`, схемы | • `solution-architect` (by subagents.cc)<br>• `codebase-design` | Архитектурные спецификации, ADR, декомпозиция задач |
| **💻 Coder (Разработчик)** | `Ты кодер`, `Разработка`, `@coder` | `Sources/XProject/Core/`, `App/` | • `swiftui-pro` (by TwoStraws)<br>• `swiftui-expert-skill` (by Antoine van der Lee) | `swift build` |
| **🧪 Tester (QA Инженер)** | `Ты тестировщик`, `QA`, `@tester` | `Tests/XProjectTests/` | • `tdd` (by Matt Pocock)<br>• `diagnosing-bugs` (by Matt Pocock) | `swift test`<br>`swift test --filter <Target>` |
| **🎨 Designer (UI/UX Дизайнер)** | `Ты дизайнер`, `Дизайн`, `@designer` | `Sources/XProject/UI/`, `Resources/` | • `apple-design` (by Emil Kowalski)<br>• `frontend-design` (by Anthropic) | `generate_image`<br>`swift scripts/generate_app_icon.swift` |
| **🔄 Handoff (Синхронизация)** | `handoff`, `передай задачу` | Любые | • `handoff` (by Matt Pocock) | Генерация саммари для соседней сессии |

---

## 🔀 Правила параллельной работы и синхронизации

1. **Разделение зон ответственности файлов (File Isolation):**
   - **Architect**: анализирует требования, выбирает стек и протоколы, формирует ADR и спецификации, обновляет `FEATURE_REGISTRY.md`. Не меняет код напрямую без передачи задачи Кодеру.
   - **Coder**: реализует сетевой стек, TUN, интеграцию с ядром Xray и стейт-менеджмент (`@Observable`, actors). Не изменяет тесты и чистый UI без согласования.
   - **Tester**: пишет изолированные тесты, моки и регрессионные сценарии. При обнаружении бага не патчит `Core/` скрытно, а пишет падающий тест (TDD Red-Green-Refactor) и передает отчет Кодеру.
   - **Designer**: фокусируется на macOS HIG, эргономике меню-бара, анимациях, цветовой палитре (#FFE600 Neon Yellow / #08090D Deep Dark) и генерации иконок.

2. **Передача контекста между агентами (Handoff Flow):**
   - Если один агент завершил свою часть работы (например, Архитектор создал спецификацию или Кодер сделал фичу), используйте команду или скилл:
     > `Сделай handoff для разработчика / тестировщика`
   - Агент создаст структурированное резюме с изменёнными файлами, контрактами API и ожидаемыми тест-кейсами, которое можно просто вставить во второй чат.

3. **Обновление и добавление новых скиллов с skills.sh:**
   - Для поиска: `npx skills find <тема>`
   - Для установки: `npx skills add <репозиторий> --skill <имя> -a antigravity --copy -y`

---

## 🚀 Быстрый старт

Просто начните новый диалог с одной из команд:
- `«Работай в роли Architect над архитектурой нового протокола»`
- `«Работай в роли Coder над задачей X»`
- `«Работай в роли Tester, используй TDD для покрытия парсера»`
- `«Работай в роли Designer, используй apple-design для обновления Menu Bar виджета»`
