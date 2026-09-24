# Реестр реализованных функций и матрица регрессионного контроля X-project (Feature Registry & Regression Matrix)

> **Назначение документа**: Данный реестр служит единым источником правды о реализованном функционале **X-project**. При внесении любых изменений, добавлении новых возможностей или рефакторинге кодовой базы необходимо сверяться с этой матрицей, чтобы убедиться, что существующие фичи **не были затронуты, перетёрты или сломаны**.

---

## 📋 Быстрый протокол проверки перед релизом / коммитом

При любых доработках обязательно выполнить следующий чек-лист:

```bash
# 1. Запуск полного встроенного набора тестов (все 20 тестов должны пройти с кодом 0):
swift run X-project --test

# 2. Проверка восстановления сервера и автозапуска через тестовый запуск:
swift run X-project --test-launch

# 3. Пересборка релизного .app бандла:
./scripts/build_app.sh

# 4. Проверка холодного старта бандла, поднятия ядра Xray и установки системных прокси:
open ./build/X-project.app
sleep 2
ps aux | grep xray | grep -v grep
networksetup -getwebproxy Wi-Fi
networksetup -getsocksfirewallproxy Wi-Fi
```

---

## 🗂 Структура параметров матрицы фичей

Для каждой функции зафиксированы следующие параметры контроля:
* **ID**: Уникальный идентификатор фичи.
* **Название и назначение**: Что делает фича и какую задачу решает.
* **Файлы реализации**: Ссылки на файлы исходного кода.
* **Ключевые методы и свойства**: Конкретные функции и структуры в Swift.
* **Хранилище / Персистентность**: Где и как сохраняется состояние (JSON, UserDefaults, Memory).
* **Граничные случаи (Edge Cases)**: Условия, которые легко сломать (пустой список, смена хоста, падение ядра, отсутствие сети).
* **Риски рефакторинга**: На что обратить особое внимание, чтобы не перетереть логику.
* **Способ верификации**: Автотест или команда для проверки.
* **Статус**: Текущее состояние реализации.

---

## 1. Персистентность состояния, автозапуск и жизненный цикл

| ID | Фича | Файлы реализации | Персистентность | Риски рефакторинга | Способ проверки | Статус |
|---|---|---|---|---|---|---|
| **FEAT-PERSIST-01** | **5-уровневое восстановление выбранного сервера** | [AppState.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/AppState.swift)<br>[AppSettings.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Models/AppSettings.swift) | `settings.json`<br>`UserDefaults.standard` | При обновлении подписок хосты серверов меняются (`cloud.figmafound.org` ➔ `api.figmafound.org`). Нельзя сбрасывать сервер на первый в списке! Должен работать поиск по `preferringName` и `lastSelectedServerName`. | `swift run X-project --test` (Тест 4/5)<br>Смена домена в подписке | ✅ Работает |
| **FEAT-PERSIST-02** | **Автоподключение туннеля при запуске («Автозапуск»)** | [XProjectApp.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/XProjectApp.swift)<br>[AppState.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/AppState.swift) | `settings.autoConnectOnLaunch`<br>`UserDefaults ("autoConnectOnLaunch")` | Синхронный вызов в `applicationDidFinishLaunching` может сработать до загрузки списка серверов из диска. Требуется `DispatchQueue.main.asyncAfter(0.3s)` + страховочный триггер после окончания загрузки подписок. | `swift run X-project --test-launch`<br>Проверка `ps aux \| grep xray` | ✅ Работает |
| **FEAT-PERSIST-03** | **Отказоустойчивая сериализация AppSettings** | [AppSettings.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Models/AppSettings.swift) | `settings.json` (атомарная запись) | Если добавить новое свойство в `AppSettings` без кастомного `init(from decoder:)`, старый `settings.json` вызовет краш декодирования и сбросит все настройки пользователя. | Декодирование JSON с отсутствующими ключами | ✅ Работает |
| **FEAT-PERSIST-04** | **Корректный сброс прокси при выходе и сбоях** | [XProjectApp.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/XProjectApp.swift)<br>[SystemProxyManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Network/SystemProxyManager.swift) | `applicationWillTerminate`<br>`cleanupDanglingProxies()` | При аварийном завершении приложения (crash/kill -9) системные прокси могут остаться включенными, ломая интернет на Mac. При старте `cleanupDanglingProxies()` обязан сбрасывать «висячие» 127.0.0.1 прокси. | Принудительное закрытие процесса и проверка сети | ✅ Работает |
| **FEAT-PERSIST-05** | **Изоляция тестов от пользовательских настроек** | [SelfTestRunner.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Testing/SelfTestRunner.swift) | Временный бэкап и восстановление через `defer` | Тесты не должны перезаписывать реальный `settings.json` и `servers.json` пользователя фейковыми тестовыми нодами («Persist Node 2»). | Запуск `swift run X-project --test` и сверка `settings.json` | ✅ Работает |

