# iOS Project — Architecture & Coding Standards
# Every rule in this file is strictly enforced. Violations break the architecture.

## Build Commands
```
# Build
xcodebuild -scheme MyApp -configuration Debug build
# or via Xcode: Cmd+B

# Run Tests
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16'
# or via Xcode: Cmd+U

# Lint
swiftlint                    # Run before EVERY commit
swiftformat .                # Auto-format before EVERY commit
```

---

## Architecture: Clean Architecture + MVVM (STRICTLY ENFORCED)

### Data Flow (ONE DIRECTION ONLY)
```
UI (SwiftUI View) → ViewModel → UseCase → Repository → DataSource (API / DB)
```
- NEVER skip layers. ViewModel MUST NOT call Repository directly.
- NEVER reverse the flow. Repository MUST NOT know about ViewModel.
- Every arrow is a dependency boundary. Inner layers know NOTHING about outer layers.

### Layer Rules

**UI Layer** (`Feature/{Name}/Presentation/`)
- Contains: SwiftUI Views, ViewModel, UiState, UiEvent
- Views are STATELESS — they receive state, emit events via ViewModel
- NO business logic here. Not even simple calculations.
- NO direct API/DB calls. Not even "just one quick call."

**Domain Layer** (`Feature/{Name}/Domain/`)
- Contains: UseCases, Domain Models, Repository Protocols
- ZERO framework imports. No UIKit, no SwiftUI, no Combine in models.
- This layer is pure Swift. It should compile without any Apple framework.
- UseCases contain ALL business logic. Every business rule lives here.

**Data Layer** (`Feature/{Name}/Data/`)
- Contains: Repository Implementations, DTOs, Mappers, DataSources
- Repository is NOT a dumb proxy. It handles: caching strategy, data source
  coordination (API vs DB), retry logic, offline-first decisions.
- DTOs NEVER leak outside this layer. Always map to Domain models.

---

## ViewModel Rules — Move Business Logic to UseCases

```swift
// ❌ BANNED — ViewModel doing business logic
@Observable
class OrderViewModel {
    func placeOrder(cart: Cart) {
        let total = cart.items.reduce(0) { $0 + $1.price * Double($1.quantity) }  // ❌ Logic here
        let discount = total > 100 ? total * 0.1 : 0.0                            // ❌ Logic here
        let finalPrice = total - discount                                          // ❌ Logic here
        Task { try await repository.submitOrder(finalPrice) }                      // ❌ Direct repo call
    }
}

// ✅ REQUIRED — ViewModel only coordinates (Swift 6 Typed Throws)
@MainActor
@Observable
class OrderViewModel {
    private(set) var state: OrderUiState = .idle
    private let placeOrderUseCase: PlaceOrderUseCaseProtocol

    init(placeOrderUseCase: PlaceOrderUseCaseProtocol) {
        self.placeOrderUseCase = placeOrderUseCase
    }

    func placeOrder(cart: Cart) {
        state = .loading
        Task {
            do throws(AppError) {
                let order = try await placeOrderUseCase.execute(cart: cart)
                state = .success(order.toUi())
            } catch {
                // `error` is statically typed as `AppError` — no casting needed
                state = .error(error.toUiMessage())
            }
        }
    }
}
```

**ViewModel responsibilities — ONLY these:**
1. Hold UI state (`@Observable` properties)
2. Receive UI events (public methods called by View)
3. Call UseCases
4. Update UI state from UseCase results
5. Handle navigation events

**If you find yourself writing an `if/else` with business meaning in ViewModel → STOP → create a UseCase.**

---

## UseCase Layer — Every Action Gets a UseCase

```swift
// ✅ REQUIRED UseCase pattern — Swift 6 Typed Throws
protocol PlaceOrderUseCaseProtocol: Sendable {
    func execute(cart: Cart) async throws(AppError) -> Order
}

final class PlaceOrderUseCase: PlaceOrderUseCaseProtocol, Sendable {
    private let orderRepository: OrderRepositoryProtocol
    private let calculateDiscountUseCase: CalculateDiscountUseCaseProtocol

    init(
        orderRepository: OrderRepositoryProtocol,
        calculateDiscountUseCase: CalculateDiscountUseCaseProtocol
    ) {
        self.orderRepository = orderRepository
        self.calculateDiscountUseCase = calculateDiscountUseCase
    }

    func execute(cart: Cart) async throws(AppError) -> Order {
        let discount = try calculateDiscountUseCase.execute(cart: cart)
        let order = cart.toOrder(discount: discount)
        return try await orderRepository.placeOrder(order)
    }
}
```

**UseCase rules:**
- One public method: `execute()` (or `callAsFunction()` for shorthand)
- Name describes the action: `GetUserProfileUseCase`, `ValidateEmailUseCase`
- Contains business logic, validation, orchestration between repositories
- Uses **Swift 6 Typed Throws** — `throws(AppError)` — NOT `Result<T, AppError>`
- Can call other UseCases for composition
- NEVER import UIKit or SwiftUI
- All UseCase types MUST conform to `Sendable`

---

## Mapper Layer — Separate All Models

Three model types. Always. No exceptions.

```swift
// 1. DTO (Data Transfer Object) — lives in Data/Remote/DTO/
struct UserDTO: Codable {
    let userId: String
    let fullName: String
    let avatarUrl: String?
    let createdAt: String        // Raw API string

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

// 2. Domain Model — lives in Domain/Model/
struct User {
    let id: String
    let name: String
    let avatarUrl: URL?
    let memberSince: Date
}

// 3. UI Model — lives in Presentation/Model/
struct UserUi: Identifiable {
    let id: String
    let displayName: String          // "John D."
    let avatarUrl: URL?
    let memberSinceText: String      // "Member since Jan 2024"
}
```

**Mapper pattern — REQUIRED between every layer boundary:**

```swift
// Data/Mapper/UserMapper.swift
extension UserDTO {
    func toDomain() -> User {
        User(
            id: userId,
            name: fullName,
            avatarUrl: avatarUrl.flatMap { URL(string: $0) },
            memberSince: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}

// Presentation/Mapper/UserUiMapper.swift
extension User {
    func toUi() -> UserUi {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return UserUi(
            id: id,
            displayName: String(name.prefix(1)) + "...",
            avatarUrl: avatarUrl,
            memberSinceText: "Member since \(formatter.string(from: memberSince))"
        )
    }
}
```

**NEVER pass DTOs to ViewModel. NEVER pass Domain models to Views without mapping.**

---

## Package Structure — Feature-Based (Not Layer-Based)

```
// ❌ BANNED — Layer-based structure
MyApp/
  ViewModels/         ← All ViewModels dumped here
  Repositories/       ← All Repos dumped here
  Models/             ← All models dumped here

// ✅ REQUIRED — Feature-based structure
MyApp/
├── App/
│   ├── MyApp.swift                → @main entry point
│   ├── AppDelegate.swift          → If needed for push notifications, etc.
│   └── DIContainer.swift          → Root dependency container
│
├── Core/
│   ├── Common/
│   │   ├── Extensions/            → Swift extensions (String+, Date+, etc.)
│   │   └── Util/                  → ONLY genuinely shared utilities (NOT a dumping ground)
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── Endpoint.swift
│   │   ├── NetworkError.swift
│   │   └── NetworkMonitor.swift
│   ├── Database/
│   │   ├── PersistenceController.swift
│   │   └── Migration/
│   ├── DesignSystem/
│   │   ├── Theme/
│   │   ├── Components/            → Shared SwiftUI components
│   │   └── Modifiers/             → Custom ViewModifiers
│   └── Security/
│       └── KeychainManager.swift
│
├── Feature/
│   ├── Auth/
│   │   ├── Data/
│   │   │   ├── Remote/
│   │   │   │   ├── AuthAPI.swift
│   │   │   │   └── DTO/
│   │   │   │       └── LoginResponseDTO.swift
│   │   │   ├── Local/
│   │   │   │   └── AuthLocalDataSource.swift
│   │   │   ├── Mapper/
│   │   │   │   └── AuthMapper.swift
│   │   │   └── Repository/
│   │   │       └── AuthRepositoryImpl.swift
│   │   ├── Domain/
│   │   │   ├── Model/
│   │   │   │   └── AuthToken.swift
│   │   │   ├── Repository/
│   │   │   │   └── AuthRepositoryProtocol.swift    ← Protocol only
│   │   │   └── UseCase/
│   │   │       ├── LoginUseCase.swift
│   │   │       └── ValidateCredentialsUseCase.swift
│   │   └── Presentation/
│   │       ├── LoginScreen.swift
│   │       ├── LoginViewModel.swift
│   │       ├── LoginUiState.swift
│   │       ├── Model/
│   │       │   └── LoginFormUi.swift
│   │       └── Mapper/
│   │           └── LoginUiMapper.swift
│   │
│   ├── Home/
│   │   ├── Data/
│   │   ├── Domain/
│   │   └── Presentation/
│   │
│   └── Profile/
│       ├── Data/
│       ├── Domain/
│       └── Presentation/
│
├── Navigation/
│   └── AppRouter.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.xcstrings
    └── Info.plist
```

**Each feature is self-contained. You should be able to delete an entire Feature/ folder
without breaking other features (except shared navigation).**

---

## Repository Rules — Repositories Must Contain Logic

```swift
// ❌ BANNED — Dumb proxy repository
final class UserRepositoryImpl: UserRepositoryProtocol {
    private let api: UserAPI

    func getUser(id: String) async throws -> User {
        return try await api.getUser(id: id).toDomain()  // Just forwarding ❌
    }
}

// ✅ REQUIRED — Smart repository with real logic
final class UserRepositoryImpl: UserRepositoryProtocol {
    private let api: UserAPI
    private let localDataSource: UserLocalDataSource
    private let networkMonitor: NetworkMonitorProtocol

    init(
        api: UserAPI,
        localDataSource: UserLocalDataSource,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.api = api
        self.localDataSource = localDataSource
        self.networkMonitor = networkMonitor
    }

    func getUser(id: String) async throws(AppError) -> User {
        // 1. Return cached data first (offline-first)
        if let cached = try? await localDataSource.getUserById(id) {
            // If offline, return cache only
            guard networkMonitor.isConnected else {
                return cached.toDomain()
            }
        }

        // 2. Fetch fresh data if online
        do {
            let dto = try await api.getUser(id: id)
            try await localDataSource.upsert(dto.toEntity())     // Cache it
            return dto.toDomain()
        } catch {
            // 3. Fall back to cache on network failure
            if let cached = try? await localDataSource.getUserById(id) {
                return cached.toDomain()
            }
            throw error.toAppError()
        }
    }
}
```

**Repository responsibilities:**
- Coordinate between remote and local data sources
- Implement caching strategy (cache-first, network-first, etc.)
- Handle offline scenarios
- Map DTOs to Domain models
- NEVER expose DTOs or Entities outside the data layer

---

## Dependency Injection — Protocol-Based with Manual DI Container

```swift
// ❌ BANNED — Hardcoded dependencies
class LoginViewModel {
    private let repository = AuthRepositoryImpl()    // ❌ Concrete type, not testable
}

// ✅ REQUIRED — Protocol-based injection

// 1. Define protocols for every dependency
protocol AuthRepositoryProtocol {
    func login(credentials: Credentials) async throws(AppError) -> AuthToken
}

// 2. Inject via initializer
@MainActor
@Observable
class LoginViewModel {
    private let loginUseCase: LoginUseCaseProtocol

    init(loginUseCase: LoginUseCaseProtocol) {       // ✅ Protocol, injectable
        self.loginUseCase = loginUseCase
    }
}

// 3. DI Container — assembles dependencies
final class DIContainer {
    // MARK: - Singletons (truly app-wide only)
    lazy var networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    lazy var apiClient: APIClient = APIClient()
    lazy var keychainManager: KeychainManagerProtocol = KeychainManager()

    // MARK: - Feature: Auth (new instance per use)
    func makeAuthAPI() -> AuthAPI {
        AuthAPI(client: apiClient)
    }

    func makeAuthRepository() -> AuthRepositoryProtocol {
        AuthRepositoryImpl(
            api: makeAuthAPI(),
            keychain: keychainManager
        )
    }

    func makeLoginUseCase() -> LoginUseCaseProtocol {
        LoginUseCase(repository: makeAuthRepository())
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(loginUseCase: makeLoginUseCase())
    }
}
```

**DI rules:**
- `lazy var` (Singleton) → ONLY for truly app-wide instances: APIClient, Keychain, NetworkMonitor
- Factory methods (`make...()`) → Repositories, UseCases, ViewModels (new instance each time)
- EVERY dependency is behind a protocol — enables testing with mocks
- NO force-unwrapping dependencies. NO global singletons (`shared`).
- Container lives at the App level, passed down via `@Environment` or explicit injection
- Alternative: Use `swift-dependencies` or `Factory` library if project grows large

### `init` vs `@Environment` — when to use which (STRICTLY ENFORCED)

Both are legitimate DI mechanisms but serve different purposes. Mixing them up is the single most common SwiftUI DI mistake.

**One-line rule:** Use `init` for **explicit, narrow, testable** dependencies. Use `@Environment` for **ambient, broad, many-consumer** context.

**Decision tree (top to bottom — first match wins):**

| # | Question | Answer → Use |
|---|---|---|
| 1 | Is it a ViewModel, UseCase, Repository, or Service? | **`init`** |
| 2 | Is it a SwiftUI system value (`colorScheme`, `dismiss`, `dynamicTypeSize`, `horizontalSizeClass`, `scenePhase`, `openURL`, `requestReview`)? | **`@Environment`** |
| 3 | Is it a design token (color, font, spacing, corner radius)? | **Neither — use `Color.svXxx` / `SvFont.xxx` / `SvSpacing.xxx` directly** |
| 4 | Is it an app-wide coordinator that ≥3 unrelated screens consume (router, user session, feature-flag read handle)? | **`@Environment`** |
| 5 | Is it stateful logic specific to one feature? | **`init`** |
| 6 | Is it a service consumed by only 1–2 screens? | **`init`** |

**Correct usage:**

```swift
// ✅ init — per-feature, testable, specific
@MainActor
@Observable
final class LoginViewModel {
    init(
        loginUseCase: LoginUseCaseProtocol,            // ✅ feature-specific
        analytics: AnalyticsServiceProtocol,           // ✅ per-instance for test isolation
        biometricUnlock: BiometricUnlock,              // ✅ narrow dependency
    ) { /* ... */ }
}

// ✅ @Environment — system values + genuinely app-wide context
struct DealDetailScreen: View {
    @State var viewModel: DealDetailViewModel                          // ← constructed by parent via init

    @Environment(\.colorScheme)          private var colorScheme       // ✅ system
    @Environment(\.horizontalSizeClass)  private var hSizeClass        // ✅ system
    @Environment(\.dismiss)              private var dismiss           // ✅ system
    @Environment(\.dynamicTypeSize)      private var dynamicTypeSize   // ✅ system
    @Environment(AppRouter.self)         private var router            // ✅ app-wide coordinator
    @Environment(UserSession.self)       private var session           // ✅ app-wide auth state
}
```

**Wiring at the App root:**

```swift
@main
struct SvangurApp: App {
    @State private var router  = AppRouter()                      // ✅ app-lifetime state
    @State private var session = UserSession()                    // ✅ app-lifetime state
    private let container = DIContainer()                          // ✅ app-lifetime factory

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .environment(router)                               // ✅ inject once at root
                .environment(session)
        }
    }
}

// Parent screen constructs child ViewModels via the container, passes via init
.navigationDestination(for: Route.self) { route in
    switch route {
    case .login:                   LoginScreen(viewModel: container.makeLoginViewModel())
    case .dealDetail(let dealId):  DealDetailScreen(viewModel: container.makeDealDetailViewModel(dealId: dealId))
    }
}

// Screen receives ViewModel via init, stores in @State for ownership
struct DealDetailScreen: View {
    @State var viewModel: DealDetailViewModel

    init(viewModel: DealDetailViewModel) {
        self._viewModel = State(wrappedValue: viewModel)           // ✅ SwiftUI takes ownership
    }
    // ...
}
```

**Custom `EnvironmentKey` — HIGH BAR**

Creating a new `EnvironmentKey` is rarely justified. ALL of these must be true:
1. **≥ 3 unrelated screens consume it** — not "might consume in the future"
2. **Its lifetime is the App lifetime** — not per-feature
3. **It's ambient context, not business logic** — passive state, not methods that perform work
4. **Testing a consumer doesn't require mocking its behavior** — it's passthrough, not logic

