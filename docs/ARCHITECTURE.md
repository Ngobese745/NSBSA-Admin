# NSBSA Admin Architecture

This Flutter app is organized by responsibility so developers and AI tools can
work on a focused area without having to understand the whole codebase first.

## Top-Level Map

- `lib/main.dart` starts Flutter, loads environment variables, initializes
  Supabase, and launches the app.
- `lib/app/` contains application composition: provider registration, theming,
  and the authenticated home decision.
- `lib/core/` contains cross-cutting constants and pure helpers such as assets,
  breakpoints, PDF branding, and risk calculations.
- `lib/models/` contains plain data models and serialization logic.
- `lib/providers/` contains `ChangeNotifier` state containers used by screens.
- `lib/screens/` contains user-facing pages and navigation surfaces.
- `lib/services/` contains Supabase, import, cache, communication, calculation,
  and account-management operations.
- `lib/theme/` contains global Material theme definitions.
- `lib/widgets/` contains reusable UI components shared across screens.
- `assets/images/` contains bundled image assets declared once in `pubspec.yaml`.
- `supabase/` and `schema.sql` contain database migration/schema material.

## Import Guidelines

Use the narrowest import that keeps a file understandable:

- Import a direct file when a module depends on one class:
  `import '../models/vendor.dart';`
- Import a barrel when a module intentionally consumes a group:
  `import '../providers/providers.dart';`
- Avoid importing screens from providers or services. Data and business logic
  should not depend on UI.

## AI Editing Boundaries

When asking an AI tool to make changes, assign ownership by folder:

- UI-only changes: one screen in `lib/screens/` or one shared widget in
  `lib/widgets/`.
- State changes: one provider in `lib/providers/` plus the specific screen that
  consumes it.
- Database or IO changes: one service in `lib/services/` plus affected models.
- App startup changes: `lib/main.dart` or `lib/app/`.

This keeps edits isolated and reduces accidental behavior changes.

## Redundancy Rules

- Asset paths belong in `lib/core/app_assets.dart`.
- Provider registration belongs in `lib/app/app_providers.dart`.
- Theme constants belong in `lib/theme/app_theme.dart`.
- Pure calculations belong in `lib/core/` or a dedicated service, not inside
  long screen files.