---

## 2. Сетевой стек, перехват трафика и системные прокси macOS

| ID | Фича | Файлы реализации | Ключевые параметры | Граничные условия / Особенности | Способ проверки | Статус |
|---|---|---|---|---|---|---|
| **FEAT-NET-01** | **Системный SOCKS5 & HTTP/HTTPS прокси** | [SystemProxyManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Network/SystemProxyManager.swift) | SOCKS: `127.0.0.1:10808`<br>HTTP: `127.0.0.1:10809`<br>HTTPS: `127.0.0.1:10809` | Должен включаться для всех активных физических служб (Wi-Fi, Ethernet). Обязательно исключать виртуальные адаптеры Tailscale, WireGuard, Happ, чтобы не создать циклический шторм пакетов. | `networksetup -getwebproxy Wi-Fi`<br>`networksetup -getsocksfirewallproxy Wi-Fi` | ✅ Работает |
| **FEAT-NET-02** | **TUN интерфейс / Системный перехват** | [TUNManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Network/TUNManager.swift) | Потокобезопасный `NSLock`, флаг `isActive` | Поддерживает переключение между TUN и системным прокси. В пользовательском режиме активирует системный стек маршрутизации. | `swift run X-project --test` (Тест 5/5) | ✅ Работает |
| **FEAT-NET-03** | **Измерение TCP-задержки (Ping)** | [LatencyTester.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Network/LatencyTester.swift) | Одиночный пинг: `measureLatency`<br>Пакетный: `measureBatch` | Таймаут соединения 2.5с. Не блокирует UI поток (Task / async). Сохраняет результат в `server.pingMs` и `server.lastTestedAt`. | Кнопка «Пинг всех» в шапке списка серверов | ✅ Работает |
| **FEAT-NET-04** | **Онлайн-валидация выхода в интернет** | [AppState.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/AppState.swift) (`checkLiveProxyReachability`) | HTTP `curl -x http://127.0.0.1:10809` к `https://api.ipify.org` | Таймаут 4с. Выполняется через 1.2с после подъема Xray. Если нода «мертвая» (таймаут рукопожатия Reality), сообщает пользователю предупреждение в лог. | Лог в консоли: «✅ Туннель подтвержден! Внешний IP: ...» | ✅ Работает |
| **FEAT-NET-05** | **Защищенный DNS (DNS over HTTPS / DoH)** | [NetworkTab.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/NetworkTab.swift)<br>[XrayConfigGenerator.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayConfigGenerator.swift) | Поле ввода URL DoH + пресеты: Cloudflare, Google, AdGuard, Quad9 | Передается в секцию `"dns"` Xray-конфига. В Global-режиме запросы к IP резолверов направляются напрямую во избежание deadlock. | Проверка секции `"dns"` в `config.json` | ✅ Работает |

---

## 3. Ядро Xray-core и генерация конфигурации

| ID | Фича | Файлы реализации | Ключевые параметры | Граничные условия / Особенности | Способ проверки | Статус |
|---|---|---|---|---|---|---|
| **FEAT-CORE-01** | **Управление бинарником и процессом Xray** | [XrayProcessManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayProcessManager.swift)<br>[XrayBinaryManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayBinaryManager.swift) | Запуск: `run -c config.json`<br>Потоки `stdout` & `stderr`<br>`onUnexpectedTermination` | Парсинг путей к бинарнику в бандле `.app` (`Contents/Resources/xray/xray`) с фоллбэком на локальную папку `./bin/xray/xray`. Детекция краша ядра с кодом завершения. | `ps aux \| grep xray`<br>Тест 3/5 в SelfTest | ✅ Работает |
| **FEAT-CORE-02** | **Генератор конфигурации Xray JSON** | [XrayConfigGenerator.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayConfigGenerator.swift) | `inbounds` (SOCKS 10808, HTTP 10809)<br>`outbounds` (proxy, direct, block)<br>`routing` | Сборка валидного JSON с подстановкой `encryption: none`, поддержкой XTLS-Reality (`publicKey`, `shortId`, `spiderX`, `fingerprint: chrome/qq/firefox`). | `xray -test -c config.json` (Тест 3/5) | ✅ Работает |
| **FEAT-CORE-03** | **Поддержка обхода блокировок DPI (Fragment)** | [XrayConfigGenerator.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayConfigGenerator.swift)<br>[JSONConfigParser.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Parsers/JSONConfigParser.swift) | `fragment`: `packets: 1-3`, `length: 50-100`, `interval: 10-20` | Сохранение блока `fragment` из входящих JSON подписок (UltimaVPN) в аутбаунд Xray для успешного пробития блокировок ТСПУ в РФ. | Тест валидации Fragment в SelfTestRunner | ✅ Работает |
| **FEAT-CORE-04** | **Защита от DNS-зацикливания в Global Mode** | [XrayConfigGenerator.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayConfigGenerator.swift) | Правила direct для порта `53` и IP `1.1.1.1`, `8.8.8.8` | Без прямых правил для DNS в глобальном режиме Xray не может зарезолвить домен прокси-ноды (циклическая блокировка). | Успешное подключение в режиме «Глобальный» | ✅ Работает |