If any condition fails → use `init` injection through the DI container.

**Banned patterns — these hide dependencies and break testability:**

```swift
// ❌ BANNED — hiding ViewModel dependencies in Environment to "clean up" init
@MainActor
@Observable
final class LoginViewModel {
    @Environment(\.loginUseCase) private var loginUseCase   // ❌ not testable, not discoverable
    // A ViewModel test can't inject a mock — it has to spin up an EnvironmentValues graph
}

// ❌ BANNED — ViewModel passed via Environment (ViewModels are instance-scoped, not app-scoped)
.environment(LoginViewModel(/* ... */))
// Two different LoginScreens would share state. That's never what you want.

// ❌ BANNED — design tokens behind EnvironmentKey
@Environment(\.svPrimaryColor) private var primary
// Color.svPrimary reads the Asset Catalog directly and handles dark-mode automatically — no Environment needed.

// ❌ BANNED — mutable state wrapped as a struct and put in Environment
struct AppConfig { var flagA: Bool; var flagB: Bool }         // ❌ value type
.environment(\.appConfig, appConfig)
// Mutations won't propagate to consumers. Use an @Observable class instead.

// ❌ BANNED — Environment as a service locator
@Environment(\.dealRepository) private var dealRepo in SomeView
// If SomeView genuinely needs the repository, its parent should construct a ViewModel that init-injects the repo.
```

**The project-specific contract** — these are the only things in `@Environment` in this app:
- SwiftUI system values (`colorScheme`, `dismiss`, `dynamicTypeSize`, `horizontalSizeClass`, `verticalSizeClass`, `scenePhase`, `openURL`, `requestReview`, `accessibilityReduceTransparency`, `accessibilityReduceMotion`)
- `AppRouter` (`@Observable` class — navigation coordinator, app-lifetime)
- `UserSession` (`@Observable` actor-backed facade — current user + auth state, app-lifetime)
- `FeatureFlagService` read handle (`@Observable` class — read-only from views; mutation via ViewModel `init` injection)

Everything else — including repositories, UseCases, analytics, location service, maps service, token store — is `init`-injected into ViewModels through the `DIContainer`.

---

## Initializer Rules — Strict DI via `init` (STRICTLY ENFORCED)

Every class, struct, and actor follows these ten rules. Violations block PR review.

### 1. All dependencies injected via `init`. No exceptions.
No property injection. No service locator. No singleton access inside `init`.
```swift
// ❌ BANNED — property injection, service locator, singleton lookup in init
@MainActor
@Observable
class LoginViewModel {
    var authRepository = AuthRepository.shared       // ❌ Singleton
    var analytics: AnalyticsService!                 // ❌ IUO, set later from outside
    @Injected var logger: Logger                     // ❌ Property-wrapper service locator
}

// ✅ REQUIRED — every dependency in init, as a protocol
@MainActor
@Observable
final class LoginViewModel {
    private let loginUseCase: LoginUseCaseProtocol
    private let analytics: AnalyticsServiceProtocol
    private let logger: LoggerProtocol

    init(
        loginUseCase: LoginUseCaseProtocol,
        analytics: AnalyticsServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.loginUseCase = loginUseCase
        self.analytics = analytics
        self.logger = logger
    }
}
```

### 2. NO side effects in `init` — only stored-property assignment
`init` assigns stored properties. That is all. It does NOT:
- launch `Task { ... }` or start async work
- subscribe to `NotificationCenter`, `Combine` publishers, or `AsyncSequence`s
- call a repository, network, disk, or keychain
- mutate any external state (singletons, UserDefaults, environment)
- log anything beyond a `debug`-level construction trace

Lifecycle work belongs in `.task { }` on the View, in `onAppear`, or in an explicit `func onAppear()` / `func start()` that the View calls from its `.task { }` modifier. This keeps construction cheap, keeps previews fast, and keeps tests deterministic.

```swift
// ❌ BANNED — init spawns async work
@MainActor
@Observable
final class HomeViewModel {
    init(homeUseCase: HomeUseCaseProtocol) {
        self.homeUseCase = homeUseCase
        Task { await load() }         // ❌ Fires in previews, tests, every Xcode rebuild
    }
}

// ✅ REQUIRED — explicit entry point, triggered by the View
@MainActor
@Observable
final class HomeViewModel {
    private let homeUseCase: HomeUseCaseProtocol

    init(homeUseCase: HomeUseCaseProtocol) {
        self.homeUseCase = homeUseCase
    }

    func onAppear() async {
        await load()                   // ✅ Triggered by the View's .task { }
    }
}

struct HomeScreen: View {
    @State var viewModel: HomeViewModel
    var body: some View {
        content
            .task { await viewModel.onAppear() }
    }
}
```

### 3. Parameter order — dependencies first, config second, state last
Every `init` groups parameters in this order (blank lines between groups are encouraged when the list is long):
1. **Services / Repositories / UseCases** — the "wiring" (protocol types)
2. **Configuration values** — URLs, timeouts, feature flags, page sizes
3. **Initial state** — default values, seed data

```swift
init(
    // 1. Dependencies
    dealRepository: DealRepositoryProtocol,
    analytics: AnalyticsServiceProtocol,

    // 2. Configuration
    pageSize: Int = 20,
    refreshInterval: Duration = .seconds(60),

    // 3. Initial state
    initialFilter: DealFilter = .all
)
```

### 4. No `!`, no `try!`, no `fatalError()` in `init`
Construction never force-unwraps. If validation is required, use typed throws:
```swift
// ✅ Throwing init with typed error
init(rawURL: String) throws(AppError) {
    guard let url = URL(string: rawURL) else {
        throw .validation(message: "Invalid URL: \(rawURL)")
    }
    self.url = url
}
```
`init?` (failable init) is acceptable only when the caller can genuinely ignore a `nil` result. In almost all cases, `throws(AppError)` is the better choice because the caller must confront the failure mode.

### 5. Value types: prefer the synthesized memberwise init
For DTOs and simple domain models, rely on Swift's auto-synthesized memberwise init. Write a custom init ONLY when you need default values, validation, or a property computed from other fields.
```swift
// ✅ No custom init needed — memberwise init is generated automatically
struct Deal: Sendable, Identifiable, Equatable {
    let id: Int64
    let title: String
    let discountType: DiscountType
    let validFrom: Date
    let validUntil: Date
}
```

### 6. Default parameter values > multiple convenience inits
Use default values instead of overloading. Classes should have ONE designated init.
```swift
// ❌ BANNED — convenience-init explosion
init(userId: String) { ... }
init(userId: String, pageSize: Int) { ... }
init(userId: String, pageSize: Int, sortOrder: SortOrder) { ... }

// ✅ REQUIRED — single init with defaults
init(userId: String, pageSize: Int = 20, sortOrder: SortOrder = .newest) { ... }
```

### 7. `@MainActor` types: `init` is main-actor-isolated
ViewModels marked `@MainActor` have main-actor-isolated `init`s. Calling them from an off-main context requires `await` at the call site. Do NOT "fix" this by detaching work (`Task.detached { }`) from inside the init — fix the call site instead, or construct the ViewModel on the main actor (e.g. from `App` or a `ViewModelFactory`).

### 8. No `self` capture in escaping closures inside `init`
If construction would register a callback, publisher subscription, or timer that captures `self`, defer that wiring to a `start()` / `onAppear()` method. `self` is not yet available for escaping capture during `init`, and the resulting lifecycle is easy to misreason about.

### 9. Preview fixtures via static factory — NOT a preview-only init
Do NOT add `init(preview: Bool)` or a defaulted-args init for previews. Expose a static factory on the type:
```swift
extension HomeViewModel {
    @MainActor
    static func previewInstance(state: HomeUiState = .idle) -> HomeViewModel {
        let vm = HomeViewModel(
            homeUseCase: FakeHomeUseCase(),
            analytics: NoopAnalytics()
        )
        vm.state = state
        return vm
    }
}

#Preview("Home - Loaded") {
    HomeScreen(viewModel: .previewInstance(state: .loaded(Deal.previews)))
}
```

### 10. Access control: keep `init` `internal` by default
Production Repositories, Services, and UseCases have `internal` (default) `init`s. Mark `init` `public` ONLY when the type is exported from a Swift package and is intended to be constructed by another module. Mark `init` `private` / `fileprivate` when construction should go through a factory or static method (e.g. a `Result`-returning factory for types with validation).

---


## State Management — @Observable + Sealed UI States

```swift
// ❌ BANNED — Multiple loose state properties
@Observable
class ProfileViewModel {
    var isLoading = false              // ❌ Can have isLoading + user + error simultaneously
    var user: User? = nil              // ❌ Optional mess
    var errorMessage: String? = nil    // ❌ Inconsistent state possible
}

// ✅ REQUIRED — Single enum state
enum ProfileUiState: Equatable {
    case idle
    case loading
    case success(UserUi)
    case error(String)
}

// One-time events (navigation, alerts)
enum ProfileUiEffect: Equatable {
    case navigateToLogin
    case showAlert(title: String, message: String)
}

// ViewModel
@MainActor
@Observable
class ProfileViewModel {
    private(set) var state: ProfileUiState = .idle
    private(set) var effect: ProfileUiEffect? = nil

    private let getUserProfileUseCase: GetUserProfileUseCaseProtocol

    init(getUserProfileUseCase: GetUserProfileUseCaseProtocol) {
        self.getUserProfileUseCase = getUserProfileUseCase
    }

    func onAppear() {
        loadProfile()
    }

    func consumeEffect() {
        effect = nil
    }

    private func loadProfile() {
        state = .loading
        Task {
            do throws(AppError) {
                let user = try await getUserProfileUseCase.execute()
                state = .success(user.toUi())
            } catch {
                state = .error(error.userMessage)
            }
        }
    }
}
```

**State rules:**
- ONE state enum per ViewModel. Screen can ONLY be in ONE state at a time.
- Use a separate `effect` property for one-time side effects (navigation, alerts)
- Use `@Observable` (iOS 17+). Use `@ObservableObject` + `@Published` for iOS 16 support.
- Mutable state is `private(set)` — Views CANNOT mutate state directly.
- NEVER use `@State` for data that comes from ViewModel — `@State` is for local view state only.

---

## Error Handling — Swift 6 Typed Throws (NOT Result)

```swift
// Core/Common/AppError.swift — Typed errors (conforms to Sendable)
enum AppError: Error, Equatable, Sendable {
    case network(message: String = "Network error")
    case server(code: Int, message: String)
    case unauthorized(message: String = "Session expired")
    case notFound(message: String = "Not found")
    case validation(message: String)
    case unknown(message: String = "Something went wrong")
}

// Core/Common/ErrorMapper.swift
extension Error {
    func toAppError() -> AppError {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut:
                return .network()
            default:
                return .network(message: urlError.localizedDescription)
            }
        }
        return .unknown(message: localizedDescription)
    }
}

extension AppError {
    var userMessage: LocalizedStringKey {
        switch self {
        case .network:
            return "error_network"
        case .unauthorized:
            return "error_session_expired"
        case .server(let code, _):
            return "Server error: \(code)"
        case .notFound:
            return "error_not_found"
        case .validation(let message):
            return LocalizedStringKey(message)
        case .unknown:
            return "error_generic"
        }
    }
}

// ✅ Swift 6 Typed Throws wrapper — replaces safeAPICall Result pattern
func apiCall<T>(_ operation: () async throws -> T) async throws(AppError) -> T {
    do {
        return try await operation()
    } catch let error as AppError {
        throw error
    } catch {
        throw error.toAppError()
    }
}

// ✅ Usage in Repository — throws(AppError), NOT Result<T, AppError>
final class UserRepositoryImpl: UserRepositoryProtocol {
    func getUser(id: String) async throws(AppError) -> User {
        return try await apiCall {
            let dto = try await api.getUser(id: id)
            return dto.toDomain()
        }
    }
}

// ✅ Usage in UseCase — propagates typed error
final class GetUserProfileUseCase: GetUserProfileUseCaseProtocol, Sendable {
    func execute(id: String) async throws(AppError) -> User {
        return try await userRepository.getUser(id: id)
    }
}

// ✅ Usage in ViewModel — catch block gets AppError directly
@MainActor @Observable
class ProfileViewModel {
    func loadProfile() {
        state = .loading
        Task {
            do throws(AppError) {
                let user = try await getUserProfileUseCase.execute(id: userId)
                state = .success(user.toUi())
            } catch {
                // `error` is AppError — no casting, no switch over Result
                state = .error(error.userMessage)
            }
        }
    }
}
```

**Why typed throws over Result:**
- Cleaner call sites — no `.success` / `.failure` destructuring at every level
- Errors propagate naturally with `try` — no manual `.map`, `.flatMap`, `.mapError`
- Compiler enforces exhaustive catch blocks for the specific error type
- Fully integrated with Swift 6 strict concurrency (Sendable conformance)
- `do throws(AppError) { ... } catch { ... }` gives you a statically-typed `error`

**Error handling rules:**
- NEVER use untyped `throws` from Repository or UseCase — use `throws(AppError)`
- NEVER use `Result<T, AppError>` for new code — use typed throws instead
- EVERY API call goes through `apiCall()` (the typed-throws replacement for `safeAPICall`)
- Errors are mapped to user-facing `LocalizedStringKey` at the presentation layer only
- User-facing strings come from `Localizable.xcstrings`
- AppError MUST conform to `Sendable`

---

## Naming Conventions — No Generic Files

```
// ❌ BANNED file names
Utils.swift            → Split into: String+Extensions.swift, Date+Extensions.swift, etc.
Models.swift           → Split into: User.swift, Order.swift, Product.swift (one model per file)
Constants.swift        → Split into: APIConstants.swift, NavigationRoutes.swift
Helper.swift           → Rename to what it actually does: PriceFormatter.swift
Common.swift           → Be specific: ValidationRules.swift
Extensions.swift       → Split by type: View+Extensions.swift, String+Extensions.swift
Mapper.swift           → Per-feature: UserMapper.swift, OrderMapper.swift
```

**Naming rules:**
- One type per file (matching filename)
- File name = primary type: `LoginViewModel.swift` contains `class LoginViewModel`
- UseCase: verb + noun + "UseCase" → `ValidateEmailUseCase.swift`
- Repository: noun + "Repository" + suffix → `UserRepositoryProtocol.swift` (protocol), `UserRepositoryImpl.swift` (impl)
- ViewModel: feature + "ViewModel" → `LoginViewModel.swift`
- Screen/View: feature + "Screen" or "View" → `LoginScreen.swift`
- Mapper: use extensions on the source type → `UserDTO+Mapper.swift` or `UserMapper.swift`
- DTO: noun + "DTO" → `UserDTO.swift`
- Entity: noun + "Entity" → `UserEntity.swift`
- Protocols: noun + "Protocol" suffix → `AuthRepositoryProtocol` (or `AuthRepositoring` if you prefer `-ing` convention)
- Extensions: `Type+Feature.swift` → `String+Validation.swift`, `View+Shimmer.swift`

---

## Separation of Concerns — Clear Boundaries

**What each component is ALLOWED to do:**

| Component     | CAN do                                        | CANNOT do                                      |
|---------------|-----------------------------------------------|-------------------------------------------------|
| SwiftUI View  | Render UI, call ViewModel methods              | Business logic, API calls, DB access            |
| ViewModel     | Hold state, call UseCases, map to UiState      | Business logic, direct repo calls, UIKit refs   |
| UseCase       | Business logic, validation, orchestration      | UIKit/SwiftUI imports, UI formatting, DB queries|
| Repository    | Coordinate data sources, cache, map DTOs       | Business logic, UI concerns, hold UI state      |
| DataSource    | Raw API/DB operations                          | Business logic, caching, model mapping          |

**If you're unsure where code goes, ask: "Is this a WHAT (domain) or a HOW (data) or a SHOW (UI)?"**

---

## Testability — Domain Layer Must Be Pure Swift

The domain layer has ZERO framework imports (no UIKit, no SwiftUI, no Combine). Every UseCase is testable in complete isolation with fakes or mocks — no simulator required for the domain test bundle.

> **Zero-cost stack.** Every testing tool below is free and open-source — no paid services, no licensed SDKs, no CI add-ons. Runs on any machine, any CI provider.
> - **Swift Testing** — ships with Xcode, Apple (free)
> - **XCTest / XCUITest** — ships with Xcode, Apple (free)
> - **swift-snapshot-testing** — MIT, pointfree.co (free, GitHub)
> - **MetricKit** — ships with iOS SDK, Apple (free)

