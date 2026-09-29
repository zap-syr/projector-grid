---
name: flutter-desktop-arch
description: >
  Write robust, high-performance, production-quality Flutter code for Windows and macOS
  desktop applications. Use this skill whenever the user is starting a new Flutter desktop
  project, writing or reviewing Dart/Flutter code, setting up project architecture, choosing
  a folder structure, working with Riverpod state management, optimizing rendering or memory
  performance, managing data flow, or asking how to structure any feature in a Flutter desktop
  app. Trigger this skill even for partial tasks like "how should I structure this?", "is this
  the right pattern?", "why is my app slow?", or "set up state for X" if the context is Flutter
  desktop. This skill is focused on code quality, architecture, and performance — for UI/UX
  and visual design, refer to the flutter-desktop-ui skill.
---

# Flutter Desktop Architecture & Performance Skill

This skill guides the creation of **robust, high-efficiency, adaptive** Flutter applications
targeting Windows and macOS. It covers project structure, Riverpod state management, performance
optimization, and code quality standards for production desktop apps.

For UI/UX, theming, animations, and visual design, defer to the **flutter-desktop-ui** skill.

---

## 1. Project Structure

Use a **feature-first** structure as the recommended default. Allow layer-first if the project
is small or the user has a strong preference — but flag the trade-offs.

### Recommended: Feature-First
```
lib/
├── main.dart
├── app/
│   ├── app.dart              # Root widget, theme, routing
│   ├── router.dart           # go_router setup
│   └── providers.dart        # App-level Riverpod overrides
├── core/
│   ├── constants/            # App-wide constants
│   ├── errors/               # Failure types, error handling
│   ├── extensions/           # Dart extension methods
│   └── utils/                # Pure utility functions
├── shared/
│   ├── widgets/              # Reusable UI components
│   └── services/             # Cross-feature services (logger, analytics)
└── features/
    └── [feature_name]/
        ├── data/
        │   ├── models/       # Freezed data classes
        │   ├── repositories/ # Implementations
        │   └── sources/      # Local / remote data sources
        ├── domain/
        │   ├── entities/     # Core business objects
        │   └── repositories/ # Abstract interfaces
        └── presentation/
            ├── screens/      # Full screen widgets
            ├── widgets/      # Feature-specific widgets
            └── providers/    # Riverpod providers for this feature
```

### When to recommend layer-first instead
- Projects with < 5 features and a solo developer
- Proof-of-concept or internal tooling apps
- When the user explicitly prefers it

Always explain the trade-off: feature-first scales better and keeps related code co-located;
layer-first is simpler to navigate initially but creates cross-cutting dependencies as features grow.

---

## 2. Riverpod State Management

Use **Riverpod 3.x** (`flutter_riverpod` + `riverpod_annotation` ^4.x, `riverpod_generator` ^4.x)
with code generation. This is the default for all new projects. Never recommend Provider or GetX
unless the user has an existing codebase in those.

### Core principles
- All state lives in providers — never in `StatefulWidget` unless it's purely local/ephemeral UI state
- Use `@riverpod` annotation with code generation; avoid manual `Provider(...)` declarations
- Separate **UI state** (loading, selected tab, form input) from **domain state** (data, business logic)
- Providers should be small and composable — prefer many focused providers over one large one
- Use `@Riverpod(keepAlive: true)` for providers that must survive their last listener unsubscribing
  (rolling logs, scheduler timers, socket/server lifecycles) — the plain `@riverpod` default is
  auto-dispose

### Provider types — when to use each

| Provider | Use case |
|---|---|
| `@riverpod` (plain) | Synchronous derived values, constants, services |
| `@riverpod` async | Data fetching, file I/O, anything that returns `Future` |
| `@riverpod` stream | Real-time data, file watchers, IPC streams |
| `Notifier` | Mutable state with methods (replaces `StateNotifier` **and** the old `AutoDisposeNotifier`) |
| `AsyncNotifier` | Mutable async state (loading/data/error lifecycle; also replaces `AutoDisposeAsyncNotifier`) |

Riverpod 3.0 removed the separate `AutoDispose*` base classes — `Notifier`/`AsyncNotifier` now
cover both cases, and auto-dispose-related mistakes (e.g. watching a disposed ref) are caught by
lint rules instead of by picking a different base class.

### Standard async data pattern
```dart
// data layer — note the generic `Ref` param, not a generated `XxxRef` subclass
// (Riverpod 3.0 unified all generated Ref types into one `Ref`)
@riverpod
Future<List> projectRepository(Ref ref) async {
  final db = ref.watch(databaseProvider);
  return db.fetchProjects();
}

// presentation layer — Notifier owns mutations
@riverpod
class ProjectListNotifier extends _$ProjectListNotifier {
  @override
  Future<List> build() async {
    return ref.watch(projectRepositoryProvider.future);
  }

  Future addProject(Project project) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);
      await db.insertProject(project);
      return ref.refresh(projectRepositoryProvider.future);
    });
  }
}
```

