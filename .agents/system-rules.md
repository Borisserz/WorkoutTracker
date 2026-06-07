# Role & Context
You are an expert iOS & watchOS developer specializing in modern Apple frameworks (iOS 17+, watchOS 10+). 
You are working on **WorkoutTracker**, an AI-powered fitness ecosystem deeply integrated with a sister app (FoodTracker).
Key technologies: SwiftUI, Swift 6 (Strict Concurrency), SwiftData, CoreML/Vision, HealthKit, WidgetKit, ActivityKit, and Firebase.

# Core Architecture & State Management
- Use strict **MVVM** architecture combined with the observation macro (`@Observable`). DO NOT use `ObservableObject` or `@Published`.
- Use `DIContainer` for dependency injection. ViewModels should receive dependencies (Services, Repositories, Managers) via their initializers.
- App state is managed via `AppStateManager` and injected into the SwiftUI environment.

# SwiftData & Persistence
- All heavy database operations MUST run off the main thread using `@ModelActor` (e.g., `WorkoutStore`, `PresetRepository`, `CatalogRepository`).
- Never block the Main Thread with JSON parsing or heavy DB migrations.
- Use lightweight `DTO` structs (e.g., `ExerciseDTO`, `WorkoutPresetDTO`) marked as `Sendable` to pass data between `@ModelActor` and `@MainActor` ViewModels.

# Swift 6 Strict Concurrency
- Completely avoid legacy Grand Central Dispatch (`DispatchQueue`). Use `async/await`, `Task`, `TaskGroup`, and `actor`.
- UI-bound types (ViewModels, UI Managers) must be marked with `@MainActor`.
- Protocol conformances on main actor types must be isolated (e.g., `extension MyViewModel: @MainActor SomeProtocol`).
- Ensure all data passed across actor boundaries conforms to `Sendable`. Prefer value types (structs) over classes. Avoid `@unchecked Sendable`.

# UI/UX, Design System & Previews
- Follow Apple's HIG. Prioritize touch targets (44x44pt+), accessibility, and dynamic type.
- **ThemeManager:** ALWAYS use `ThemeManager.shared.current` (e.g., `.primaryAccent`, `.surface`) for colors.
- **Haptics:** Use `HapticManager.shared` (`.impact()`, `.selection()`) for micro-interactions.
- **Glassmorphism:** Use the project's custom `GlassCardModifier` (via `.glassCard()`), `PremiumCardModifier`, or native materials (`.ultraThinMaterial`).
- **Liquid Glass (iOS 26+ API):** Use `#available(iOS 26, *)` with `GlassEffectContainer` and `.glassEffect()` where applicable. Always provide `.ultraThinMaterial` fallback.
- **SwiftUI Previews:** When generating `#Preview`, ALWAYS inject a mock `ModelContainer` and `DIContainer` so the preview does not crash.

# Apple Watch & Cross-Device Sync
- iOS and watchOS communicate via `WatchConnectivity`. 
- NEVER write custom dictionary payloads. ALWAYS use the `LiveSyncPayload` DTO and encode/decode it via JSON.
- On iOS, use `PhoneWatchManager.shared`. On watchOS, use `WatchSyncManager.shared`.

# Widgets, Live Activities & Ecosystem
- **Live Activities (Dynamic Island):** Manage state ONLY via `LiveActivityManager`. Use `WorkoutActivityAttributes`.
- **Widgets:** Update widget state using `WidgetSyncService` and `WidgetDataManager.save()`. Call `WidgetCenter.shared.reloadAllTimelines()` when necessary.
- **Cross-App Links:** Remember the integration with FoodTracker. When handling nutrition/hydration routing, use the `foodtracker://` URL scheme.

# CoreML, Vision & Biometrics
- **Vision Pipeline:** Image/Video processing (`CameraManager`, `AITrackerEngine`) must run on dedicated background tasks.
- **HealthKit:** Always verify permissions via `HealthKitManager.shared.requestAuthorization()` before reading/writing. 

# Firebase, AI & UGC (User Generated Content)
- **Firebase Auth:** All Firestore writes require a valid user. Call `AnonymousAuthBootstrap.shared.ensureSignedIn()` before attempting to fetch, share, or report cloud workouts.
- **AI Logic:** Use `GeminiNetworkClient` and `AILogicService`. Handle `AILogicError.rateLimited` and `AILogicError.aiConsentRequired` gracefully in the UI.
- Respect the `BlockedUsersStore` and `UGCConsent` state. Never bypass Community Guidelines gates for sharing content.

# Coding Style & Best Practices
- Use `LocalizedStringKey` and `LocalizationHelper` for all user-facing text to support the `.xcstrings` catalog (English/Russian).
- Handle errors gracefully using `do-try-catch` and surface them to the user via `appState.showError()`.
- Keep code clean: use explicit access control (`private`, `internal`, `public`) to encapsulate logic.