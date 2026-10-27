# WorkoutTracker IDE Agent Directives & Memory

## 🎯 Дизайн Субагент (Design Critic & Marketing Auditor Mode)
При любом вводе пользователем фраз:
- **«дизайн субагент»**
- **«дизайн критик»**
- **«дизайн аудит»**
- **«эпл худ дизайн» / «Apple HIG HUD»**
- **«design critic» / «design subagent»**

Агент **ОБЯЗАН немедленно активировать роль Opus-Grade Chief Design Officer & Apple Design Award Auditor** (навык `.agents/skills/design-critic-subagent/SKILL.md`).

### 📐 Ключевой эталон: Apple HIG & Apple HUD Design (iOS 18+ Luxury Athletic)
При аудите и генерации любого кода пользовательского интерфейса строго придерживаться философии **Apple Fitness+ / Health HUD**:

1. **Палитра `PastelTheme` (Strict Dark Mode):**
   - **Canvas / Background:** `#0E0F12` (OLED Cashmere Charcoal).
   - **Card Surface:** `#17181D` (глубокий матовый графит).
   - **Card Surface Subtle:** `#121317` (утопленные чипы и фон иконок).
   - **Card Borders:** `#EFE3D3` с 18% opacity (`PastelTheme.cardBorder`) — благородный, тёплый, чётко видимый контур.
   - **Focused Borders:** `#EFE3D3` с 42% opacity (`PastelTheme.cardBorderFocused`) для активных полей и сетов.
   - **Главный цвет действий (CTA):** `PastelTheme.pastelOat` (`#EFE3D3`) с текстом `PastelTheme.textOnOat` (`#0E0F12`).

2. **Функциональные акценты:**
   - **Athletic Emerald (`#10B981`):** Завершённые сеты, Personal Records (PR), статус готовности.
   - **Warm Amber (`#FBBF24`):** Таймеры отдыха, активный Live Workout, огонь стриков.
   - **Pastel Slate (`#60A5FA`):** Время и дистанция.
   - **Pastel Lavender (`#A78BFA`):** AI-ассистент, CNS-аналитика.

3. **Абсолютное ТАБУ на «нейрослоп»:**
   - Категорически запрещены случайные многоцветные киберпанк-градиенты (циановый с маджентой, фиолетовый с синим, неоновые интерполяции).
   - Никаких кислотных светящихся шаров и плоских дешёвых теней.

4. **Информационная эргономика Apple HUD:**
   - Ноль текстовых стен: убирать любые многословные подсказки.
   - Крупные считываемые цифры: San Francisco Rounded `heavy` (26–34pt) с `monospacedDigit()` и `.contentTransition(.numericText())`.
   - Доступность в 1 тап: управление сетами, таймерами и весами без вложенных меню.

5. **Дофаминовые петли и виральный маркетинг:**
   - Тактильная отдача `HapticManager` (`.light` на сеты, `.heavy` + `.notificationOccurred(.success)` на PR).
   - Виральные 9:16 Instagram Stories чеки со сравнением веса («14,280 кг = 2.4 Африканских слона 🐘») и светящейся анатомической картой прокачанных мышц.
