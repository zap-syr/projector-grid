# Projector Grid

## Project Overview
Projector Grid is a Flutter-based desktop application designed for Windows and macOS. Its primary purpose is to control and manage Panasonic Projectors using the Panasonic LAN protocol. The application features an interactive graphical workspace where users can add, arrange, select (via clicking or marquee dragging), and control projector nodes on a local network.

### Key Technologies
- **Framework:** Flutter (Desktop targeted: Windows, macOS)
- **State Management:** Riverpod (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`)
- **Immutability & Data Classes:** Freezed (`freezed`, `freezed_annotation`)
- **Desktop Window Management:** `window_manager`

### Architecture
The project follows a **Feature-First** directory structure to ensure scalability and separation of concerns.

**Core Directories:**
- `lib/app/`: Contains the main application widget and root setup.
- `lib/core/`: Contains shared resources like themes (`app_theme.dart`), constants, and utilities.
- `lib/features/`: Contains isolated application features.
  - `workspace/`: The central interactive area for managing projectors.
    - `domain/`: Contains data models like `ProjectorNode` (managed via Freezed).
    - `presentation/`: Contains widgets, screens, and state providers (Riverpod Notifiers).
      - `screens/`: e.g., `main_workspace_screen.dart`
      - `widgets/`: e.g., `projector_workspace.dart`, `projector_card.dart`, `toolbar.dart`, `control_bar.dart`
      - `providers/`: e.g., `workspace_provider.dart`

## Building and Running

### Prerequisites
- Flutter SDK (Beta or Master channel recommended for latest desktop features)
- Dart SDK 3.9+
- Target platform build tools (Visual Studio for Windows, Xcode for macOS)

### Code Generation
Because this project relies heavily on `riverpod_generator` and `freezed`, you must run the `build_runner` whenever you modify models or providers:

```bash
# Run once to build generated files
dart run build_runner build -d

# Or run in watch mode to automatically rebuild on file changes
dart run build_runner watch -d
```

### Running the App
To run the application on your current desktop platform:

```bash
# For Windows
flutter run -d windows

# For macOS
flutter run -d macos
```

### Building for Production
```bash
# For Windows
flutter build windows

# For macOS
flutter build macos
```

## Development Conventions

1. **State Management:**
   - All app state is managed using Riverpod.
   - Use `@riverpod` annotations and `build_runner` instead of manual Provider declarations.
   - Separate UI state from Domain state.

2. **Immutability:**
   - All data models (like `ProjectorNode`) must be immutable and created using `@freezed` annotations.
   - Avoid manual `copyWith` or `==` overrides; let Freezed handle them.

3. **Desktop UI/UX Guidelines:**
   - **Compact Density:** UIs are built with `VisualDensity.compact` for a desktop-appropriate feel.
   - **Material Design 3:** The app uses MD3 with `colorScheme` derived from a seed color.
   - **Native Integrations:** Uses `PlatformMenuBar` for native OS top menu bars and `window_manager` for specific window size/position rules.

4. **Code Quality:**
   - Use `const` constructors wherever possible to improve rendering performance.
   - Maintain a clean `build()` method; break down large widgets into smaller, private widget classes.
   - Handle dependencies via Riverpod (`ref.watch`, `ref.read`); avoid passing dependencies through constructors unless strictly necessary for UI components.

5. **Testing:**
   - Write widget tests in the `test/` directory.
   - Run tests using `flutter test`.