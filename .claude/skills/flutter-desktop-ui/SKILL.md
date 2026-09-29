---
name: flutter-desktop-ui
description: >
  Apply modern UI/UX guidance for Flutter desktop apps targeting Windows and macOS.
  Use this skill whenever the user asks to build, design, style, or improve any Flutter
  desktop interface — including screens, widgets, layouts, navigation, animations,
  or component design. Trigger this skill even for partial tasks like "make this look
  better", "add a transition", "fix the layout", or "how should I structure this screen"
  if the context is Flutter desktop. Enforces Material Design 3 and Fluent Design
  principles with a unified cross-platform approach, covering visual polish,
  accessibility, adaptive layouts, and animations.
---

# Flutter Desktop UI/UX Skill

This skill guides the creation of polished, modern Flutter desktop applications for
Windows and macOS. It blends **Material Design 3** (MD3) and **Fluent Design** principles
into a unified, cross-platform aesthetic — platform-aware where it matters, consistent
everywhere else.

---

## 1. Design Thinking First

Before writing any Flutter code, answer these:

- **Purpose**: What does this screen/widget do? Who uses it and how often?
- **Density**: Desktop users have more space. Avoid mobile-style large touch targets.
  Use compact, information-rich layouts.
- **Platform feel**: Default to MD3. Add Fluent-inspired surface treatments (acrylic,
  mica-like effects) on Windows where it enhances the native feel.
- **Differentiation**: What makes this screen feel *crafted*, not auto-generated?

---

## 2. Layout & Adaptive Design

### Desktop-First Density
- Use `compact` visual density: `ThemeData(visualDensity: VisualDensity.compact)`
- Minimum clickable area: 32×32dp for desktop (not 48×48dp as on mobile)
- Prefer tight, information-dense UIs over spacious mobile-ported layouts

### Adaptive Layouts
- Use `LayoutBuilder` or `MediaQuery` to adapt at breakpoints:
  - `< 600dp`: single column (rarely needed on desktop, but handle gracefully)
  - `600–1200dp`: two-column, sidebar + content
  - `> 1200dp`: three-column or master-detail
- Use `NavigationRail` for medium widths; `NavigationDrawer` (persistent) for wide
- Avoid `BottomNavigationBar` — it is a mobile pattern

```dart
// Adaptive navigation pattern
Widget build(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return Scaffold(
    body: Row(
      children: [
        if (width >= 600) NavigationRail(...),
        Expanded(child: _currentPage),
      ],
    ),
    bottomNavigationBar: width < 600 ? BottomNavigationBar(...) : null,
  );
}
```

### Sidebar / Navigation
- Persistent `NavigationDrawer` or custom sidebar for primary navigation
- Use `ResizableWidget` or `SplitView` patterns for adjustable panes
- Support keyboard shortcuts for panel toggling

---

## 3. Visual Design & Theming