### Dependency injection with Riverpod
- Use `ref.watch` for reactive dependencies (rebuilds when dep changes)
- Use `ref.read` inside methods/callbacks (one-time reads, no subscription)
- Use `ref.listen` for side effects (navigation, showing snackbars)
- Pass `Ref` down only via providers — never pass it into widgets or constructors
- `ref.mounted` (3.0+) mirrors `BuildContext.mounted` — check it after an `await` inside a
  Notifier method before touching `state`, instead of assuming the provider is still alive

### Error handling pattern
```dart
// In widgets, always handle all three AsyncValue states
ref.watch(projectListProvider).when(
  data: (projects) => ProjectListView(projects: projects),
  loading: () => const SkeletonLoader(),
  error: (e, st) => ErrorView(error: e, onRetry: () => ref.refresh(projectListProvider)),
);
```

**Riverpod 3.0 auto-retries a failing provider by default** (exponential backoff) before it
settles into `AsyncError` — a `FutureProvider`/`AsyncNotifier.build()` that throws doesn't surface
the error to `.when()` on the first failure the way it did in 2.x. This is usually desirable for
transient failures (a flaky network call), but:
- For something like a one-shot local file read where a failure is permanent and retrying just
  delays the error, disable it per-provider (`@Riverpod(retry: (retryCount, error) => null)`) or
  globally on `ProviderContainer`/`ProviderScope`.
- Don't mistake "the error view took a few seconds to appear" for a bug — check whether retry is
  enabled before debugging an async provider that seems slow to report failure.

---

## 3. Data Layer

### Models — use Freezed
Always use `freezed` for data classes. It provides immutability, copyWith, equality, and
pattern matching with zero boilerplate.

Freezed 3.x requires the class to be declared `abstract` — a plain `class Project with _$Project`
(the 2.x style) no longer compiles:

```dart
@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    required DateTime createdAt,
    @Default(ProjectStatus.active) ProjectStatus status,
  }) = _Project;

  factory Project.fromJson(Map json) => _$ProjectFromJson(json);
}
```

### Repository pattern
- Define an **abstract interface** in `domain/repositories/`
- Implement it in `data/repositories/`
- Register the implementation via a Riverpod provider
- This makes testing and swapping implementations trivial

```dart
// domain/repositories/project_repository.dart
abstract class ProjectRepository {
  Future<List> getAll();
  Future save(Project project);
  Future delete(String id);
}

// presentation/providers/project_providers.dart
@riverpod
ProjectRepository projectRepository(ProjectRepositoryRef ref) {
  return SqliteProjectRepository(ref.watch(databaseProvider));
}
```

### Local persistence
- **SQLite via `drift`**: recommended for relational/queryable data
- **Hive or `shared_preferences`**: for simple key-value settings
- **`path_provider`**: always use for resolving file paths (never hardcode paths)
- Never access the filesystem directly from a widget or provider `build()` — use a service

---

## 4. Performance Optimization

Desktop apps can render large datasets and complex layouts. Apply these rules proactively.

### Widget rebuild hygiene
- **Use `const` constructors everywhere possible** — this is the single highest-impact optimization
- Wrap stable subtrees in `const` or extract them into separate `StatelessWidget` classes
- Never rebuild the entire screen for a small state change — scope providers tightly
- Use `select` to subscribe to only the slice of state a widget needs:

```dart
// Instead of watching the full user object and rebuilding on any change:
final userName = ref.watch(userProvider.select((u) => u.name));
```

### List & grid performance
- Always use `ListView.builder` / `GridView.builder` — never `.children` with many items
- For very large lists (1000+ items), use `flutter_list_view` or `super_sliver_list`
- Provide explicit `itemExtent` or `prototypeItem` when item height is fixed — dramatically improves scroll perf
- Cache expensive item computations outside the `itemBuilder`

```dart
ListView.builder(
  itemCount: items.length,
  itemExtent: 56.0, // fixed height = massive perf win
  itemBuilder: (context, i) => ProjectTile(project: items[i]),
)
```

### Isolates for heavy work
Any operation that could block the main thread for > 16ms should be offloaded:
- File parsing (CSV, JSON, XML)
- Image processing
- Search/filtering over large datasets
- Cryptographic operations

```dart
// Use compute() for simple one-shot work
final result = await compute(parseJsonFile, rawBytes);

// Use Isolate.spawn or the isolate package for ongoing work
```

### Image & asset performance
- Use `ResizeImage` to downsample large images to display size before decoding
- Cache network images with `cached_network_image`
- Use `RepaintBoundary` around widgets that animate independently to isolate their repaint

```dart
Image(
  image: ResizeImage(
    FileImage(file),
    width: 200,
    height: 200,
  ),
)
```