---

## 4. Сетевые парсеры, форматы ссылок и подписки

| ID | Фича | Файлы реализации | Поддерживаемые форматы | Граничные условия / Особенности | Способ проверки | Статус |
|---|---|---|---|---|---|---|
| **FEAT-PARSE-01** | **Парсер протокола VLESS** | [VLESSParser.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Parsers/VLESSParser.swift) | `vless://uuid@host:port?...` | XTLS-Reality, Vision (`flow=xtls-rprx-vision`), gRPC, WebSocket, TCP, IPv6 хосты в квадратных скобках `[::1]`. | Тест 1/5 в SelfTestRunner | ✅ Работает |
| **FEAT-PARSE-02** | **Парсер протокола Trojan** | [TrojanParser.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Parsers/TrojanParser.swift) | `trojan://password@host:port?...` | TLS, WebSocket с `path`, ALPN, SNI, pinned peer cert SHA256. | Тест 1/5 в SelfTestRunner | ✅ Работает |
| **FEAT-PARSE-03** | **Парсер Shadowsocks SIP002** | [ShadowsocksParser.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Parsers/ShadowsocksParser.swift) | `ss://base64(method:password)@host:port` | Base64 с padding и без (`=`), legacy и modern SIP002 URL, IPv6 адреса. | Тест 1/5 в SelfTestRunner | ✅ Работает |
| **FEAT-PARSE-04** | **Парсер JSON-массивов подписок (UltimaVPN/Happ)** | [JSONConfigParser.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Parsers/JSONConfigParser.swift) | `[ { "remarks": "...", "outbounds": [...] } ]` | Извлечение `remarks`, распознавание флагов стран, сохранение `rawJsonConfig` и параметров обхода DPI. | Тест парсинга UltimaVPN JSON в SelfTest | ✅ Работает |
| **FEAT-PARSE-05** | **Универсальный MIME & Base64 детектор** | [URLSchemeParser.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Parsers/URLSchemeParser.swift) | Base64, JSON, Raw URL list | Устойчивость к переводам строк MIME `\r\n`, авто-детектирование скрытого JSON внутри Base64, отсев битых строк. | Тест 1/5 в SelfTestRunner | ✅ Работает |
| **FEAT-PARSE-06** | **HTTP-заголовки подписки (Квота и маршрутизация)** | [SubscriptionManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Subscriptions/SubscriptionManager.swift) | `subscription-userinfo`, `profile-title`, заголовок `routing:` | Парсинг израсходованного/общего трафика, даты экспирации и авто-предложение применить переданные сервером правила маршрутизации в 1 клик. | Загрузка живой подписки UltimaVPN | ✅ Работает |
| **FEAT-PARSE-07** | **Оптическое распознавание QR с экрана Mac** | [ScreenQRScanner.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Scanner/ScreenQRScanner.swift) | Apple Vision `VNDetectBarcodesRequest`<br>CoreImage `CIDetector` | Снимок экранов Mac ➔ поиск штрихкодов ➔ декодирование ссылки ➔ авто-добавление сервера/подписки в AppState. | Тест 2/5 в SelfTestRunner | ✅ Работает |

---

## 5. Маршрутизация, правила и гео-базы