### Swift Testing — MANDATORY for Unit & Integration Tests

Use **Swift Testing** (the `Testing` module, shipped with Xcode 16 / Swift 6) for ALL new unit and integration tests. `XCTestCase` is legacy — it is NOT deprecated, but it is NOT used for new tests in this project. The two narrow XCTest exceptions are listed at the bottom of this section.

```swift
import Testing
@testable import App

// ✅ Testable UseCase — pure logic, typed throws, Sendable
final class CalculateShippingUseCase: CalculateShippingUseCaseProtocol, Sendable {
    private let shippingRepository: ShippingRepositoryProtocol

    init(shippingRepository: ShippingRepositoryProtocol) {
        self.shippingRepository = shippingRepository
    }

    func execute(order: Order) async throws(AppError) -> ShippingCost {
        guard !order.items.isEmpty else {
            throw .validation(message: "Cart is empty")
        }
        let weight = order.items.reduce(0.0) { $0 + $1.weight }
        let rate = try await shippingRepository.getRates(destination: order.destination)
        return rate.calculate(weight: weight)
    }
}

// ✅ Swift Testing — struct suite, init replaces setUp, #expect / #require replace XCTAssert
@Suite("CalculateShippingUseCase")
struct CalculateShippingUseCaseTests {
    let mockRepository: MockShippingRepository
    let sut: CalculateShippingUseCase

    // init replaces setUp — runs before EACH test (fresh instance per test, no shared state)
    init() {
        self.mockRepository = MockShippingRepository()
        self.sut = CalculateShippingUseCase(shippingRepository: mockRepository)
    }

    @Test("Empty cart throws validation error")
    func emptyCart_throwsValidation() async {
        await #expect(throws: AppError.self) {
            _ = try await sut.execute(order: Order(items: []))
        }
    }

    @Test("Calculates shipping based on total weight")
    func calculatesShippingBasedOnWeight() async throws {
        mockRepository.stubbedRate = Rate(pricePerKg: 5.0)
        let cost = try await sut.execute(order: Order(items: [Item(weight: 2.0)]))
        #expect(cost.amount == 10.0)
    }

    // Parameterized — one @Test, many inputs. Replaces multiple near-identical XCTest methods.
    @Test("Rejects invalid orders", arguments: [
        Order(items: []),
        Order(items: [Item(weight: -1.0)]),
    ])
    func rejectsInvalidOrders(_ order: Order) async {
        await #expect(throws: AppError.self) {
            _ = try await sut.execute(order: order)
        }
    }
}
```

**Swift Testing rules:**
- Import `Testing` — NOT `XCTest`. Do NOT mix `#expect` and `XCTAssert*` in the same test.
- Suite type: prefer `struct` (Apple's default). Use `class` only if you need `deinit` for cleanup; use `actor` if the suite holds mutable shared state.
- `init()` replaces `setUp()`; `deinit` replaces `tearDown()`. A fresh instance is created per test — state is NEVER shared across tests by default.
- Assertions: `#expect(expr)` for non-fatal checks, `#require(expr)` for fatal checks (test stops on failure). No more forty variants of `XCTAssert*` — any Swift expression works.
- Optional unwrapping: `let x = try #require(optional)` — do NOT use `XCTUnwrap`.
- Error checks: `#expect(throws: AppError.self) { ... }` or `#expect(throws: AppError.validation(message: "...")) { ... }`.
- Suite names: `@Suite("Human-readable name")` — the name does NOT need to start with `test`.
- Test names: `@Test("Describes behaviour under test")` — descriptive sentences, not `test_...` prefixes.
- Parameterization: `@Test(arguments: [...])` — one test, many inputs. Replaces looped `for` inside XCTest methods.
- Parallel by default: Swift Testing runs tests in parallel in-process via Swift Concurrency. If a suite holds shared state it MUST opt out with `@Suite(.serialized)` — don't do this unless absolutely necessary.
- Tags: `@Test(.tags(.networking, .slow))` for filtering in the Test Navigator / CI.

**When XCTest is still required (the ONLY exceptions):**
- **UI tests** (`XCUITest`) — Swift Testing does not support UI automation. Keep UI tests in a separate `XCUITest` target using `XCTestCase`.
- **Performance tests** (`XCTMetric`, `measure { }`) — Swift Testing has no performance-testing API yet.

Both may coexist with Swift Testing in the same test bundle — Xcode runs both in the same session. Do NOT mix frameworks within a single test function.

**General testing rules (framework-independent):**
- Use **Fakes** over **Mocks** where possible (`FakeUserRepository`, not a mocking library). Reach for mocks only when the fake would be more complex than the mock.
- Every UseCase gets tests. No exceptions. Domain coverage target: 100% of branches.
- ViewModel tests verify `state` transitions through deterministic sequences — drive the ViewModel via its public methods, then assert on `state` directly. No sleeps.
- Repository tests mock DataSources (API + DB), never the other way around.
- Name tests descriptively: `@Test("Empty cart throws validation error")` — not `test1()`, not `testEmptyCart()`.
- Test files: `FeatureNameTests.swift`, in a test target that mirrors the production package structure.

### Snapshot Testing — MANDATORY for Reusable Components

Since design fidelity is a strict rule, snapshot (visual regression) tests automate what would otherwise be manual overlay-compare. Use **swift-snapshot-testing** (pointfree.co) — it's the de-facto community standard.

```swift
// Package.swift
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),

// Test file
import SnapshotTesting
@testable import App

@Suite("PrimaryButton snapshot")
struct PrimaryButtonSnapshotTests {
    @Test("Default state matches recorded image")
    func defaultState() {
        let view = PrimaryButton(text: "Log In", onClick: {})
            .frame(width: 380, height: 53)
        assertSnapshot(of: view, as: .image)
    }

    @Test("Loading state matches recorded image")
    func loadingState() {
        let view = PrimaryButton(text: "Log In", onClick: {}, isLoading: true)
            .frame(width: 380, height: 53)
        assertSnapshot(of: view, as: .image)
    }
}
```

**Snapshot rules:**
- Every reusable component in `ui/components/` gets at least default + variants (disabled, loading, error)
- Every screen gets default state snapshot at minimum (Loading / Error / Empty covered by state tests already)
- Record snapshots on a single agreed simulator (iPhone 16 Pro, iOS 18, 3x scale) to avoid device-specific diffs in CI
- Commit `__Snapshots__` folders to git — they ARE the contract
- When a design change is intentional, delete the old snapshot and re-record in one PR — review the diff visually on the PR
- NEVER use `record: true` left-in committed code — it would silently overwrite instead of failing

---

## SwiftUI View Rules

```swift
// ✅ Proper SwiftUI View structure
struct ProfileScreen: View {
    let viewModel: ProfileViewModel     // ✅ Injected, not created here

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
            case .success(let user):
                ProfileContent(user: user)
            case .error(let message):
                ErrorView(message: message, onRetry: viewModel.onAppear)
            }
        }
        .task {
            viewModel.onAppear()          // ✅ Load data via .task
        }
    }
}

// ✅ Extract reusable subviews
struct ProfileContent: View {
    let user: UserUi                      // ✅ Takes UI model, not domain model

    var body: some View {
        VStack(spacing: 16) {
            AsyncImage(url: user.avatarUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            Text(user.displayName)
                .font(.title2.bold())
            Text(user.memberSinceText)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

## Device Compatibility — iPhone First, iPad-Ready (STRICTLY ENFORCED)

**Current scope:** iPhone, portrait. Baseline width = 428pt (iPhone 14 Pro Max / 15 Plus / 15 Pro Max / 16 Pro Max). Portrait-locked in Info.plist is fine for the launch release.

**Forward compatibility:** iPad support (and landscape / Stage Manager / Split View / larger iPhones in landscape) must NOT require rewriting screens. The rules below keep that path open at zero current cost. Violations block PR review because they silently create future-rewrite debt.

### 1. Read size class at the screen root, branch explicitly
Every screen reads `@Environment(\.horizontalSizeClass)` at the top of `body` even if it currently has one branch. This makes the adaptation point explicit and grep-able later.
```swift
struct DealListScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State var viewModel: DealListViewModel

    var body: some View {
        // Today: compact-only. When iPad arrives, add the .regular branch here.
        switch hSizeClass {
        case .regular: compactLayout()   // Placeholder — same as compact until iPad work starts
        default:       compactLayout()
        }
    }
}
```

### 2. NEVER read `UIScreen.main.bounds` or `UIScreen.main.scale`
`UIScreen.main` returns the whole-device screen, NOT the app window. On iPad Split View, Stage Manager, or iPhone landscape, window width ≠ screen width. This is the #1 source of broken iPad layouts.
```swift
// ❌ BANNED
let cardWidth = UIScreen.main.bounds.width * 0.9     // ❌ Wrong on iPad, Split View, landscape
let isSmallScreen = UIScreen.main.bounds.width < 375 // ❌ Misleading name, wrong value

// ✅ REQUIRED — use GeometryReader for the container, or size class for branches
GeometryReader { proxy in
    DealCard().frame(width: proxy.size.width * 0.9)
}
```
Use `GeometryReader` sparingly — it forces layout recalculation. For most cases, `.frame(maxWidth: .infinity)` + parent-provided padding is enough.

### 3. NO fixed widths — use `.frame(maxWidth:)` with a cap
Fixed widths break on iPad and in multi-column layouts. Icons and chips are the only exception.
```swift
// ❌ BANNED — forces iPhone-sized cards on iPad
DealCard().frame(width: 360)

// ✅ REQUIRED — responsive, but bounded so it doesn't stretch to 1024pt on iPad
DealCard().frame(maxWidth: 520)

// ✅ OK — icons / chips are fixed-size by design
Image(systemName: "heart").frame(width: 24, height: 24)
Chip("Pizza").frame(height: 32)   // height fixed, width hugs content
```

### 4. `NavigationStack` today — structure routes so `NavigationSplitView` works tomorrow
Use `NavigationStack` for all navigation now. When iPad support lands, it swaps to `NavigationSplitView` for regular-width windows. That swap ONLY works if route destinations are independent View types — never inline closures embedding state.
```swift
// ❌ BANNED — destinations are inline closures with captured state. Cannot be hoisted to a split view.
NavigationStack {
    List(deals) { deal in
        NavigationLink(deal.title) {
            DealDetailView(deal: deal, viewModel: DealDetailViewModel(dealId: deal.id))  // ❌
        }
    }
}

// ✅ REQUIRED — route-based navigation with typed destinations
enum DealRoute: Hashable { case detail(dealId: Int64) }

NavigationStack(path: $router.path) {
    DealListScreen()
        .navigationDestination(for: DealRoute.self) { route in
            switch route {
            case .detail(let id): DealDetailScreen(dealId: id)   // ✅ Can be hoisted into a split view's detail pane later
            }
        }
}
```

### 5. List-detail screens: design list + detail as independent Views today
Any screen pair where one screen lists items and another shows details for one of them (DealList → DealDetail, RestaurantList → RestaurantDetail, SearchResults → DealDetail, etc.) MUST have the list and detail as two fully independent `View` structs that each own their own `ViewModel`. Don't push detail state down from the list screen.

This rule costs nothing today (it's already good structure). It's what makes an iPad side-by-side rollout a one-file change — wrap both in `NavigationSplitView` and you're done.

### 6. Respect safe areas — NEVER hardcode nav or tab bar heights
Safe areas differ on iPhone notch, Dynamic Island, iPad, and iPad with Stage Manager.
```swift
// ❌ BANNED
VStack { ... }.padding(.bottom, 83)      // ❌ Assumes iPhone tab-bar height

// ✅ REQUIRED — let the system compute it
VStack { ... }
    .safeAreaInset(edge: .bottom) { BottomActionBar() }
```
Use `.ignoresSafeArea(.keyboard)` only when a view genuinely needs to slide under the keyboard. Never `.ignoresSafeArea()` at the root to "fill the screen."

### 7. Dynamic Type — font tokens MUST be text-style-backed
All typography tokens in `SvFont` / `SvTypography` should build on `Font.system(...)` with a `TextStyle` (`.body`, `.title3`, etc.) and a custom-font overlay — NOT raw point sizes. This way accessibility text-size settings scale the UI without breakage.
```swift
// ❌ BANNED — fixed point size, ignores Dynamic Type
static let bodyRegular = Font.custom("Poppins-Regular", size: 16)

// ✅ REQUIRED — relative to .body, scales with Dynamic Type
static let bodyRegular = Font.custom("Poppins-Regular", size: 16, relativeTo: .body)
```
When a specific screen deliberately opts out (e.g. a tightly-designed splash), document why and clamp with `.dynamicTypeSize(.large ... .xxLarge)` — never ignore the setting entirely.

### 8. Orientation — lock in Info.plist, NEVER in code
For launch, the Info.plist specifies Portrait for iPhone only. Do NOT call `UIDevice.current.setValue(...)` or override `supportedInterfaceOrientations` in code. When iPad support is added, iPad's Info.plist entry gets all four orientations with zero code change.

### 9. Assets — Asset Catalog only, include @2x and @3x
Every raster asset in the Asset Catalog has @2x and @3x variants. No loose PNGs in the bundle. When iPad-specific artwork is added later, Asset Catalog supports per-idiom variants without code changes — the `Image("hero")` call doesn't change.

Prefer SF Symbols or Vector (PDF / SVG) for anything tintable — scales infinitely, one asset serves all devices.

### 10. Previews — current baseline + explicit "does not break on large width"
Every screen `#Preview` block must include at least the compact preview. Screens that currently render on phone only should ALSO have a preview at a larger width that verifies they don't visually break (stretched buttons, oversized cards, etc.), even if the layout is unoptimized.
```swift
#Preview("DealList - iPhone", traits: .sizeThatFitsLayout) {
    DealListScreen(viewModel: .previewInstance(state: .loaded(Deal.previews)))
}

#Preview("DealList - Wide (no break)") {
    DealListScreen(viewModel: .previewInstance(state: .loaded(Deal.previews)))
        .frame(width: 1024, height: 1366)   // iPad dimensions — catches stretched buttons, unbounded cards
}
```
"Does not break" = no overflow, no stretched-edge-to-edge buttons, no unbounded images, no truncated text. Aesthetic optimization for iPad comes when iPad is in scope.

### What NOT to do (guaranteed iPad rewrites later)
- ❌ `UIScreen.main.bounds` anywhere
- ❌ `if UIDevice.current.userInterfaceIdiom == .pad` — use size class instead
- ❌ Fixed widths in `.frame(width:)` for content cards
- ❌ Inline-closure `NavigationLink` destinations
- ❌ Hardcoded padding that assumes iPhone dimensions (e.g. `.padding(.horizontal, 24)` is OK; `.padding(.horizontal, (screenWidth - 375) / 2)` is ❌)
- ❌ `GeometryReader` at screen root when size class would do
- ❌ `.frame(minHeight: UIScreen.main.bounds.height)` to "fill the screen" — use `.frame(maxHeight: .infinity)` + layout

---

## Liquid Glass — iOS 26 `.glassEffect()` (USE SELECTIVELY)

iOS 26 (September 2025) introduced Liquid Glass as the system's new material language — translucent, blur-aware, morph-capable. Apple's own system controls (TabView, toolbar, sheets, alerts) adopt it automatically when the app is recompiled against the iOS 26 SDK. Custom surfaces opt in via `.glassEffect()`.

**Current deployment target:** If the project supports iOS 17+, ALL custom `.glassEffect()` usage MUST be gated with `if #available(iOS 26, *)`, with a clean `.ultraThinMaterial` fallback for older OSes. If the project bumps its minimum to iOS 26, the guards can be removed — flag this as a one-shot migration PR.

### When to use glass (the short list)
- **Floating controls over media** — map overlay buttons, deal-detail bottom-sheet action bar when map/photo fills the screen behind
- **Contextual overlays** — filter popups, sort menus that visually hover above the list
- **Tab bar / toolbar** — adopted automatically; do NOT reskin
- **Hero moments** — deal-detail hero card over a blurred restaurant photo

### When NOT to use glass
- Dense text content (deal description, settings body) — glass reduces legibility
- Stacked glass on glass — layers become muddy
- List rows, cards at rest, standard form fields — solid `Color.svSurface` instead
- Brand identity surfaces (splash, onboarding hero) — solid brand color
- Dark-on-dark or light-on-light low-contrast combinations

### Usage — design-system wrapper, NOT literal calls everywhere
Centralize glass rules in one place so a design pivot is a one-file change.