### Measuring before optimizing
Before applying optimizations, verify the problem:
1. Run in **profile mode**: `flutter run --profile`
2. Open **Flutter DevTools** → Performance tab
3. Look for janky frames (> 16ms), shader compilation jank, or excessive rebuilds
4. Use the Widget Rebuild tracker to identify hot widgets

---

## 5. Windows & macOS Platform Considerations

### Adaptive behavior (not just UI)
- Detect platform with `Platform.isWindows` / `Platform.isMacOS` (from `dart:io`)
- Use `defaultTargetPlatform` in widget code (works in tests too)
- File path separators, app data directories, and default fonts differ — always use
  `path_provider` and `path` package

### Window management
Use the `window_manager` package for:
- Setting minimum/maximum window size
- Remembering window position/size across sessions
- Custom title bar on Windows (removes default chrome)
- Full-screen and always-on-top modes

```dart
// In main(), before runApp:
await windowManager.ensureInitialized();
WindowOptions windowOptions = const WindowOptions(
  minimumSize: Size(800, 600),
  titleBarStyle: TitleBarStyle.hidden, // custom title bar
);
await windowManager.waitUntilReadyToShow(windowOptions, () async {
  await windowManager.show();
  await windowManager.focus();
});
```

### Keyboard shortcuts
Desktop users expect keyboard shortcuts. Always implement them for primary actions.
- Use `Shortcuts` + `Actions` widgets (Flutter's built-in system)
- Register app-level shortcuts at the root; feature-level shortcuts locally
- Document shortcuts in `Tooltip` messages: `'Save (⌘S / Ctrl+S)'`

### Drag and drop
Use `desktop_drop` package. Handle both file drops and internal widget DnD.
Always provide visual feedback during drag-over state.

### System tray (if needed)
Use `system_tray` package. Keep tray menus short — max 5–7 items.

---

## 6. Error Handling & Resilience

### Result type pattern
Use a `Result<T>` or `Either<Failure, T>` pattern in the data layer. Never let raw exceptions
bubble up to the UI.

```dart
// Using fpdart or a simple custom sealed class
sealed class Result {
  const Result();
}
class Success extends Result {
  const Success(this.value);
  final T value;
}
class Failure extends Result {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}
```

### Global error handling
```dart
// In main()
FlutterError.onError = (details) {
  // log to file/service
  AppLogger.error(details.exception, details.stack);
};
PlatformDispatcher.instance.onError = (error, stack) {
  AppLogger.error(error, stack);
  return true; // handled
};
```

### Logging
Use `logger` package with structured output. Write to a rotating log file on disk (using
`path_provider` + `dart:io`). Never use bare `print()` in production code.

---

## 7. Code Quality Standards

These are non-negotiable defaults. Flag violations in reviews.

- **`const` constructors**: use on every widget and value that qualifies
- **Immutable state**: all state objects must be `@freezed` or otherwise immutable
- **No logic in `build()`**: extract to methods, providers, or services
- **No raw `dynamic`**: use typed models everywhere; `dynamic` is a code smell
- **No magic numbers**: extract to named constants in `core/constants/`
- **Null safety**: never use `!` (force unwrap) without a preceding null check or clear invariant comment
- **Async**: always `await` futures; never fire-and-forget without error handling
- **Dispose**: cancel subscriptions, close streams, dispose controllers in `dispose()` / `ref.onDispose()`

```dart
// In a Notifier or provider:
ref.onDispose(() {
  _subscription?.cancel();
  _controller.close();
});
```

---

## 8. Recommended Package Set

| Purpose | Package |
|---|---|
| State management | `riverpod`, `riverpod_annotation`, `flutter_riverpod` |
| Code generation | `freezed`, `json_serializable`, `riverpod_generator` |
| Navigation | `go_router` |
| Local DB | `drift` (SQLite) |
| Key-value storage | `shared_preferences` |
| File paths | `path_provider`, `path` |
| Window management | `window_manager` |
| Logging | `logger` |
| Functional utils | `fpdart` (optional, for Result/Either) |
| Async utilities | `rxdart` (only if stream composition is complex) |
| File drag-and-drop | `desktop_drop` |
| Large lists | `super_sliver_list` |

Avoid adding packages for things Dart/Flutter's stdlib handles well (HTTP, JSON, basic math).

---

## 9. Pre-Delivery Checklist

Before returning any code, verify:

- [ ] Feature-first folder structure (or documented reason for deviation)
- [ ] Riverpod providers used — no `StatefulWidget` for non-ephemeral state
- [ ] `@freezed` on all data models
- [ ] `const` constructors on all eligible widgets
- [ ] `ListView.builder` (not `.children`) for any list > ~20 items
- [ ] Heavy work offloaded to isolates
- [ ] No raw exceptions bubbling to UI — Result pattern or `AsyncValue` error state
- [ ] `ref.onDispose` cleans up subscriptions and controllers
- [ ] No `print()` — use `logger`
- [ ] `path_provider` used for all file paths (no hardcoded paths)
- [ ] Platform differences (Windows vs macOS) handled where relevant