| ID | Фича | Файлы реализации | Ключевые компоненты | Граничные условия / Особенности | Способ проверки | Статус |
|---|---|---|---|---|---|---|
| **FEAT-ROUTE-01** | **Режимы Split Tunneling vs Global** | [RoutingTab.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/RoutingTab.swift)<br>[RoutingConfig.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Models/RoutingRule.swift) | `ProxyRoutingMode.ruleBased`<br>`ProxyRoutingMode.global` | При переключении режима в интерфейсе немедленно синхронизируется с `settings.routingMode` и сохраняется в `routing.json` и `settings.json`. | Проверка переключения режима в UI и файла `routing.json` | ✅ Работает |
| **FEAT-ROUTE-02** | **Интерактивные правила Proxy, Direct, Block** | [RoutingTab.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/RoutingTab.swift) | Добавление правил, поиск, удаление, комментарии | Валидация типов (`domain:`, `geosite:`, `geoip:`, `full:`, `regexp:`). Быстрые пресеты («Соцсети», «AI», «RU напрямую»). | Добавление и удаление тестового правила в UI | ✅ Работает |
| **FEAT-ROUTE-03** | **Схемы маршрутизации Happ / V2RayTUN** | [HappRoutingCodec.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Routing/HappRoutingCodec.swift)<br>[HappSchemeSheetView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/HappSchemeSheetView.swift) | Base64 схемы, экспорт, импорт, слияние (`merge: true`) | Полная совместимость с экосистемой Happ / V2RayTUN. Экспорт в буфер и файл. | Тест 4/5 в SelfTestRunner | ✅ Работает |
| **FEAT-ROUTE-04** | **FakeDNS пул (198.18.0.0/15)** | [RoutingTab.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/RoutingTab.swift)<br>[XrayConfigGenerator.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Xray/XrayConfigGenerator.swift) | Тумблер FakeDNS, интеграция в секцию `fakedns` и `inbound` Xray | Исключает задержку двойного DNS при сплит-туннелировании. | Тест 3/5 в SelfTestRunner | ✅ Работает |
| **FEAT-ROUTE-05** | **Автообновление гео-баз geosite.dat / geoip.dat** | [GeoAssetManager.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Network/GeoAssetManager.swift)<br>[GeoAsset.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/Core/Models/RoutingRule.swift) | Загрузка с GitHub (Loyalsoldier), валидация SHA256 | Атомарная замена файлов баз в `Application Support/XProject/geo/` с откатом при ошибке хэш-суммы. | Карточка гео-баз в RoutingTab | ✅ Работает |

---

## 6. Пользовательский интерфейс и Menubar (macOS HIG)