```swift
// ui/theme/GlassStyle.swift — the only place that touches .glassEffect directly
extension View {
    @ViewBuilder
    func svGlassOverlay(_ shape: some Shape = .capsule, tinted: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            let glass: Glass = tinted.map { .regular.tint($0) } ?? .regular
            self.glassEffect(glass, in: shape)
        } else {
            // Fallback: best-available translucent material on iOS 17/18
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// Screens only ever call the wrapper:
Button("Directions", action: viewModel.openMaps)
    .svGlassOverlay()                              // Capsule glass

HStack { ... }
    .svGlassOverlay(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
```

**Liquid Glass rules:**
- EVERY `.glassEffect(...)` call goes through `svGlassOverlay(...)` (or a named component that wraps it) — NEVER call `.glassEffect` directly in a screen file
- Prefer `.regular` variant — use `.clear` only for near-invisible overlays, never `.identity` in production
- Interactive glass (`.interactive()`) ONLY on tappable elements — buttons and toggles, never static decoration
- `GlassEffectContainer` MUST wrap groups of related glass elements so they morph together instead of blinking in/out independently
- `glassEffectID("name", in: namespace)` required when glass elements move/swap across states — without it transitions are jarring
- Tint sparingly — a single tinted primary call-to-action per screen, never multiple competing tints
- NEVER wrap dense text (>3 lines body copy) in glass — legibility fails
- NEVER stack glass layers (glass button inside a glass card inside a glass toolbar) — one layer per UI context
- Accessibility: do NOT manually check `@Environment(\.accessibilityReduceTransparency)` — the system degrades glass to an opaque fill automatically. Testing with Reduce Transparency ON is mandatory.
- Previews: add one `#Preview` with Reduce Transparency enabled:
  ```swift
  #Preview("DealDetail - Reduce Transparency") {
      DealDetailScreen(...)
          .environment(\.accessibilityReduceTransparency, true)
  }
  ```
- Performance: glass is GPU-expensive. On screens with >6 simultaneous glass surfaces, wrap all in a `GlassEffectContainer` (consolidates into one pass) and profile at 60 fps on the oldest target device

### What NOT to do
- ❌ `.glassEffect()` called directly in a screen — always through `svGlassOverlay`
- ❌ Glass on list cells, form fields, or any content the user reads
- ❌ Custom blur + transparency hand-rolled with `.background(.regularMaterial).opacity(...)` as a "glass effect" — use the real API
- ❌ Tint colors pulled from `Color.red` or literal hex — tints come from `Color.svXxx` tokens
- ❌ Stacked glass (glass button inside glass card)
- ❌ Shipping Liquid Glass without testing on the oldest supported device (iPhone 13 / 14 currently) — it WILL drop frames if overused

---

## SwiftUI Previews — MANDATORY for Every Screen

Every screen and reusable component MUST have at least one `#Preview` block. Previews are not optional — they are the primary development and QA tool.

```swift
// ✅ REQUIRED — #Preview macro (Swift 5.9+ / Xcode 15+)
// Every Screen file MUST end with previews for all visual states.

// Screen preview — show all states
#Preview("Login - Default") {
    LoginScreen(viewModel: LoginViewModel.preview())
}

#Preview("Login - Loading") {
    LoginScreen(viewModel: LoginViewModel.preview(state: .loading))
}

#Preview("Login - Error") {
    LoginScreen(viewModel: LoginViewModel.preview(state: .error("Invalid email or password")))
}

// ✅ ViewModel must have a .preview() factory for mock data
extension LoginViewModel {
    static func preview(state: LoginUiState = .idle) -> LoginViewModel {
        let vm = LoginViewModel(loginUseCase: MockLoginUseCase())
        vm.state = state
        return vm
    }
}

// ✅ Reusable component preview — show variants
#Preview("DealCard - Open") {
    DealCard(deal: .previewOpen)
        .padding()
}

#Preview("DealCard - Closed") {
    DealCard(deal: .previewClosed)
        .padding()
}

// ✅ UI Model must have static preview fixtures
extension DealUi {
    static let previewOpen = DealUi(
        id: "1", restaurantName: "Pizza Palace",
        offerTitle: "30% off all pizzas", discountBadge: "30%",
        distance: "1.2 km", openNow: true,
        validTimeDisplay: "11:00–15:00",
        imageUrl: nil
    )
    static let previewClosed = DealUi(
        id: "2", restaurantName: "Burger Joint",
        offerTitle: "2 for 1 burgers", discountBadge: "2 for 1",
        distance: "3.5 km", openNow: false,
        validTimeDisplay: "18:00–22:00",
        imageUrl: nil
    )
}
```

**Preview rules:**
- EVERY Screen file must have `#Preview` blocks for: Default, Loading, Error, Empty states
- EVERY reusable component must have `#Preview` for its key visual variants
- Use `#Preview("Descriptive Name")` — named previews are required (not unnamed)
- ViewModels MUST expose a `static func preview(state:)` factory for preview injection
- UI Models MUST have `static let preview...` fixtures with realistic sample data
- Use the `#Preview` macro (Swift 5.9+), NOT the legacy `PreviewProvider` protocol
- Previews MUST render correctly — broken previews are treated as build failures
- When using device-specific previews, use `.previewDevice("iPhone 15 Pro")` for 428pt width baseline
- Preview fixtures live alongside the type they extend (not in a separate Previews/ folder)
- `#if DEBUG` guard preview fixtures if they import test-only dependencies

---