### Material Design 3 (Primary System)
- Always use `useMaterial3: true` in `ThemeData`
- Derive the full color scheme from a seed: `ColorScheme.fromSeed(seedColor: ...)`
- Respect MD3 surface tones — avoid hardcoded colors; use `Theme.of(context).colorScheme.*`
- Use MD3 elevation via `surfaceTintColor`, not drop shadows alone

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A73E8),
    brightness: Brightness.light,
  ),
  visualDensity: VisualDensity.compact,
)
```

### Fluent Design Influence (Windows Enhancement)
- Apply subtle acrylic/frosted glass effects on sidebars and toolbars using
  `BackdropFilter` with `ImageFilter.blur`
- Depth cues: layered surfaces with slight elevation differences, not heavy shadows
- Subtle reveal/hover effects on interactive elements (animate border or background on hover)

```dart
// Acrylic-style sidebar
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  child: Container(
    color: Colors.white.withOpacity(0.7),
    child: sidebar,
  ),
)
```

### Typography
- Use `TextTheme` from MD3 — `displayLarge`, `headlineMedium`, `bodyMedium`, etc.
- Pair a strong display/heading font with a clean body font via `GoogleFonts`
- Desktop body text: 13–14sp for dense UIs, 15–16sp for reading-heavy content
- Never use raw `fontSize` — always go through the theme

### Color
- Light and dark theme support is mandatory — always define both
- Accent colors should be purposeful: use `primary` for CTAs, `tertiary` sparingly
- Surface hierarchy: `surface` → `surfaceVariant` → `surfaceContainerHighest`
- Avoid pure white/black backgrounds; use MD3 tonal surfaces

---

## 4. Animation & Motion

### Principles
- Motion should feel **responsive** (< 200ms for immediate feedback) and
  **graceful** (150–400ms for layout changes)
- Use **ease curves** not linear: `Curves.easeInOutCubic`, `Curves.fastOutSlowIn`
- Animations should reinforce spatial relationships (where did this panel come from?)

### Key Patterns

**Page/Route Transitions**
```dart
// Shared-axis transition (MD3 recommended for related screens)
PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (_, __, ___) => NextPage(),
  transitionsBuilder: (_, animation, __, child) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic)),
      child: child,
    );
  },
)
```

**Hover & Focus States** (essential for desktop)
```dart
// Always implement hover states on interactive widgets
MouseRegion(
  onEnter: (_) => setState(() => _hovered = true),
  onExit: (_) => setState(() => _hovered = false),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    color: _hovered
        ? Theme.of(context).colorScheme.surfaceVariant
        : Colors.transparent,
    child: child,
  ),
)
```

**List/Content Appearance**
- Use `AnimatedList` for dynamic lists
- Stagger item animations using `Future.delayed` + `AnimationController`
- Fade + slide-up on first load for content panels

**Loading States**
- Prefer `Shimmer`-style skeleton loaders over spinners for content areas
- Use `LinearProgressIndicator` in toolbars/headers for background operations

---

## 5. Component Guidelines

### Buttons
- `FilledButton`: primary CTA only — one per view
- `OutlinedButton`: secondary actions
- `TextButton`: tertiary / destructive-warning actions
- All buttons: add `tooltip` on icon-only buttons

### Forms & Inputs
- Use `TextFormField` with MD3 styling (outlined or filled variant)
- Always show inline validation, not dialog errors
- Group related fields visually with `Card` or surface containers

### Dialogs & Overlays
- Keep dialogs focused: one decision, minimal content
- Use `AlertDialog` for confirmations; custom `Dialog` for complex flows
- Prefer inline editing over dialogs where possible on desktop

### Data Tables
- Use `DataTable2` package or custom `Table` for large datasets
- Support column sorting, row selection, and keyboard navigation
- Show column headers fixed on scroll

### Toolbars & App Bars
- Prefer a compact custom toolbar row over `AppBar` for desktop apps
- Include keyboard shortcut hints in tooltips: `Tooltip(message: 'Save (Ctrl+S)')`

---

## 6. Accessibility

- All interactive widgets must have `Semantics` labels
- Keyboard navigation must work fully — use `FocusTraversalGroup` and `Shortcuts`
- Minimum contrast ratio: 4.5:1 for body text, 3:1 for large text (WCAG AA)
- Support system font scaling via `MediaQuery.textScaleFactor`
- Never disable text scaling

```dart
// Keyboard shortcut support
Shortcuts(
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
        SaveIntent(),
  },
  child: Actions(
    actions: {SaveIntent: CallbackAction(onInvoke: (_) => _save())},
    child: appContent,
  ),
)
```

---

## 7. Code Quality Standards

- Always use `const` constructors where possible
- Extract reusable widgets into their own classes (not inline builders > 20 lines)
- Use `Theme.of(context)` — never hardcode colors, sizes, or fonts
- Keep `build()` methods clean: extract logic into methods or `StatefulWidget`
- Prefer `CustomPainter` for complex custom graphics over stacked containers

---

## 8. Quick Checklist Before Delivering Code

- [ ] `useMaterial3: true` and `ColorScheme.fromSeed` in theme
- [ ] `VisualDensity.compact` set
- [ ] Both light and dark themes defined
- [ ] Hover states on all interactive elements
- [ ] Adaptive layout at 600dp and 1200dp breakpoints
- [ ] No `BottomNavigationBar` (use `NavigationRail` or sidebar)
- [ ] Animations use easing curves and appropriate durations
- [ ] Keyboard shortcuts and `Semantics` labels present
- [ ] No hardcoded colors or font sizes