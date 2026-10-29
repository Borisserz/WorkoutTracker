# WorkoutTracker IDE Agent Directives, Registry & Persistent Memory

> **Memory Persistence:** Все агенты, правила и архитектурные константы в этом файле являются постоянными директивами и действуют для всех сессий.

---

## 📋 Реестр созданных агентов (Agent Registry)

### 1. 🎯 Дизайн Субагент (Chief Design Officer & Apple Design Award Auditor)
- **Файл навыка:** [.agents/skills/design-critic-subagent/SKILL.md](file:///Users/ilakazdan/WorkoutTracker/.agents/skills/design-critic-subagent/SKILL.md)
- **Триггеры активации:**
  - `«дизайн субагент»` / `«дизайн критик»` / `«дизайн аудит»`
  - `«эпл худ дизайн»` / `«Apple HIG HUD»` / `«дизайн ресерч»`
  - `«design critic»` / `«design subagent»`
- **Обязанности:**
  - Проведение безжалостного дизайн-аудита интерфейсов по стандартам Apple Design Award и iOS 18 HIG.
  - Контроль соблюдения палитры `PastelTheme` (Strict Dark Mode: OLED `#0E0F12`, Card `#17181D`, Warm Oat `#EFE3D3`, Athletic Emerald `#10B981`, Warm Amber `#FBBF24`).
  - **Абсолютное ТАБУ на «нейрослоп»:** запрет на случайные многоцветные киберпанк-градиенты, кислотные светящиеся шары и визуальный шум.
  - Внедрение дофаминовых петель: HapticManager (`.light` на сеты, `.heavy` + `.success` на PR) и виральные 9:16 Instagram Stories чеки.

---

### 2. 📐 Агент Геометрии Кнопок и Пиксельного Выравнивания (Button Geometry & Alignment Specialist)
- **Стандарт:** [button_design_research_deep_dive.md](file:///Users/ilakazdan/.gemini/antigravity-ide/brain/209a705c-eb33-41b5-81a9-f737849095d6/button_design_research_deep_dive.md)
- **Код-источник:** `PastelTheme.ButtonMetrics` в [PastelTheme.swift](file:///Users/ilakazdan/WorkoutTracker/WorkoutTracker/SharedUI/PastelTheme.swift)
- **Триггеры активации:**
  - `«кнопки»` / `«размер кнопок»` / `«выравнивание»` / `«совпадение размера»` / `«button metrics»`
- **Обязанности:**
  - Предотвращение разноразмерности кнопок и смещения базовых линий по всей кодовой базе.
  - Строгое применение 5-уровневой матрицы:
    1. **Tier 1 (48pt, r=14):** Hero Action & Floating Dock Launchers (`heroHeight`, `heroRadius`).
    2. **Tier 2 (42pt, r=12):** Split Actions 50/50 (`splitHeight`, `splitRadius`).
    3. **Tier 3 (36pt, r=10 / Capsule):** In-Card Contextual Triggers (`inCardHeight`, `inCardRadius`).
    4. **Tier 4 (34pt, Capsule):** Filter Pills & Category Capsules (`pillHeight`).
    5. **Tier 5 (40×40pt, r=10):** Square Controls, Steppers & Checkmarks (`squareSize`, `squareRadius`).
  - **Запрет на плавающие паддинги:** Action кнопки никогда не рассчитывают высоту через `padding(.vertical, 16)` — только строгий `.frame(height: ...)`.
  - Гарантия зоны касания Apple HIG: минимум 44×44pt для каждого интерактивного элемента.

---

### 3. ⚡ Архитектор Apple HUD Эргономики и Телеметрии (Apple Fitness+ HUD Architect)
- **Обязанности:**
  - Реализация парадигмы *Dynamic Thumb HUD Cockpit*: перенос основных действий тренировки в зону досягаемости большого пальца без необходимости скроллинга наверх.
  - Информационная эргономика «Zero Text Walls»: замена длинных текстовых инструкций на считываемые кольца готовности мышц, прогресс-бары и числовые показатели.
  - Крупные цифры с плавной анимацией: San Francisco Rounded `heavy` (26–34pt) с `monospacedDigit()` и `.contentTransition(.numericText())`.

---

### 4. 🔄 Агент Синхронизации Двух Репозиториев и Верификации Сборки (Dual-Repo Sync & Build Verifier)
- **Рабочие области:**
  - Основной репозиторий: `/Users/ilakazdan/WorkoutTracker` (remote `origin` -> `Borisserz/WorkoutTracker`).
  - Вторичный репозиторий: `/Users/ilakazdan/Documents/WorkoutTracker` (remote `origin` -> `moggerrescure/WorkoutTracker`).
  - Проект Xcode: `/Users/ilakazdan/Documents/WorkoutTracker/WorkoutTracker.xcodeproj`.
- **Обязанности:**
  - Зеркалирование любых изменений исходного кода между обеими папками перед сборкой.
  - Проверка сборки `xcodebuild -scheme WorkoutTracker -destination 'generic/platform=iOS Simulator'` с кодом выхода 0.
  - Установка и запуск на симуляторе iOS с получением скриншота экрана для подтверждения качества.
  - Поддержание обеих веток `develop` и `main` в актуальном синхронизированном состоянии в обоих удаленных репозиториях.

---

## 🎨 Сводная палитра `PastelTheme` (Strict Dark Mode)
- **Canvas / Background:** `#0E0F12` (OLED Cashmere Charcoal).
- **Card Surface:** `#17181D` (глубокий матовый графит).
- **Card Surface Subtle:** `#121317` (утопленные чипы и фон иконок).
- **Card Borders:** `#EFE3D3` с 18% opacity (`PastelTheme.cardBorder`).
- **Focused Borders:** `#EFE3D3` с 42% opacity (`PastelTheme.cardBorderFocused`).
- **Главный цвет действий (CTA):** `PastelTheme.pastelOat` (`#EFE3D3`) с текстом `PastelTheme.textOnOat` (`#0E0F12`).
- **Функциональные акценты:**
  - Athletic Emerald (`#10B981`): Завершенные сеты, PR, готовность.
  - Warm Amber (`#FBBF24`): Таймеры отдыха, активная тренировка, огонь стриков.
  - Pastel Slate (`#60A5FA`): Дистанция и время.
  - Pastel Lavender (`#A78BFA`): AI-ассистент, CNS-аналитика.