## Tech Stack (MANDATORY)
- Language: Swift 6+ (strict concurrency)
- UI: SwiftUI (NO UIKit for new screens)
- Architecture: MVVM + Clean Architecture
- DI: Protocol-based manual injection (or Factory / swift-dependencies)
- Networking: URLSession + async/await (or Alamofire if justified)
- Database: SwiftData (or Core Data for iOS < 17)
- Async: Swift Concurrency — async/await + TaskGroup (NO DispatchQueue for new code)
- Reactive: Combine only where needed (interop, publishers)
- Navigation: NavigationStack (type-safe, iOS 16+)
- Image Loading: AsyncImage (built-in) or Kingfisher/Nuke for advanced caching
- Logging: os.Logger (Apple's unified logging)
- Testing: **Swift Testing** (primary — `@Test` / `#expect` / `#require` macros, Xcode 16+ / Swift 6+). XCTest/XCUITest ONLY for UI tests and performance tests (Swift Testing doesn't support those yet).

---

## Type-Safe Navigation — REQUIRED pattern

```swift
// ❌ BANNED — String-based or loosely typed navigation
NavigationLink("Profile", destination: ProfileView())  // ❌ Tight coupling

// ✅ REQUIRED — Type-safe NavigationStack with routes
enum AppRoute: Hashable {
    case home
    case profile(userId: String)
    case settings
    case orderDetail(orderId: String)
}

// App-level router
struct AppRouter: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                onNavigateToProfile: { userId in
                    path.append(AppRoute.profile(userId: userId))
                }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    HomeScreen(onNavigateToProfile: { path.append(AppRoute.profile(userId: $0)) })
                case .profile(let userId):
                    ProfileScreen(viewModel: DIContainer.shared.makeProfileViewModel(userId: userId))
                case .settings:
                    SettingsScreen()
                case .orderDetail(let orderId):
                    OrderDetailScreen(orderId: orderId)
                }
            }
        }
    }
}
```

**Navigation rules:**
- ALL routes defined as a `Hashable` enum
- Views NEVER create other Views directly for navigation — use closures: `onNavigateToX: (String) -> Void`
- Navigation logic stays in Router or NavigationStack — not in ViewModel
- ViewModel NEVER triggers navigation directly — update state, let View react
- Use `NavigationPath` for programmatic navigation
- Deep links handled via `.onOpenURL` at the App level

---

## Swift Concurrency — STRICT Rules

```swift
// ❌ BANNED patterns
DispatchQueue.global().async { ... }               // ❌ Use Task {} instead
DispatchQueue.main.async { ... }                   // ❌ Use @MainActor instead
DispatchQueue.main.sync { ... }                    // ❌ Deadlock risk

// ✅ REQUIRED — Modern Swift Concurrency
@MainActor
@Observable
class UserViewModel {
    private(set) var state: UserUiState = .idle

    func loadUser(id: String) {
        state = .loading
        Task {                                     // ✅ Inherits @MainActor
            let result = await getUserUseCase.execute(id: id)
            state = result.toUiState()             // ✅ Already on MainActor
        }
    }
}

// ✅ Use nonisolated for background work in actors
actor DataProcessor {
    func processData(_ raw: Data) -> ProcessedData {
        // Heavy computation runs off main thread automatically
    }
}

// ✅ TaskGroup for parallel work
func loadDashboard() async -> Dashboard {
    async let profile = profileUseCase.execute()
    async let orders = ordersUseCase.execute()
    async let notifications = notificationsUseCase.execute()

    return Dashboard(
        profile: await profile,
        orders: await orders,
        notifications: await notifications
    )
}
```

**Concurrency rules:**
- NEVER use `DispatchQueue` for new code — use `Task`, `async let`, `TaskGroup`
- Mark ViewModels with `@MainActor` — all state updates happen on main thread
- Use `Task { }` for fire-and-forget work from synchronous contexts
- Use `Task.detached { }` sparingly — only when you explicitly need to escape actor context
- ALWAYS handle `Task` cancellation: check `Task.isCancelled` in long operations
- SwiftUI `.task { }` modifier automatically cancels when view disappears — prefer it
- NEVER hold strong references to `self` in long-running Tasks without checking cancellation

---

## Sendable Protocol — STRICTLY ENFORCED (Swift 6)

Swift 6 enforces data-race safety at compile time. Every type shared across concurrency boundaries MUST conform to `Sendable`.

```swift
// ❌ BANNED — Non-Sendable types crossing actor boundaries
class UserService {  // ❌ Classes are not Sendable by default
    var cache: [String: User] = [:]
    func getUser(id: String) async -> User { ... }
}

// ✅ REQUIRED — Use value types, actors, or explicit Sendable conformance
// Option 1: Value types are implicitly Sendable if all properties are Sendable
struct UserDTO: Codable, Sendable {  // ✅ struct + all Sendable props = implicitly Sendable
    let userId: String
    let fullName: String
}

// Option 2: Actor for mutable shared state
actor UserCache {  // ✅ Actors are always Sendable
    private var store: [String: User] = [:]
    func get(_ id: String) -> User? { store[id] }
    func set(_ id: String, user: User) { store[id] = user }
}

// Option 3: final class with Sendable conformance + immutable stored properties
final class AppConfig: Sendable {
    let apiBaseURL: URL      // ✅ All stored properties are let + Sendable types
    let maxRetries: Int

    init(apiBaseURL: URL, maxRetries: Int) {
        self.apiBaseURL = apiBaseURL
        self.maxRetries = maxRetries
    }
}

// Option 4: @unchecked Sendable — LAST RESORT, document why
final class LegacySDKWrapper: @unchecked Sendable {
    // ⚠️ Use @unchecked ONLY when wrapping thread-safe third-party code
    // that doesn't declare Sendable. ALWAYS add a comment explaining why.
    private let lock = NSLock()
    private var _value: String = ""

    var value: String {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
}
```

**Sendable rules — MANDATORY for Swift 6:**
- ALL Domain Models MUST be `Sendable` (they're value types → automatic)
- ALL DTOs MUST be `Sendable` (Codable structs → automatic)
- ALL UI Models MUST be `Sendable` (value types → automatic)
- ALL UseCase protocols MUST inherit `Sendable` (`protocol XxxUseCaseProtocol: Sendable`)
- ALL UseCase implementations MUST be `final class: Sendable` or `struct: Sendable`
- ALL Repository protocols MUST inherit `Sendable`
- Use `actor` for any mutable shared state (caches, token managers)
- Use `@MainActor` on ViewModels — they're Sendable by actor isolation
- NEVER use `@unchecked Sendable` without a code review comment explaining why
- Enable `StrictConcurrency` in build settings: `SWIFT_STRICT_CONCURRENCY = complete`
- Closures passed across concurrency boundaries must be `@Sendable`:
  ```swift
  func fetchAll(ids: [String], transform: @Sendable (User) -> UserUi) async { ... }
  ```

---

## SwiftUI Performance — CRITICAL

```swift
// ❌ BANNED — Expensive work in body
struct UserList: View {
    let users: [UserUi]

    var body: some View {
        // ❌ Sorting on every rerender
        let sorted = users.sorted(by: { $0.name < $1.name })
        List(sorted) { user in UserRow(user: user) }
    }
}

// ✅ REQUIRED — Pre-compute, use Equatable, minimize body complexity
struct UserList: View {
    let users: [UserUi]              // ✅ Pre-sorted by ViewModel

    var body: some View {
        List(users) { user in
            UserRow(user: user)
        }
    }
}

// ✅ Make subviews Equatable to prevent unnecessary redraws
struct UserRow: View, Equatable {
    let user: UserUi

    static func == (lhs: UserRow, rhs: UserRow) -> Bool {
        lhs.user.id == rhs.user.id && lhs.user.displayName == rhs.user.displayName
    }

    var body: some View {
        HStack {
            AsyncImage(url: user.avatarUrl)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            Text(user.displayName)
        }
    }
}
```

**Performance rules:**
- NEVER do sorting, filtering, or heavy computation inside `body` — do it in ViewModel
- Make UI models conform to `Identifiable` — SwiftUI uses `id` for efficient diffing
- Use `EquatableView` or conform to `Equatable` for complex subviews
- Use `LazyVStack` / `LazyHStack` inside `ScrollView` — not `VStack` for long lists
- NEVER create objects inside `body` without wrapping in `@State` or caching
- Use `.id(item.id)` for explicit identity in ForEach
- Profile with Instruments (SwiftUI template) — zero unnecessary view updates is the goal

---

## Memory Management — ARC, Retain Cycles & Bounded Caches (STRICTLY ENFORCED)

ARC is automatic but does NOT prevent all leaks. Two sources of memory growth in this codebase: **strong reference cycles inside closures** and **unbounded in-memory caches**. Every rule below addresses one or both.

### 1. Closure capture — `[weak self]` by default in escaping closures
Any closure stored or escaped that captures `self` from a reference type (class, actor) MUST use `[weak self]` unless lifetime is guaranteed. Bare `self` creates a strong cycle and leaks the enclosing object.
```swift
// ❌ BANNED — strong cycle: self → timer → closure → self
class FeedRefresher {
    var timer: Timer?
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.reload()                        // ❌ strong capture leaks FeedRefresher forever
        }
    }
}

// ✅ REQUIRED — weak capture, guard for nil
class FeedRefresher {
    var timer: Timer?
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }       // ✅ nil means object is deallocated — stop work
            self.reload()
        }
    }
    deinit { timer?.invalidate() }               // ✅ always invalidate timers in deinit
}
```

**Capture-list rules:**
- `[weak self]` is the default for escaping closures in classes/actors — timers, publishers, `NotificationCenter` observers, `UIApplication` callbacks, long-running `Task`s stored as properties
- `[unowned self]` ONLY when the closure's lifetime is strictly shorter than `self`'s — rare. Wrong use crashes the app, not just leaks. When in doubt, use `weak`
- Short-lived closures that return synchronously (`.map { }`, `.filter { }`, `#expect { }`) — bare `self` is fine, no cycle possible
- `Task { [weak self] ... }` when the Task is stored as a property; inside SwiftUI `.task { }` it's unnecessary because the Task is tied to view lifetime
- Actors and `@MainActor` classes follow the same rules as regular classes — `Sendable` / isolation doesn't prevent cycles
- Value types (`struct`, `enum`) have NO reference cycles — capture lists not needed when `self` is a struct

### 2. Cancel long-running work on deinit
Timers, `NSObjectProtocol` observers, `DispatchSourceTimer`, `CADisplayLink`, custom `Task` properties — all MUST be cancelled/invalidated in `deinit` or equivalent teardown.
```swift
actor WebSocketClient {
    private var listenTask: Task<Void, Never>?

    func connect() {
        listenTask = Task { [weak self] in
            await self?.listenLoop()
        }
    }

    deinit {
        listenTask?.cancel()                     // ✅ NEVER rely on ARC alone for async work
    }
}
```
Structured concurrency (`.task { }` on a View, `async let`, `withTaskGroup`) cancels automatically — prefer it over detached Tasks. Reach for `Task.detached` only with a documented reason.

### 3. SwiftUI ownership — use `@State` correctly
- `@State var viewModel: SomeViewModel` — SwiftUI owns the ViewModel, binds its lifetime to the view. Works for `@Observable` classes.
- `@Bindable` — for passing an existing observable into a child view that needs two-way bindings
- `@Environment(...)` — use for app-wide singletons (services, theme); the environment value must outlive every consumer (enforced by the App / Scene root)
- NEVER instantiate a ViewModel inside `body` (`let vm = LoginViewModel()` inline) — SwiftUI throws it away on every re-render, leaking the previous instance's subscriptions
- NEVER store `NSTimer`, `NotificationCenter` tokens, or KVO observers as properties of a `View` struct — use a reference-type wrapper (`@State` on an `@Observable` class) so deinit runs deterministically

### 4. Bounded caches only — use `NSCache` or cap `Dictionary`
`Dictionary` and `Array` grow forever. If a cache isn't bounded, it's a memory leak in slow motion.
```swift
// ❌ BANNED — unbounded in-memory map
final class DealImageCache {
    private var map: [URL: UIImage] = [:]        // ❌ grows per unique URL, never purged

    func image(for url: URL) -> UIImage? { map[url] }
    func store(_ image: UIImage, for url: URL) { map[url] = image }
}

// ✅ REQUIRED — NSCache auto-purges on memory pressure
final class DealImageCache {
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 100                    // ✅ Hard cap
        cache.totalCostLimit = 50 * 1024 * 1024   // ✅ ~50 MB max
    }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func store(_ image: UIImage, for url: URL, cost: Int) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}
```
For general data caches (non-image), either use `NSCache` (object/Any type) or a custom LRU with explicit size/TTL.

### 5. Image loading — use the library, not `UIImage(contentsOfFile:)`
`AsyncImage` (built-in) or Kingfisher/Nuke have memory-bounded caches out of the box. Loading `UIImage` manually bypasses these bounds.
```swift
// ❌ BANNED
let image = UIImage(contentsOfFile: path)       // ❌ Full decode, no cache, blocks

// ✅ REQUIRED — in SwiftUI
AsyncImage(url: url) { $0.resizable() } placeholder: { ProgressView() }

// ✅ If using Kingfisher (image-heavy screens)
KFImage(url)
    .setProcessor(DownsamplingImageProcessor(size: targetSize))   // ✅ Don't load full resolution
    .cacheMemoryOnly(false)                                        // ✅ Disk+memory
```
Downsample to the target frame — a 4MP restaurant hero photo at 360pt width wastes ~95% of the decoded bytes.

### 6. Combine subscriptions (only if using Combine)
If Combine is used for interop (rare in this project — we prefer async/await), subscriptions MUST be stored in a `Set<AnyCancellable>` and cancelled in `deinit`:
```swift
private var cancellables: Set<AnyCancellable> = []

someSubject
    .sink { [weak self] value in self?.handle(value) }
    .store(in: &cancellables)                    // ✅ Released when self is released
```
Bare `.sink { }` without `.store(in:)` leaks the entire pipeline.

### 7. Memory warnings — wire caches to system pressure
Listen for `UIApplication.didReceiveMemoryWarningNotification` and purge caches. `NSCache` does this automatically; custom caches must handle it explicitly.
```swift
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil, queue: .main
) { [weak self] _ in
    self?.mapPinCache.removeAll()                // ✅ Drop non-essential caches
}
```

### 8. Profiling workflow — mandatory before every release
- **Instruments → Leaks** — run on a live-use scenario (login → browse → deal detail → back → repeat 10x). Zero leaks = ship.
- **Instruments → Allocations** — watch Persistent bytes. Should return to baseline after each navigation round-trip.
- **Xcode Memory Graph** (`Debug → View Debugging → View Memory Graph`) — quick cycle detection while developing.
- **MetricKit** payloads include peak memory usage in `MXMetricPayload.memoryMetrics` — log to observability (see Crash Reporting section)
- **Baseline target:** cold-launch steady-state memory ≤ 120 MB on iPhone 14. Deal-detail screen ≤ +30 MB over baseline. Regressions >20% page on-call.

### What NOT to do
- ❌ Bare `self` in escaping closures on reference types
- ❌ `[unowned self]` without a clear lifetime proof
- ❌ `UIImage(named:)` for large photos — use Asset Catalog + downsampling
- ❌ Unbounded `Dictionary` / `Array` caches
- ❌ Forgetting to `cancel()` a stored `Task` in `deinit`
- ❌ `NotificationCenter` observer without removing on deinit (iOS 9+ auto-cleans block-based observers, but token-based ones leak)
- ❌ Storing `UIViewController` references in singletons
- ❌ Shipping without running Instruments Leaks on the login→deal detail→back cycle

---

## SwiftUI Lifecycle & Side Effects — CORRECT Usage

```swift
// ✅ .task — async work that cancels on disappear
struct ProfileScreen: View {
    let viewModel: ProfileViewModel

    var body: some View {
        content
            .task {
                await viewModel.loadProfile()           // ✅ Auto-cancels
            }
            .task(id: viewModel.selectedTab) {          // ✅ Re-runs when ID changes
                await viewModel.loadTabContent()
            }
    }
}

// ✅ .onAppear / .onDisappear — synchronous setup/teardown
.onAppear { viewModel.trackScreenView() }
.onDisappear { viewModel.saveScrollPosition() }

// ✅ .onChange — react to state changes
.onChange(of: searchText) { oldValue, newValue in
    viewModel.onSearchChanged(newValue)
}

// ✅ @State for LOCAL view state only
struct ExpandableCard: View {
    @State private var isExpanded = false     // ✅ Pure UI state, not business data
    let content: CardUi

    var body: some View {
        VStack {
            Text(content.title)
            if isExpanded { Text(content.details) }
        }
        .onTapGesture { isExpanded.toggle() }
    }
}
```

**Side effect rules:**
- `.task { }` → for async work (API calls, data loading) — auto-cancels
- `.task(id:)` → re-runs when the ID value changes
- `.onAppear` → for synchronous, immediate work only
- `.onChange(of:)` → react to specific value changes
- `@State` → ONLY for local UI state (expanded, selected tab, text input)
- NEVER use `@State` for data that comes from ViewModel or network

---

## Pagination Pattern

```swift
// Domain
protocol UserRepositoryProtocol {
    func getUsers(page: Int, limit: Int) async throws(AppError) -> PaginatedResult<User>
}

struct PaginatedResult<T> {
    let items: [T]
    let hasNextPage: Bool
    let nextPage: Int?
}

// ViewModel
@MainActor
@Observable
class UserListViewModel {
    private(set) var users: [UserUi] = []
    private(set) var isLoadingMore = false
    private(set) var hasNextPage = true
    private var currentPage = 1

    private let getUsersUseCase: GetUsersUseCaseProtocol

    func loadInitial() {
        currentPage = 1
        users = []
        Task { await loadPage(page: 1) }
    }

    func loadMore() {
        guard !isLoadingMore, hasNextPage else { return }
        Task { await loadPage(page: currentPage) }
    }

    private func loadPage(page: Int) async {
        isLoadingMore = page > 1
        let result = await getUsersUseCase.execute(page: page, limit: 20)
        switch result {
        case .success(let paginated):
            users.append(contentsOf: paginated.items.map { $0.toUi() })
            hasNextPage = paginated.hasNextPage
            currentPage = (paginated.nextPage ?? page) + 1
        case .failure(let error):
            // Handle error
            break
        }
        isLoadingMore = false
    }
}

// View
struct UserListScreen: View {
    let viewModel: UserListViewModel

    var body: some View {
        List {
            ForEach(viewModel.users) { user in
                UserRow(user: user)
                    .onAppear {
                        if user.id == viewModel.users.last?.id {
                            viewModel.loadMore()           // ✅ Trigger pagination
                        }
                    }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .refreshable {
            viewModel.loadInitial()                        // ✅ Pull to refresh
        }
        .task {
            viewModel.loadInitial()
        }
    }
}
```

---

## Image Loading

```swift
// ✅ Built-in AsyncImage (simple cases)
AsyncImage(url: user.avatarUrl) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image
            .resizable()
            .scaledToFill()
    case .failure:
        Image(systemName: "person.circle.fill")
            .foregroundStyle(.secondary)
    @unknown default:
        EmptyView()
    }
}
.frame(width: 48, height: 48)
.clipShape(Circle())
```

**Image rules:**
- Use `AsyncImage` for simple cases (built-in, no dependencies)
- For advanced caching/prefetching: use Kingfisher or Nuke
- ALWAYS handle all phases: empty (loading), success, failure
- ALWAYS provide placeholder and error fallback
- ALWAYS set `contentDescription` via accessibility modifiers

---

## Persistence & State Restoration

```swift
// ✅ @AppStorage for simple user preferences (persists via UserDefaults)
@AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
@AppStorage("selected_theme") private var selectedTheme: String = "system"

// ✅ @SceneStorage for per-scene state restoration (survives process death)
@SceneStorage("search_query") private var searchQuery = ""
@SceneStorage("selected_tab") private var selectedTab = 0

// ✅ SwiftData for structured data
@Model
class UserEntity {
    @Attribute(.unique) var id: String
    var name: String
    var email: String
    var avatarUrl: String?
    var updatedAt: Date

    init(id: String, name: String, email: String, avatarUrl: String?, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.updatedAt = updatedAt
    }
}
```

**Persistence rules:**
- `@AppStorage` → simple key-value prefs only (theme, onboarding flag)
- `@SceneStorage` → restore UI state after process death (search text, tab selection)
- SwiftData / Core Data → structured data with relationships
- Keychain → sensitive data (tokens, passwords, API keys)
- NEVER store sensitive data in UserDefaults or @AppStorage
- Entity ≠ Domain Model — always map between them

---

## Network Connectivity Handling

```swift
// Core/Network/NetworkMonitor.swift
protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    var connectionUpdates: AsyncStream<Bool> { get }
}

@Observable
final class NetworkMonitor: NetworkMonitorProtocol {
    private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    var connectionUpdates: AsyncStream<Bool> {
        AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                let connected = path.status == .satisfied
                continuation.yield(connected)
            }
            continuation.onTermination = { [weak self] _ in
                self?.monitor.cancel()
            }
        }
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
```

**Connectivity rules:**
- NEVER assume network is always available
- Show offline banner/indicator at app level
- Repository handles offline-first logic (see Repository Rules)
- Queue failed mutations for retry when back online

---

## Network Resilience & Retry Policy (STRICTLY ENFORCED)

Every networked request follows these rules. No ad-hoc retry logic in screens, UseCases, or Repositories — all of it goes through the central `APIClient`.

### 1. Retry ONLY idempotent requests
Retrying a non-idempotent mutation (POST create offer, POST redeem deal, DELETE account) duplicates side effects. Retries are automatic ONLY for GET, PUT, DELETE by ID, HEAD. POST retries require an `Idempotency-Key` header.
```swift
enum HTTPMethod {
    case get, put(idempotent: Bool = true), delete, head
    case post(idempotencyKey: UUID? = nil)
    var isIdempotent: Bool {
        switch self {
        case .get, .delete, .head: return true
        case .put(let i): return i
        case .post(let key): return key != nil
        }
    }
}
```

### 2. Exponential backoff with jitter — max 3 retries
```swift
struct RetryPolicy: Sendable {
    let maxAttempts: Int = 3
    let baseDelay: Duration = .milliseconds(500)
    let maxDelay: Duration = .seconds(8)
    let jitter: ClosedRange<Double> = 0.8...1.2

    func delay(for attempt: Int) -> Duration {
        let exp = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
        let jittered = exp * Double.random(in: jitter)
        return jittered
    }
}
```
- Retry ONLY on transient failures: `URLError.notConnectedToInternet`, `.timedOut`, `.networkConnectionLost`, and HTTP 408, 429, 502, 503, 504
- NEVER retry on 4xx other than 408/429 — they're client errors, retrying won't fix them
- Honor `Retry-After` header on 429/503 — it overrides computed backoff

### 3. Request cancellation on screen dismissal
Every request must be cancellable. `Task` is cancelled automatically when the owning `.task { }` is torn down — USE THIS. Never use `Task.detached` for screen requests (it won't cancel).
```swift
// ✅ CORRECT — request tied to screen lifecycle
struct DealDetailScreen: View {
    @State var viewModel: DealDetailViewModel
    var body: some View {
        content
            .task(id: viewModel.dealId) {
                await viewModel.load()     // Cancels if user leaves OR dealId changes
            }
    }
}

// ❌ BANNED — request survives user leaving screen, writes stale state on return
.onAppear { Task.detached { await viewModel.load() } }
```
When the user navigates away and the Task is cancelled, `CancellationError` propagates. Repositories MUST check `Task.checkCancellation()` before updating `@Observable` state post-await.

### 4. 401 auto-refresh, at most ONCE per request
The `AuthInterceptor` attempts a refresh on 401 EXACTLY ONCE per original request. If refresh succeeds, replay the request with the new token. If refresh fails OR the replayed request returns 401 again → emit `AppError.unauthenticated`, clear tokens, route to login.
```swift
actor RefreshCoordinator {
    private var inFlight: Task<String, Error>?

    func currentOrRefreshedToken() async throws(AppError) -> String {
        if let task = inFlight { return try await task.value }
        let task = Task { try await refreshToken() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
```
- NEVER spawn multiple concurrent refresh calls — coalesce in an actor so parallel 401s wait for the single refresh
- NEVER retry the refresh call itself on failure — one shot, then force re-login

### 5. Offline mutation queue
Mutations that fail with "no network" are enqueued and replayed when `NetworkMonitor.isConnected` transitions to true. Queue persists across app launches (disk-backed) so a kill-swipe doesn't lose a pending offer creation.
```swift
// Core/Network/MutationQueue.swift
protocol MutationQueue: Sendable {
    func enqueue(_ mutation: PendingMutation) async throws(AppError)
    func drain() async       // Called by app when connectivity returns
    var pending: AsyncStream<[PendingMutation]> { get }
}

struct PendingMutation: Codable, Sendable, Identifiable {
    let id: UUID
    let endpoint: String
    let method: String
    let body: Data
    let idempotencyKey: UUID     // REQUIRED — server uses this to deduplicate replays
    let enqueuedAt: Date
    let maxAttempts: Int = 5
}
```
- EVERY enqueued mutation carries an `idempotencyKey` — the server MUST deduplicate by this key to prevent double-creation on replay
- UI shows a small "2 pending" indicator when queue is non-empty — gated behind the app-level offline banner
- If a mutation's 5 attempts exhaust, move to a dead-letter list and surface a retryable error to the user — NEVER silently drop
- Queue is `EncryptedDataStore` if the body contains PII (offer description, user notes)

### 6. Search & text input — debounce 300ms
Typing should not fire a request per keystroke. Debounce at the ViewModel, not in the View.
```swift
@MainActor
@Observable
final class SearchViewModel {
    var query: String = "" { didSet { scheduleSearch() } }
    private var searchTask: Task<Void, Never>?

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, query.count >= 2 else { return }
            await runSearch(query)
        }
    }
}
```
- 300ms is the standard — shorter feels jumpy, longer feels laggy
- `query.count >= 2` — don't search for single-character queries (too noisy, returns everything)
- ALWAYS cancel the prior debounce task before scheduling a new one

### 7. Force-upgrade & maintenance mode
The server can return HTTP 503 with a `X-App-Minimum-Version` header, or a 200 with a `maintenanceMode` envelope. The client MUST handle both at the `APIClient` layer, NOT per-screen.
```swift
enum ServerGate: Sendable {
    case maintenanceMode(returningAt: Date?, message: String)
    case forceUpgrade(minimumVersion: String, storeURL: URL)
}

// APIClient intercepts and publishes via AsyncStream<ServerGate>
// App observes and presents a blocking full-screen view — ALL other UI is obscured
```
- Force-upgrade view has ONE action: "Open App Store" (iOS) → deep link
- Maintenance-mode view shows ETA and a "Try again" button that retries the last request
- NEVER let a single failed request route the user to these gates — require 2 consecutive responses signalling the same gate (protects against transient misconfiguration)

---

## UX State & Perceived Performance (STRICTLY ENFORCED)

The rules that make the app *feel* fast. Perceived performance matters more than actual latency.

### 1. Loading-state hierarchy — initial ≠ refresh ≠ append
Every list/feed has FOUR distinct states; each renders differently. No blanket "is loading" boolean.
```swift
enum LoadState<T: Sendable>: Sendable {
    case initial                        // First load, screen empty → skeleton
    case loaded(T)                      // Content shown
    case refreshing(T)                  // Pull-to-refresh over existing content → subtle spinner
    case appending(T)                   // Load-more pagination → footer spinner
    case empty(EmptyReason)             // First-use / no-results / filtered-out
    case error(T?, AppError)            // Keep old data if present; show banner
}

enum EmptyReason: Sendable {
    case firstUse                       // "Add your first deal"
    case noResults                      // "No deals match your search"
    case filteredOut                    // "Try clearing filters"
    case offline                        // "You're offline — showing cached"
}
```
- Initial load → skeleton shimmer, never a centered spinner
- Refresh → system pull-to-refresh spinner; keep existing content visible
- Append → footer spinner; keep existing rows visible
- Empty → NEVER just "No data"; pick the right reason + matching CTA

### 2. Skeleton / shimmer for initial load — NEVER centered spinner
A centered `ProgressView` on a blank screen feels broken. Use a skeleton that matches the real layout shape.
```swift
struct DealCardSkeleton: View {
    @State private var isAnimating = false
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.svShimmer)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.svShimmer).frame(height: 16)
                RoundedRectangle(cornerRadius: 4).fill(Color.svShimmer).frame(width: 120, height: 12)
            }
        }
        .redacted(reason: .placeholder)
        .shimmer(isAnimating: isAnimating)   // Custom modifier, simple opacity animation
        .onAppear { isAnimating = true }
    }
}
```
- Skeleton count matches realistic viewport (5–8 deal cards, not 2 and not 100)
- Respect `@Environment(\.accessibilityReduceMotion)` — disable the shimmer animation when user has Reduce Motion on, keep the placeholder shape
- NEVER use skeleton for "refreshing" states — refreshes keep real content; skeleton is for initial-load only

### 3. Pull-to-refresh — `.refreshable { }` MANDATORY on every list
```swift
List(viewModel.deals) { deal in DealRow(deal: deal) }
    .refreshable { await viewModel.refresh() }
```
- EVERY feed, list, and grid supports pull-to-refresh — users expect it, cost is ~3 lines
- Refresh calls `viewModel.refresh()`, which re-fetches from network and updates `state` in-place — does NOT reset to `.initial`
- If the user pulls while already refreshing, the second pull is debounced (SwiftUI handles this)

### 4. Optimistic updates with rollback
For actions the user expects to feel instant (favourite, save deal, follow restaurant), update local state IMMEDIATELY, then fire the mutation, then roll back on failure.
```swift
@MainActor
func toggleFavourite(dealId: Int64) {
    let wasFavourited = state.deals.first { $0.id == dealId }?.isFavourited ?? false
    mutate(dealId) { $0.isFavourited.toggle() }            // ✅ Optimistic update — UI flips instantly

    Task {
        do throws(AppError) {
            try await favouriteUseCase.execute(dealId: dealId, favourite: !wasFavourited)
        } catch {
            mutate(dealId) { $0.isFavourited = wasFavourited }   // ✅ Rollback
            showToast(.error("Couldn't save favourite — try again"))
        }
    }
}
```
- Use for: toggles, likes, small reorders, local marks — anything reversible
- Do NOT use for: creating a new record, payment, destructive delete — those need confirmation + loading state
- ALWAYS pair with a fallback toast/snackbar on rollback — silent reverts are confusing

### 5. Empty states — ALWAYS have copy + illustration + CTA
```swift
EmptyStateView(
    illustration: .noSearchResults,           // SF Symbol or custom SVG
    title: "No deals match your search",
    subtitle: "Try different keywords, or clear your filters",
    primaryAction: .init("Clear filters") { viewModel.clearFilters() },
    secondaryAction: .init("Browse all deals") { router.navigate(.allDeals) }
)
```
- NEVER ship "No data" / "Empty" as the full message — pick one `EmptyReason` and match copy to it
- Every empty state has a CTA that helps the user progress — NEVER just a sad face

### 6. Form draft autosave — 60-second cadence + on background
Long forms (offer creation, signup) autosave to `EncryptedDataStore` so accidental dismissal doesn't lose work.
```swift
@MainActor
@Observable
final class OfferFormViewModel {
    init(draftStore: OfferDraftStore, ...) {
        self.draftStore = draftStore
        Task { await restoreDraft() }            // On init, prompt: "Resume draft?"
        startAutosave()
    }

    private func startAutosave() {
        Task {
            for await _ in AsyncTimer.interval(.seconds(60)) {
                await draftStore.save(snapshot())
            }
        }
    }

    func onDisappear() async { await draftStore.save(snapshot()) }   // Also save when leaving
    func submit() async { await draftStore.clear(); /* submit real offer */ }
}
```
- Save every 60 seconds AND on `.onDisappear` / `UIApplication.willResignActiveNotification`
- On next open, show a one-tap "Resume draft?" banner — don't auto-restore silently (could surprise user)
- Clear the draft on successful submit

### 7. Scroll position preservation across navigation
When user scrolls a list, taps a row, then returns, the list MUST be scrolled to the same position — not reset to top. `NavigationStack` handles this automatically IF the list isn't rebuilt on return.
```swift
// ✅ CORRECT — @State var in the screen, survives re-entry via NavigationStack
struct DealListScreen: View {
    @State private var scrollPosition: Int64?     // Bind to ScrollPosition on iOS 17+
    @State var viewModel: DealListViewModel

    var body: some View {
        List(viewModel.deals) { ... }
            .scrollPosition(id: $scrollPosition)
    }
}

// ❌ BANNED — rebuilding the ViewModel on re-entry loses scroll state
// Don't recreate ViewModel in body; inject it once at navigation time.
```

### 8. Feedback surface decision tree
| Event | Surface | Example |
|---|---|---|
| Non-blocking success | Toast (auto-dismiss, ~2s) | "Offer saved" |
| Non-blocking failure | Toast with retry action | "Couldn't save — Retry" |
| Blocking confirmation | Dialog (modal) | "Delete this offer? Can't be undone." |
| Progressive status | Inline banner | "You're offline — showing cached" |
| Success with undo | Snackbar with action | "Offer deleted — Undo" |
| Fatal / force-upgrade | Full-screen takeover | "Please update Svangur to continue" |

- NEVER use a modal dialog for a non-blocking success — it interrupts flow
- Toasts MUST be queued (one at a time), not stacked
- Undo windows are 5 seconds for destructive actions — after that, the action commits server-side

---

## Auth Token / Interceptor Pattern

```swift
// Core/Network/AuthenticatedAPIClient.swift
actor AuthenticatedAPIClient {
    private let baseClient: APIClient
    private let tokenManager: TokenManagerProtocol
    private var isRefreshing = false

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var request = endpoint.urlRequest
        if let token = await tokenManager.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            return try await baseClient.execute(request)
        } catch APIError.unauthorized {
            // Auto-refresh token
            let newToken = try await refreshToken()
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await baseClient.execute(request)
        }
    }

    private func refreshToken() async throws -> String {
        guard !isRefreshing else {
            // Wait for ongoing refresh
            try await Task.sleep(for: .milliseconds(500))
            return try await tokenManager.getAccessToken() ?? ""
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let refreshToken = try await tokenManager.getRefreshToken()
        let newTokens = try await baseClient.refreshToken(refreshToken: refreshToken)
        await tokenManager.saveTokens(newTokens)
        return newTokens.accessToken
    }
}
```

---

## Security — MANDATORY

```swift
// ❌ BANNED — NEVER do these
let apiKey = "sk-abc123..."                          // ❌ Hardcoded secrets
UserDefaults.standard.set(token, forKey: "auth")     // ❌ Tokens in UserDefaults

// ✅ REQUIRED — Use Keychain for sensitive data
final class KeychainManager: KeychainManagerProtocol {
    func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)     // Remove old value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }

    func read(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
```

**Security rules:**
- NEVER commit API keys, secrets, tokens to git
- Secrets go in `.xcconfig` files (which are in `.gitignore`)
- Use Keychain for stored tokens, passwords, sensitive data
- NEVER use UserDefaults for sensitive information
- Enable App Transport Security — no cleartext HTTP
- Use certificate pinning for sensitive API calls
- NEVER log sensitive data — use `os.Logger` with `.private` for PII
- Enable Hardened Runtime for Mac apps

### Biometric Authentication — `LocalAuthentication` for JWT Unlock

When the user has a stored JWT, subsequent app launches should unlock via Face ID / Touch ID rather than re-prompting for password. Use `LAContext` from `LocalAuthentication`.

```swift
// ✅ REQUIRED pattern — in AuthRepository
import LocalAuthentication

actor BiometricUnlock {
    func unlockSession(reason: String) async throws(AppError) -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw .biometricUnavailable
        }

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let laError as LAError where laError.code == .userCancel {
            return false                           // User tapped cancel — not an error
        } catch {
            throw .biometricFailed(reason: error.localizedDescription)
        }
    }
}
```

**Biometric rules:**
- `NSFaceIDUsageDescription` MUST be in Info.plist with a clear user-facing reason
- Fall back policy: `.deviceOwnerAuthentication` (allows passcode if biometrics fail 3x) — NOT biometrics-only
- NEVER cache biometric results beyond a single session — re-prompt on cold launch
- The JWT itself is stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — biometric unlock is an additional gate, not a replacement for Keychain
- If the user disables biometrics in Settings, fall through to password login — don't lock them out
- `LAContext` is not `Sendable` — create it fresh per unlock attempt, don't store it on a long-lived actor

---

## Logging — os.Logger ONLY

```swift
// ❌ BANNED
print("User logged in: \(userId)")             // ❌ print in production code
NSLog("Debug: %@", data)                       // ❌ NSLog is slow and leaks to Console

// ✅ REQUIRED — os.Logger (unified logging)
import os

extension Logger {
    static let auth = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "auth")
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ui")
}

// Usage
Logger.auth.info("User logged in: \(userId, privacy: .private)")    // ✅ PII redacted in release
Logger.network.error("Request failed: \(error.localizedDescription)")
Logger.network.debug("Response: \(data.count) bytes")               // ✅ Debug only
```

**Logging rules:**
- NEVER use `print()` — always `Logger`
- NEVER use `NSLog()` — always `Logger`
- NEVER log sensitive data (tokens, passwords, PII) — use `.private` privacy level
- Category per module: `auth`, `network`, `database`, `ui`
- Use appropriate levels: `.debug`, `.info`, `.error`, `.fault`

---

## Swift Package Manager — Dependency Management (MANDATORY)

```swift
// Package.swift or Xcode SPM integration
// ALL dependencies managed via SPM — no CocoaPods, no Carthage for new projects

// Key dependencies (add only what you need):
dependencies: [
    // Networking (if not using plain URLSession)
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
    // Image loading (if AsyncImage isn't enough)
    .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
    // Linting
    // swiftlint installed via Homebrew, not SPM
    // Testing helpers
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
]
```

**Dependency rules:**
- Use Swift Package Manager ONLY — no CocoaPods or Carthage for new dependencies
- Pin to major versions: `.upToNextMajor(from: "5.0.0")`
- Minimize third-party dependencies — prefer Apple frameworks when possible
- Review every dependency for maintenance status before adding
- Lock Package.resolved into git for reproducible builds

---

## Build Configurations

```
// Use .xcconfig files for environment-specific values
// Debug.xcconfig
API_BASE_URL = https:/$()/api-dev.example.com
ENABLE_LOGGING = YES

// Release.xcconfig
API_BASE_URL = https:/$()/api.example.com
ENABLE_LOGGING = NO

// Access in code via Info.plist
guard let baseURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String else {
    fatalError("API_BASE_URL not configured")
}
```

**Build rules:**
- ALWAYS have separate Debug and Release configurations
- Use `.xcconfig` files for environment variables (not hardcoded)
- Debug builds: enable logging, use dev API, disable analytics
- Release builds: disable logging, use production API, enable crash reporting
- NEVER ship debug code to production — use `#if DEBUG` guards

---

## Privacy Manifests — MANDATORY (App Store Requirement)

Starting May 2024, Apple **rejects** apps that use required reason APIs without a privacy manifest. This is enforced at App Store review.

### PrivacyInfo.xcprivacy — required in every app target

Add `PrivacyInfo.xcprivacy` to the app target (Xcode → File → New → App Privacy):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Nutrition labels — what data your app collects -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePreciseLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>

    <!-- Required reason APIs — declare WHY you use them -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- UserDefaults / @AppStorage -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>  <!-- Read/write app settings -->
            </array>
        </dict>
        <!-- File timestamp APIs (if using file modification dates) -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>  <!-- Access within app container -->
            </array>
        </dict>
        <!-- System boot time / Date APIs -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>  <!-- Measure time elapsed -->
            </array>
        </dict>
    </array>

    <!-- Tracking domains — empty if no ATT tracking -->
    <key>NSPrivacyTrackingDomains</key>
    <array/>

    <!-- Tracking flag — false if you don't use ATT -->
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

### Info.plist — required privacy usage descriptions

```xml
<!-- MUST be present for any app using these features -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Svangur uses your location to show nearby restaurant deals.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Svangur uses your location to notify you about nearby deals.</string>

<key>NSCameraUsageDescription</key>
<string>Svangur needs camera access to take photos of your restaurant.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Svangur needs photo access to upload restaurant and offer images.</string>

<!-- Push notifications (no description key needed, but entitlement required) -->
<!-- App Transport Security — enforce HTTPS -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <!-- Dev exception (remove for production) -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Privacy manifest rules:**
- `PrivacyInfo.xcprivacy` MUST exist in the app target — App Store rejects without it
- Update it when adding new APIs that Apple requires reasons for (UserDefaults, disk space, file timestamps, system boot time)
- Third-party SDKs must also ship their own privacy manifests — check with `swift package audit`
- Every permission usage string MUST clearly explain WHY (not just "needs access")
- Review Apple's "Required Reason API" list before using any new system API: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- NEVER set `NSAllowsArbitraryLoads = true` in production builds

---

## Background Tasks

```swift
// ✅ BGTaskScheduler for deferred background work
import BackgroundTasks

func scheduleSync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.app.sync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

func handleSync(task: BGAppRefreshTask) {
    let syncTask = Task {
        do {
            try await syncRepository.syncPendingChanges()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        syncTask.cancel()
    }

    scheduleSync()     // Reschedule for next time
}
```

**Background task rules:**
- Use `BGTaskScheduler` for deferred, system-scheduled work
- Use `.task { }` on views for immediate async work tied to view lifecycle
- Set `expirationHandler` to cancel long-running work gracefully
- NEVER rely on background time for critical operations — design for interruption

---

## Accessibility — REQUIRED

```swift
// ✅ ALL interactive elements must have accessibility labels
Button(action: { viewModel.deleteItem() }) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete item")                      // ✅ Descriptive label
.accessibilityHint("Removes this item from your list")  // ✅ Optional hint

// ✅ Decorative images
Image(systemName: "star.fill")
    .accessibilityHidden(true)                           // ✅ Hide from VoiceOver

// ✅ Minimum tap target
Button("Edit") { }
    .frame(minWidth: 44, minHeight: 44)                  // ✅ 44pt minimum

// ✅ Dynamic Type support
Text(user.name)
    .font(.body)                                         // ✅ Scales with system setting
// ❌ .font(.system(size: 12))                           // ❌ Fixed size, doesn't scale
```

**Accessibility rules:**
- EVERY interactive element needs `.accessibilityLabel()`
- Decorative elements: `.accessibilityHidden(true)`
- Minimum touch target: 44pt x 44pt (Apple HIG requirement)
- Test with VoiceOver enabled
- Support Dynamic Type — use semantic fonts (`.body`, `.title2`)
- NEVER hardcode font sizes with `.system(size:)` for user-facing text
- Ensure sufficient color contrast

---

## Localization — String Catalogs

```swift
// ❌ BANNED
Text("Loading...")                         // ❌ Hardcoded string
Text("Hello, \(name)")                    // ❌ Hardcoded with variable

// ✅ REQUIRED — Use String Catalogs (Localizable.xcstrings)
Text("loading_text")                       // ✅ Key from String Catalog
Text("greeting \(name)")                   // ✅ Interpolation auto-extracted

// ✅ For programmatic use outside Views
let message = String(localized: "error_network")
let formatted = String(localized: "items_count \(count)")
```

**Localization rules:**
- ZERO hardcoded user-facing strings — everything via String Catalogs
- Use Xcode String Catalogs (`.xcstrings`) — not legacy `.strings` files
- String interpolation in `Text()` is auto-extracted by Xcode
- Date/Time formatting: use `.formatted()` with locale — never manual formatting
- RTL support: use `.leading/.trailing` instead of `.left/.right` in layouts
- Use `LocalizedStringKey` for strings passed to SwiftUI views

---

## SwiftData / Core Data — Best Practices

```swift
// ✅ SwiftData model (iOS 17+)
@Model
final class UserEntity {
    @Attribute(.unique) var id: String
    var name: String
    var email: String
    var avatarUrl: String?
    var updatedAt: Date

    init(id: String, name: String, email: String, avatarUrl: String?, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.updatedAt = updatedAt
    }
}

// ✅ Repository uses ModelContext — NOT the View
final class UserLocalDataSource {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getAllUsers() throws -> [UserEntity] {
        let descriptor = FetchDescriptor<UserEntity>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor)
    }

    func upsert(_ entity: UserEntity) throws {
        modelContext.insert(entity)
        try modelContext.save()
    }

    func deleteById(_ id: String) throws {
        let descriptor = FetchDescriptor<UserEntity>(predicate: #Predicate { $0.id == id })
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }
}
```

**Database rules:**
- Entity ≠ Domain Model — always map between them
- NEVER use `@Query` directly in Views for complex features — go through Repository
- Use `@Query` only for simple, read-only lists where Clean Architecture overhead isn't justified
- Handle migrations properly — test with real data before shipping
- Use `ModelContext` in the Data layer, not in Views or ViewModels

---

## Analytics, Tracking & Consent — GDPR + App Tracking Transparency (STRICTLY ENFORCED)

Svangur has defined analytics events (`trackView`, `trackClick`, `trackMap`, `trackCall`, `trackWebsite`) and ships to EU/EEA users (Icelandic locale) — GDPR applies. Claude Code MUST NOT wire up any analytics SDK without these rules.

### Consent categories

```swift
enum ConsentCategory: String, CaseIterable, Sendable {
    case analytics       // trackView, trackClick, etc.
    case crashReporting  // Sentry / Crashlytics
    case marketing       // personalised push, remarketing
}

protocol ConsentManagerProtocol: Sendable {
    func hasConsent(for category: ConsentCategory) async -> Bool
    func grant(_ category: ConsentCategory) async
    func revoke(_ category: ConsentCategory) async
    func consentStates() async -> [ConsentCategory: Bool]
}
```

- Consent is collected on first launch via a full-screen sheet (NOT a dismissible banner)
- Each category is independently toggleable — user can accept crash reporting but decline analytics
- Revoking consent MUST immediately stop all collection for that category (no "next session" delay)
- Consent state persisted in Keychain, not `UserDefaults` (survives reinstall)
- If `ConsentManager` says `false` for a category, that SDK MUST NOT initialize

### Gating events

```swift
@MainActor
final class AnalyticsService: AnalyticsServiceProtocol, Sendable {
    private let consentManager: ConsentManagerProtocol
    private let provider: AnalyticsProviderProtocol    // Firebase / Segment / Mixpanel behind a protocol

    func trackView(offerId: Int64) async {
        guard await consentManager.hasConsent(for: .analytics) else { return }  // ✅ Gate every event
        await provider.log("deal_view", params: ["offer_id": offerId])
    }
}
```

### App Tracking Transparency (ATT)

ATT is required ONLY IF the app tracks users across other apps/websites or shares identifiers with data brokers. Svangur's first-party backend analytics (view/click/etc.) DO NOT require ATT. It becomes mandatory the moment an ad network / attribution SDK (AppsFlyer, Adjust, Branch, Meta, Google Ads) is added.

```swift
import AppTrackingTransparency

@MainActor
final class TrackingPermissionService: Sendable {
    func requestIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return ATTrackingManager.trackingAuthorizationStatus
        }
        return await ATTrackingManager.requestTrackingAuthorization()
    }
}
```

**ATT rules:**
- `NSUserTrackingUsageDescription` in Info.plist — user-facing reason, localized for `is`
- Prompt ONLY after a user action (e.g. after accepting analytics consent) — NEVER on first launch unprompted
- Status `≠ .authorized` → IDFA is zeros; no cross-app tracking allowed. Ad SDKs MUST fall back to contextual/non-personalised mode.

### What NOT to do
- ❌ Track anything before consent is granted — not even "app_launched"
- ❌ Include PII (email, user name, precise location) in event parameters — aggregate only
- ❌ Use `UIDevice.current.identifierForVendor` as an IDFA substitute for tracking — this IS tracking
- ❌ Import an analytics SDK without a protocol boundary — breaks consent gating

---

## Crash Reporting & Observability (MANDATORY)

Every crash, fatal exception, and unhandled error MUST be captured, symbolicated, and triaged within 24 hours of release. No app ships without crash reporting.

### Service contract

```swift
protocol CrashReportingServiceProtocol: Sendable {
    func record(_ error: Error, context: [String: String])
    func setUser(id: String?)                                    // Hashed (SHA-256) opaque id; nil = logged out
    func setBreadcrumb(_ message: String, category: BreadcrumbCategory)
    func log(_ message: String, level: LogLevel)
}
```

**Rules:**
- Consent-gated: MUST check `ConsentManager.hasConsent(for: .crashReporting)` before initializing the provider SDK
- **NO PII**: never pass email, user name, phone, or exact location. User IDs are SHA-256 hashed opaque strings.
- **Symbolication**: dSYMs uploaded to the provider on every release build via a build-phase script — unsymbolicated crashes are useless
- **Breadcrumbs**: network calls, navigation events, and important state transitions add breadcrumbs automatically via the Service — do NOT scatter `breadcrumb(...)` calls through business logic
- **Fatal vs non-fatal**: use `record(_:)` for recoverable errors caught from `throws(AppError)` — surfaced in the dashboard without crashing the app
- **Recommended providers**: Sentry (preferred — ergonomic with typed throws) or Firebase Crashlytics. Both behind the protocol above so we can swap.

### What NOT to do
- ❌ Log request / response bodies — they may contain tokens or PII
- ❌ Call `fatalError(...)` to "test" the crash reporter — it creates real crashes in the same build users see
- ❌ Ship release builds without uploaded dSYMs
- ❌ Use multiple crash reporters simultaneously — their signal handlers conflict

### MetricKit — Launch Time, Hangs, Disk Writes

`MetricKit` (iOS 13+, greatly expanded in iOS 16+) streams real-device performance payloads: launch time, hang rate, CPU time, disk writes, memory footprint. It costs nothing to enable and catches regressions that crashes don't surface.

```swift
import MetricKit

@MainActor
final class MetricObserver: NSObject, MXMetricManagerSubscriber {
    func start() {
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Forward to crash reporter / analytics with consent gating
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.totalBucketCount, launch > 0 {
                // Log launch time P95/P99 to your observability backend
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Hangs, disk writes, CPU exceptions — each has structured diagnostic
        for payload in payloads {
            payload.hangDiagnostics?.forEach { hang in
                // Upload hang.callStackTree to observability, gated by consent
            }
        }
    }
}
```

**MetricKit rules:**
- Subscribe in `App.init` — payloads arrive once per day from the system; no user-visible latency
- Payloads MUST be gated by `ConsentCategory.CRASH_REPORTING` consent before upload
- Launch-time regressions of >100ms P95 should page on-call — wire alerts in the observability backend
- Hang diagnostics contain full callstacks — treat them like crashes for triage priority
- DO NOT use `MetricKit` as a replacement for a crash reporter — the two are complementary (crashes vs. performance)

---

## Feature Flags & Remote Config

Feature flags enable progressive rollouts and instant rollback without shipping a new build. Required for Svangur's ranking weights, filter options, and new-feature gates.

### Service protocol

```swift
protocol FeatureFlagServiceProtocol: Sendable {
    func bool(_ key: FeatureFlagKey, default: Bool) async -> Bool
    func int(_ key: FeatureFlagKey, default: Int) async -> Int
    func double(_ key: FeatureFlagKey, default: Double) async -> Double
    func string(_ key: FeatureFlagKey, default: String) async -> String
    func refresh() async     // Normally refreshes on launch + every 12h; use this for manual refresh
}

enum FeatureFlagKey: String, Sendable {
    case feedRankingWeightDistance    = "feed_ranking_weight_distance"
    case feedRankingWeightDiscount    = "feed_ranking_weight_discount"
    case showNewBoostInFeed           = "show_new_boost_in_feed"
    case enable2For1FilterChip        = "enable_2for1_filter_chip"
    // ...
}
```

**Rules:**
- Provider behind a protocol: **Firebase Remote Config**, **LaunchDarkly**, or **ConfigCat** — never expose the SDK type
- Flags have safe, sensible defaults baked into the binary — if network fails, app still works
- Reading a flag is `async`; fetch on launch, cache in memory for the session
- **Freeze the value at session start** for flags that must stay consistent for a user's session
- All flag keys live in `FeatureFlagKey` — NEVER use raw strings anywhere else
- Flags gate NEW features or tune numerical weights; they MUST NOT silently remove entitled functionality from paying users

### What NOT to do
- ❌ Read flags inside tight loops (e.g. per cell in a list) — read once per screen into local state
- ❌ Use Remote Config for secrets (API keys, endpoint URLs) — those live in the bundle / Keychain
- ❌ Couple flag reads to UI rendering — always read once and pass downward

---

## Deep Links, Universal Links & URL Schemes (MANDATORY)

Svangur must open deals from push notifications, shared URLs, emails, and the web. All user-facing links MUST be **Universal Links** (HTTPS), not custom URL schemes.

### Supported entry points

| Source | URL format | Destination |
|---|---|---|
| Shared deal URL | `https://svangur.com/deals/{id}` | `DealDetailScreen(id:)` |
| Restaurant page | `https://svangur.com/restaurants/{id}` | `RestaurantDetailScreen(id:)` |
| Push notification tap | Same HTTPS URL embedded in APS payload | Same |
| Password reset email | `https://svangur.com/reset?token=...` | `ResetPasswordScreen` |

### Apple App Site Association (AASA)

- Hosted at `https://svangur.com/.well-known/apple-app-site-association`
- Entitlement: `com.apple.developer.associated-domains = ["applinks:svangur.com"]`
- Must serve with `Content-Type: application/json`, NO `.json` extension in URL path, NO redirects
- Validate with `https://search.developer.apple.com/appsearch-validation-tool` before every release

### Handling in SwiftUI

```swift
@main
struct SvangurApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
                .onOpenURL { url in router.handle(url) }                          // URL scheme + cold start
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { router.handle(url) }      // Universal Link
                }
        }
    }
}
```

**Router rules:**
- `DeepLinkRouter` is a pure parser that maps URL → `NavigationRoute` enum; NO networking, NO auth checks here
- Route enum is the same type used by in-app navigation — one navigation model
- Unknown / malformed URLs → open Home with a non-blocking banner "Link not found"
- Token-containing URLs (password reset) MUST be consumed immediately — never leave tokens in browser history

### What NOT to do
- ❌ Custom URL scheme (`svangur://...`) for user-shareable URLs — Universal Links only
- ❌ Handling a URL from inside a deep-nested ViewModel — always route through the App-level router
- ❌ Auto-login from a link without user confirmation

---

## Push Notifications (APNs)

Svangur sends push for: new deals from followed restaurants, deals expiring soon, account verification, offer approval status.

### Setup

1. **Capabilities:** Push Notifications + Background Modes (Remote notifications)
2. **Entitlement:** `aps-environment` = `development` or `production`
3. **Provider:** APNs directly OR Firebase Cloud Messaging (behind a protocol)
4. **Token lifecycle:** on login success → send APNs device token to backend with user ID; on logout → DELETE token server-side

### Protocol

```swift
protocol PushNotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> UNAuthorizationStatus
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    func registerDeviceToken(_ token: Data) async throws(AppError)
    func unregisterDevice() async throws(AppError)
}
```

### Authorization flow

- Show a **pre-prompt rationale screen** before calling `requestAuthorization()` — explain what notifications are for
- Ask AFTER the user has engaged (e.g. after favoriting their first restaurant) — NEVER on first launch
- Persist status so we don't re-prompt users who have declined

### Payload handling

- APS payload carries a deep link URL — forward to `DeepLinkRouter` (never implement custom per-notification navigation)
- Silent pushes (`content-available: 1`) only for token refresh / session invalidation — NEVER to trigger business logic
- Interactive actions: declare via `UNNotificationCategory` (e.g. "View Deal" action)

### Consent

- Marketing-topic subscriptions (new deal alerts) MUST check `ConsentManager.hasConsent(for: .marketing)`
- Transactional pushes (password reset, account verification) do NOT require marketing consent — they are functional
- Unsubscribing from marketing pushes MUST NOT remove transactional pushes

---

## Location Services & Permissions — Core Svangur Pattern

Svangur's feed ranks deals by distance. Location is a first-class dependency. Follow this pattern for ALL location access.

### Service protocol

```swift
protocol LocationServiceProtocol: Sendable {
    var authorizationStatus: CLAuthorizationStatus { get async }
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus
    func currentLocation(accuracy: CLLocationAccuracy) async throws(AppError) -> CLLocation
    func locationStream(accuracy: CLLocationAccuracy) -> AsyncStream<CLLocation>
}

actor LocationService: LocationServiceProtocol {
    // Uses CLLocationManager internally; exposes only Sendable async API.
}
```

### Info.plist (REQUIRED)

```
NSLocationWhenInUseUsageDescription = "Svangur uses your location to show deals near you."
```
- Text explains the **benefit** to the user, not the permission mechanics
- NEVER request "Always" — Svangur has no background location use case
- Localize for `is` via `InfoPlist.strings`

### Authorization flow

1. User opens the Home screen → ViewModel reads `authorizationStatus`
2. If `.notDetermined` → show a **pre-prompt rationale screen** explaining why → user taps "Continue" → OS prompt
3. If `.denied` / `.restricted` → show fallback: manual city picker + a link to Settings
4. NEVER call `requestWhenInUseAuthorization()` on app launch — always in response to user intent

### Accuracy rules

- `kCLLocationAccuracyHundredMeters` for the deal feed — faster, battery-friendly, enough for "deals within 5 km"
- `kCLLocationAccuracyBest` ONLY while the map is visible and zoomed in
- Stop updates in `.onDisappear` and on `@Environment(\.scenePhase) == .background`

### Privacy

- Location data is sent to backend ONLY if the user has granted permission (enforced client-side AND server-side)
- NEVER log exact coordinates to crash reports or analytics — round to 0.01° (~1.1 km) if logging is unavoidable
- Respect iOS 14+ "Precise" vs "Approximate" toggle — Svangur MUST work with approximate location

---

## Maps Integration

Svangur uses maps to show deal pins (list + detail + clustering). Rules:

- **MapKit** only — first-party, no extra SDK, no extra privacy manifest entries
- **SwiftUI `Map`** (iOS 17+) with `Annotation` for pins, NOT the legacy UIKit `MKMapView`
- Pin tap = floating popup card per FRD, NOT navigation. Popup has a "View Deal" CTA.
- Clustering at zoomed-out levels: use built-in `MKClusterAnnotation` with a count badge
- Filter state (discount type, category, open-now) is hoisted to a `MapFilterViewModel` that is SHARED with the list view — both read the same state
- Maps access location ONLY through `LocationServiceProtocol` — never talk to `CLLocationManager` directly from a `Map` view

```swift
Map(initialPosition: .userLocation(fallback: .region(icelandRegion))) {
    ForEach(viewModel.pins) { pin in
        Annotation(pin.restaurantName, coordinate: pin.coordinate) {
            DealPinView(pin: pin)
                .onTapGesture { viewModel.onPinTapped(pin.id) }
        }
    }
    UserAnnotation()
}
.mapControls { MapUserLocationButton(); MapCompass() }
```

### Offline / network handling

- MapKit shows cached tiles automatically when offline — our UI must display a non-blocking "Offline" banner, not an error state
- No custom tile cache — MapKit's is sufficient

---

## Form Validation Pattern (STRICTLY ENFORCED)

Svangur has login, signup, and offer forms with strict rules (offer title ≤ 60, description ≤ 150, email format, password strength, offer end > start). Use ONE pattern across ALL forms.

### Validation types

```swift
enum ValidationError: Error, Equatable, Sendable {
    case empty
    case tooShort(min: Int)
    case tooLong(max: Int)
    case invalidFormat
    case custom(messageKey: LocalizedStringKey)    // For rules with unique error copy
}

protocol Validator: Sendable {
    associatedtype Input
    func validate(_ input: Input) -> ValidationError?
}

struct EmailValidator: Validator {
    func validate(_ input: String) -> ValidationError? {
        if input.isEmpty { return .empty }
        if !input.contains("@") || !input.contains(".") { return .invalidFormat }
        return nil
    }
}
```

### ViewModel pattern

```swift
@MainActor
@Observable
final class OfferFormViewModel {
    var title: String = ""            { didSet { validateTitle() } }
    var description: String = ""      { didSet { validateDescription() } }
    var validStart: Date = .now
    var validEnd: Date = .now.addingTimeInterval(3600)   { didSet { validateDates() } }

    private(set) var titleError: ValidationError?
    private(set) var descriptionError: ValidationError?
    private(set) var dateError: ValidationError?

    var isValid: Bool {
        titleError == nil && descriptionError == nil && dateError == nil && !title.isEmpty
    }

    private func validateTitle() {
        titleError = title.isEmpty ? .empty : (title.count > 60 ? .tooLong(max: 60) : nil)
    }
    private func validateDates() {
        dateError = (validEnd > validStart) ? nil : .custom(messageKey: "form.error.end_before_start")
    }
    // ... description, price, etc.
}
```

**Form rules:**
- Validate on EVERY change (`didSet`) — errors appear as the user types, not on submit
- Validate AGAIN on submit — never trust UI state alone
- Error messages from `Localizable.xcstrings` via `LocalizedStringKey` — NEVER hardcoded English
- Submit button is `disabled` when `isValid == false`
- Inline error renders UNDER the field in `Color.svError` with `SvFont.caption`
- Max-length clamping at input time: `.onChange(of: title) { _, new in if new.count > 60 { title = String(new.prefix(60)) } }`

### What NOT to do
- ❌ Put validation logic in the View — it belongs in the ViewModel
- ❌ Use `String.lengthOfBytes(using:)` for character counts — use `title.count` (grapheme clusters) since Icelandic accented chars matter
- ❌ Block typing past the max (use clamp at the value level, not at the `TextField` key-input level)

### Keyboard Handling & `@FocusState`

Every form MUST manage focus explicitly. Tap-to-dismiss, submit-on-return, and correct next-field traversal are required.

```swift
struct LoginScreen: View {
    @State var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case email, password }

    var body: some View {
        VStack {
            TextInput(label: "Email", value: $viewModel.email)
                .focused($focusedField, equals: .email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            SecureTextInput(label: "Password", value: $viewModel.password)
                .focused($focusedField, equals: .password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { viewModel.login() }

            PrimaryButton(text: "Log In", onClick: viewModel.login, isLoading: viewModel.isLoading)
        }
        .scrollDismissesKeyboard(.interactively)     // ✅ Swipe down on scroll dismisses keyboard
        .onTapGesture { focusedField = nil }         // ✅ Tap outside dismisses keyboard
    }
}
```

**Keyboard rules:**
- EVERY text field declares `.keyboardType(...)` and `.textContentType(...)` — the latter enables iOS autofill (Keychain passwords, SMS codes, address lookup)
- EVERY multi-field form declares a `Field` enum and `@FocusState` — no exceptions
- `.submitLabel(.next)` / `.submitLabel(.go)` matches real-world semantic — "Next" on all but the final field, which uses "Go" / "Done" / "Send"
- `ScrollView`-hosted forms use `.scrollDismissesKeyboard(.interactively)` — never `.immediately` (jarring)
- NEVER attempt to shift the view manually when keyboard appears — SwiftUI handles this through safe areas automatically
- For OTP / SMS-code fields: `.textContentType(.oneTimeCode)` enables the "From Messages" autofill suggestion
- For password creation flows: use `.textContentType(.newPassword)` + `.passwordRules(...)` to hint iOS Strong Password
- iPad external keyboard: `Cmd+Return` should submit — wire this via `.keyboardShortcut(.return, modifiers: .command)` on the primary button

---

## Navigation Transitions (iOS 18+)

The iOS 18 `.navigationTransition(.zoom)` + matched-geometry API provides a hero transition for card → detail flows (deal card → deal detail). Polish feature — optional for MVP, but when used, use it correctly.

```swift
struct DealCard: View {
    let deal: Deal
    @Namespace private var namespace

    var body: some View {
        NavigationLink(value: DealRoute.detail(dealId: deal.id)) {
            DealCardContent(deal: deal)
                .matchedTransitionSource(id: deal.id, in: namespace)
        }
    }
}

// In the destination
struct DealDetailScreen: View {
    let dealId: Int64
    let namespace: Namespace.ID

    var body: some View {
        content
            .navigationTransition(.zoom(sourceID: dealId, in: namespace))
    }
}
```

**Rules:**
- Gate with `if #available(iOS 18, *)` for graceful fallback on iOS 17
- Use only for card → detail hero moments, NOT every navigation (it's visually noisy otherwise)
- Source `id` must match EXACTLY between source and destination — use the same domain model ID

---

## Avoid Over-Abstraction — NO Unnecessary Base Classes

```swift
// ❌ BANNED — Over-engineering
class BaseViewModel<S, E>: ObservableObject {
    // 200 lines of generic machinery nobody understands
}

protocol BaseRepository {
    associatedtype Entity
    func getAll() async -> [Entity]
    // Forced generic that doesn't fit every use case
}

protocol BaseUseCase {
    associatedtype Input
    associatedtype Output
    func execute(input: Input) async -> Output
}

// ✅ REQUIRED — Simple, direct, specific
// Just use @Observable directly. Each ViewModel is unique enough.
@MainActor @Observable
class LoginViewModel {
    // Direct, clear, no inheritance chain to trace
}

// UseCases use their own protocol — no base needed
protocol LoginUseCaseProtocol {
    func execute(credentials: Credentials) async throws(AppError) -> User
}
```

**Abstraction rules:**
- Do NOT create BaseViewModel, BaseRepository, BaseView
- Do NOT create generic UseCase base protocols with associated types
- Shared behavior goes in extensions or composition, NOT inheritance
- If you're creating a base class, ask: "Does EVERY subclass need ALL of this?" If no → don't
- Protocol extensions are your friend for shared default implementations

---

## Haptics — `SensoryFeedback` (iOS 17+)

Use SwiftUI's declarative `.sensoryFeedback(...)` modifier — NOT the imperative `UIImpactFeedbackGenerator`. Haptics are part of the UX contract and belong in a central token, not scattered literal calls.

```swift
// ❌ BANNED — imperative, fires on every render, iOS 16-era API
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.prepare()
generator.impactOccurred()

// ✅ REQUIRED — declarative, driven by state changes
Button("Save Offer", action: viewModel.save)
    .sensoryFeedback(.success, trigger: viewModel.saveCompleted)   // Fires when value changes to true

DealCard(deal: deal)
    .sensoryFeedback(.selection, trigger: isSelected)              // Fires on toggle

// Custom weights
.sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: tapCount)
```

**Haptics rules:**
- Use SwiftUI `.sensoryFeedback(...)` — NOT `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`
- Semantic feedback types MUST match action: `.success` for save/confirm, `.warning` for validation failure, `.error` for destructive failure, `.selection` for toggles, `.impact(.light)` for subtle taps
- NEVER fire haptics on appearance, scroll, or typing — only on discrete user actions (button tap, toggle, completion)
- Respect accessibility setting — SwiftUI automatically respects "Reduce Motion" and system haptic preferences, so NEVER manually check `UIAccessibility.isReduceMotionEnabled` for haptics
- iOS 17 deployment target guard: the project's minimum is iOS 17+, so `.sensoryFeedback` is always available — no `if #available` needed

---

## In-App Review — `RequestReviewAction` (iOS 16+)

Use SwiftUI's `@Environment(\.requestReview)` — NOT `SKStoreReviewController.requestReview(in:)` (deprecated-in-effect since iOS 16).

```swift
struct DealDetailScreen: View {
    @State var viewModel: DealDetailViewModel
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        content
            .onChange(of: viewModel.callCompleted) { _, completed in
                if completed && viewModel.shouldRequestReview {
                    requestReview()            // ✅ System-governed — may no-op, that's fine
                }
            }
    }
}
```

**In-App Review rules:**
- Trigger on a **moment of success** (user called restaurant from deal, redeemed offer, completed signup) — NOT on app launch, settings open, or error dismissal
- Maximum 3 prompts per user per 365 days — the system enforces this, but gate your own logic too (e.g. only after 5 successful interactions)
- Track whether prompt was triggered (not whether user rated — Apple does not expose that) in analytics, gated by consent
- NEVER call `requestReview()` inside `.task { }` or `onAppear` — users perceive it as intrusive and rate 1-star
- NEVER wrap it in a custom "Would you like to rate?" dialog — that's a policy violation

---

## SwiftLint Configuration

```yaml
# .swiftlint.yml — drop in project root
disabled_rules:
  - trailing_whitespace

opt_in_rules:
  - empty_count
  - closure_spacing
  - force_unwrapping
  - implicitly_unwrapped_optional
  - private_outlet
  - vertical_whitespace_closing_braces

force_cast: error                    # Force casts are errors, not warnings
force_try: error                     # Force try is an error
force_unwrapping: error              # Force unwrapping is an error

line_length:
  warning: 120
  error: 150

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 700

excluded:
  - Pods
  - DerivedData
  - .build
```

---

## Design Fidelity — Font, Padding & Style MUST Match Figma

Zero tolerance for "close enough." Every screen must be pixel-accurate to the Figma design. Mismatches are treated as bugs.

### Font Matching — EXACT from DesignSystem

```swift
// ❌ BANNED — Hardcoded fonts that don't match Figma
Text("Welcome")
    .font(.system(size: 24, weight: .bold))          // ❌ System font, not Poppins
Text("Email")
    .font(.headline)                                  // ❌ System semantic font

// ✅ REQUIRED — Always use DesignSystem tokens
Text("Welcome")
    .font(SvFont.heading)                             // ✅ Poppins SemiBold 24 (from Figma)
Text("Email")
    .font(SvFont.label)                               // ✅ Poppins Medium 16 (from Figma)
```

**Font rules:**
- ALWAYS use `SvFont.xxx` from `DesignSystem.swift` — never `.system(size:)`, never `.body/.headline`
- If a Figma frame uses a font size not in DesignSystem, add it to `SvFont` first — never inline
- Font weight MUST match Figma exactly: Regular ≠ Medium ≠ SemiBold ≠ Bold
- When Figma shows "Poppins Medium 16", use `SvFont.medium(16)` — not `SvFont.regular(16)`
- Check letter spacing (`tracking`) if Figma specifies it
- Check line height (`lineSpacing`) if Figma specifies it

### Padding & Spacing — EXACT from DesignSystem

```swift
// ❌ BANNED — Magic number padding
VStack(spacing: 12) { ... }                           // ❌ Where did 12 come from?
    .padding(.horizontal, 20)                         // ❌ Is this screenPadding or something else?
    .padding(.top, 8)                                 // ❌ Undocumented value

// ✅ REQUIRED — Named spacing tokens
VStack(spacing: SvSpacing.md) { ... }                 // ✅ md = 12, documented
    .padding(.horizontal, SvSpacing.screenPadding)    // ✅ 24pt, matches Figma
    .padding(.top, SvSpacing.sm)                      // ✅ sm = 8, documented
```

**Spacing rules:**
- NEVER use raw numbers for padding/spacing — always `SvSpacing.xxx`
- If Figma shows a gap not in `SvSpacing`, add a named constant first — never inline
- Screen horizontal padding is ALWAYS `SvSpacing.screenPadding` (24pt)
- Form field vertical spacing is ALWAYS `SvSpacing.formFieldSpacing` (20pt)
- Section spacing is ALWAYS `SvSpacing.sectionSpacing` (24pt)
- Measure Figma gaps with the ruler tool (Option + hover in Figma Dev Mode)

### Color — EXACT from DesignSystem

```swift
// ❌ BANNED — Hardcoded colors
Text("Error")
    .foregroundStyle(Color.red)                       // ❌ System red, not brand
    .background(Color(hex: "F5F5F5"))                 // ❌ Inline hex

// ✅ REQUIRED — Named color tokens
Text("Error")
    .foregroundStyle(Color.svError)                   // ✅ #F44336 from Figma
    .background(Color.svBackground)                   // ✅ #F5F5F5 from Figma
```

### Dark Mode / Appearance — Every Color Token Has a Dark Variant

Every color token in the Asset Catalog MUST define both light and dark variants — even if the current Figma design only shows light mode. Adding dark mode later without this rule means visiting every screen.
```swift
// ✅ REQUIRED — define colors in Assets.xcassets with Appearance = "Any, Dark"
// Light: #F5F5F5   Dark: #1C1C1E
Color.svBackground
// Light: #111111   Dark: #F2F2F7
Color.svOnBackground
```
If the design team hasn't delivered dark-mode values yet, temporarily map dark to the light value in the Asset Catalog (NOT in code) and file a design ticket. This keeps the structure right; only the palette changes later.

**Dark mode rules:**
- NEVER read `@Environment(\.colorScheme)` to swap colors in code — always define a semantic token (`Color.svBackground`) and let the Asset Catalog handle the switch
- Status bar style adapts automatically via `@Environment(\.colorScheme)` + `.toolbarColorScheme(...)` — don't hardcode
- Screenshots / `#Preview` blocks: add `.preferredColorScheme(.dark)` variants for every screen
- Test Dynamic Type + Dark Mode combinations explicitly — they stack and reveal layout bugs
- If a specific screen must stay light (e.g. splash with brand artwork), use `.preferredColorScheme(.light)` at that screen's root — NEVER app-wide

```swift
#Preview("Login - Light")  { LoginScreen(viewModel: .previewInstance()) }
#Preview("Login - Dark")   { LoginScreen(viewModel: .previewInstance()).preferredColorScheme(.dark) }
```

### Corner Radius — EXACT from DesignSystem

```swift
// ❌ BANNED
.clipShape(RoundedRectangle(cornerRadius: 10))        // ❌ Magic number

// ✅ REQUIRED
.clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))   // ✅ 10pt, for inputs
.clipShape(RoundedRectangle(cornerRadius: SvSpacing.buttonRadius))  // ✅ 12pt, for buttons
.clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))    // ✅ 16pt, for cards
```

### Component Heights — EXACT from DesignSystem

```swift
// ❌ BANNED
TextField("Email", text: $email)
    .frame(height: 50)                                // ❌ Wrong height

// ✅ REQUIRED — Match Figma precisely
TextField("Email", text: $email)
    .frame(height: SvSpacing.inputHeight)             // ✅ 55pt (Figma-measured)

Button("Log in") { }
    .frame(height: SvSpacing.buttonHeight)            // ✅ 53pt (Figma-measured)
```

### Verification Workflow — MANDATORY per screen

After building any screen, run this checklist:

1. **Screenshot** the SwiftUI Preview (or Simulator) at 428pt width (iPhone 14 Pro)
2. **Screenshot** the Figma frame at the same size
3. **Overlay compare** — place screenshots side-by-side (or use Figma overlay)
4. **Check each property:**
   - [ ] Font family matches (Poppins, not system)
   - [ ] Font weight matches (Regular vs Medium vs SemiBold vs Bold)
   - [ ] Font size matches (check with Figma Dev Mode)
   - [ ] Text color matches (check hex values)
   - [ ] Padding/margins match (measure with ruler)
   - [ ] Component heights match (input=55, button=53)
   - [ ] Corner radii match (input=10, button=12, card=16)
   - [ ] Background colors match
   - [ ] Shadow/elevation matches
   - [ ] Icon sizes match
   - [ ] Image aspect ratios match

5. **Report deltas concretely** — not "it looks off," but:
   ```
   "Email field label is Regular 14, Figma shows Medium 16"
   "Gap between password and button is 16pt, Figma shows 20pt"
   "Login button is 50pt tall, should be 53pt per Figma"
   ```

**Zero-tolerance items (PR will be rejected):**
- Wrong font family (system instead of Poppins)
- Wrong font weight (Regular instead of SemiBold)
- Wrong primary color (system blue instead of #F06285)
- Missing screen padding (content touching edges)
- Wrong input/button heights (anything other than 55pt/53pt)

---

## Git Conventions
- Run `swiftlint` and `swiftformat .` before every commit
- Run tests before pushing
- Commit message format: `feat(auth): add login validation`
- Branch naming: `feature/auth-login`, `bugfix/crash-on-profile`, `refactor/user-repository`
- PR must pass: lint, unit tests, build
- NEVER commit: `.xcconfig` with secrets, Certificates, Provisioning Profiles, `.env` files