| ID | Фича | Файлы реализации | Ключевые элементы | Граничные условия / Особенности | Способ проверки | Статус |
|---|---|---|---|---|---|---|
| **FEAT-UI-01** | **Главное окно (Glassmorphic Dark HIG)** | [MainWindowView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Main/MainWindowView.swift)<br>[PreferencesWindowController.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/PreferencesWindowController.swift) | Центрирование окна, темный фон `#080B1C`, отсутствие белых рамок | Размер 420x760, единая плавная анимация `ModernMacTheme.smoothSpring`. Выгрузка `contentView = nil` при закрытии для экономии памяти. | Открытие главного окна, проверка верстки | ✅ Работает |
| **FEAT-UI-02** | **Кнопка питания (PowerButtonView)** | [PowerButtonView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/MenuBar/PowerButtonView.swift) | Неоновый ореол, пульсирующее кольцо при подключении, тактильный отклик | Стабильный фрейм разметки (не дергается при смене статусов). Иконка `power` с градиентом. | Нажатие кнопки, проверка анимаций | ✅ Работает |
| **FEAT-UI-03** | **Интерактивный золотистый переключатель «Автозапуск»** | [MainWindowView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Main/MainWindowView.swift) (строка 116)<br>[GoldenToggle.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Components/GoldenToggle.swift) | Фирменный золотистый тумблер (GoldenToggle) | Прямой биндинг `$appState.settings.autoConnectOnLaunch`. Единый стиль во всем приложении (главное окно, настройки, MenuBar). | Переключение тумблера и проверка `cat settings.json` | ✅ Работает |
| **FEAT-UI-04** | **Иконка и координатор строки меню (MenuBar)** | [MenuBarCoordinator.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/MenuBarCoordinator.swift) | Динамический щит со статусной точкой | При подключении отображается активная точка, смена иконки при ошибке. При клике открывает Popover. | Проверка иконки в MenuBar Mac | ✅ Работает |
| **FEAT-UI-05** | **Menubar Popover быстрого доступа** | [MenuBarPopoverView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/MenuBar/MenuBarPopoverView.swift) | Кнопка питания, селектор сервера, кнопка пинга, счетчики | Адаптивная высота списка серверов (до 185pt скролл). Быстрое переключение нод прямо из строки меню. | Клик по иконке в строке меню | ✅ Работает |
| **FEAT-UI-06** | **Телеметрия в реальном времени** | [MainWindowView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Main/MainWindowView.swift)<br>[MenuBarPopoverView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/MenuBar/MenuBarPopoverView.swift) | Таймер аптайма (`formattedUptime`), счетчики `bytesIn`/`bytesOut` | При отключении плавно скрывается без схлопывания высоты блока статуса. | Подключение к серверу и наблюдение за таймером | ✅ Работает |
| **FEAT-UI-07** | **Консоль журналов Xray (LogsTab)** | [LogsTab.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/LogsTab.swift) | Фильтр уровней, поиск, чекбокс автоскролла, копирование, очистка | Отображает живой вывод ядра Xray и системных менеджеров с подсветкой синтаксиса. | Вкладка «Журналы» в Настройках | ✅ Работает |
| **FEAT-UI-08** | **Окно расширенных настроек** | [SettingsWindowController.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/SettingsWindowController.swift)<br>[SettingsView.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/SettingsView.swift) | Вкладки: Маршрутизация, Сеть и DNS, Журналы | Размер 780x640, шорткат `Cmd+,`. Переключение вкладок без потери состояния. | Нажатие `Cmd+,` или кнопки шестеренки | ✅ Работает |
| **FEAT-UI-09** | **Дедупликация серверов** | [AppState.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/AppState.swift) (`deduplicateServers`)<br>[ServersTab.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/UI/Preferences/ServersTab.swift) | Чип «Очистить дубликаты (N)» | Сравнение адреса, порта, протокола и UUID/пароля. Не удаляет разные серверы с одинаковыми именами. | Нажатие чипа дедупликации | ✅ Работает |
| **FEAT-UI-10** | **Безопасное удаление подписок и серверов** | [AppState.swift](file:///Users/tony/Desktop/vpn/Sources/XProject/App/AppState.swift) (`deleteSubscription`, `deleteServer`) | Автоматический вызов `restoreSelectedServer()` | При удалении подписки, содержащей активный сервер, `selectedServerId` не зависает в пустоте, а корректно переключается на доступный сервер. | Удаление подписки в MainWindowView | ✅ Работает |

---

## 7. Встроенные автоматизированные тесты (Self-Test Suite)

| Секция | Название блока | Описание тестов | Количество тестов |
|---|---|---|:---:|
| **[1/5]** | **Сетевые парсеры** | VLESS Reality+Vision, Trojan TLS, Shadowsocks SIP002, IPv6 хосты, Base64 MIME `\r\n`, отсев мусора, многострочный VLESS с декодированием фрагментов `#%F0%...`, JSON массив UltimaVPN, загрузка живой подписки по сети | **9** |
| **[2/5]** | **Оптическое распознавание QR** | Генерация QR в памяти ➔ Vision/CoreImage детектор ➔ Парсинг URL | **1** |
| **[3/5]** | **Валидация официальным бинарником Xray** | `xray -test -c config.json`, валидация FakeDNS (198.18.0.0/15), валидация Fragment для UltimaVPN | **3** |
| **[4/5]** | **Сериализация и хранилище** | JSON Roundtrip ServerProfile & RoutingConfig, кодирование схем Happ/V2RayTUN, парсинг заголовка `routing:`, GeoAsset метаданные, сохранение сервера и автозапуск `autoConnectOnLaunch` | **5** |
| **[5/5]** | **Сетевые адаптеры macOS** | Определение физических сетевых служб `networksetup`, переключение TUN-интерфейса | **2** |
| **ИТОГО** | **Полный тестовый прогон** | `swift run X-project --test` | **21 из 21 (100% PASS)** |

---

## 💡 Памятка для разработчиков и AI-ассистентов

1. **Никогда не удаляйте поля из `AppSettings`** без добавления значений по умолчанию в `init(from decoder:)`.
2. **Не вызывайте `appState.servers.removeAll()` без сохранения выбранного сервера**: всегда сохраняйте `prevSelectedName = appState.selectedServer?.name` и вызывайте `restoreSelectedServer(preferringName: prevSelectedName)`.
3. **Не делайте синхронных блокирующих вызовов в `applicationDidFinishLaunching`**: сетевые операции и инициализация туннеля должны выполняться асинхронно.
4. **Всегда запускайте `swift run X-project --test` перед сборкой приложения**: падение хотя бы одного теста означает регрессию в парсерах, ядре или персистентности.
5. **Всегда проверяйте очистку сетевых настроек**: при закрытии приложения системный прокси обязан переходить в состояние `Enabled: No`.
