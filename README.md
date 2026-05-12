# NSBSA Admin System

The official administrative web platform for the National Small Business Support Agency (NSBSA). Built with Flutter Web and powered by Supabase, this system handles stokvel group management, vendor loan tracking, and automated financial reporting.

## Overview

The NSBSA Admin System provides Super Admins and Admins with a centralized dashboard to:
- **Manage Groups & Centers**: Establish reporting hierarchies for community saving groups.
- **Track Loans & Payments**: Full lifecycle management of member loans, interest calculations, and payment tracking.
- **Generate Reports**: Automated PDF generation for individual profiles, ledgers, and group summaries.
- **Audit & Security**: Immutable system logging, role-based access control (RLS), and secure authentication flows.

## Tech Stack

- **Frontend**: Flutter Web (Dart)
- **Backend as a Service (BaaS)**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **State Management**: Provider (`ChangeNotifier`)

## Project Structure

The codebase is organized by feature and architectural layer:
- `/lib/app`: Application entry point, routing, and global providers.
- `/lib/core`: System-wide utilities, constants, theme data, and configuration (`AppConfig`, `AppLogger`).
- `/lib/models`: Data structures reflecting Supabase database tables.
- `/lib/providers`: State management classes handling business logic and local caching.
- `/lib/screens`: Full-page routing views.
- `/lib/services`: External API handlers, Supabase queries, and complex calculations (e.g., `LoanCalculationService`, `SystemAuditService`).
- `/lib/widgets`: Reusable, stateless or tightly scoped stateful UI components.

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>=3.0.0`)
- Supabase Project with initialized database schema

### Installation

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd nsbsa_admin
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Setup**
   Create a `.env` file in the root directory:
   ```env
   SUPABASE_URL=your_project_url
   SUPABASE_ANON_KEY=your_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```
   > **Note:** Never commit the `.env` file. It is explicitly ignored in `.gitignore`.

4. **Run the App**
   ```bash
   flutter run -d chrome
   ```

## Contribution Guidelines

- **Linting**: Ensure your code passes `flutter analyze`. We use strict rules defined in `analysis_options.yaml` (e.g., `prefer_single_quotes`, `avoid_print`, `always_declare_return_types`).
- **Formatting**: Run `dart format lib` before committing.
- **Logging**: Do not use `print()` or `debugPrint()` directly. Use `AppLogger.info()`, `AppLogger.error()`, etc. from `lib/core/logger.dart`.
- **Secrets**: Use `AppConfig` in `lib/core/app_config.dart` to access environment variables.

## Core Workflows

### Authentication & Role Management
Handled by `AuthProvider` and `AccountManagementService`. Super Admins can invite new staff, which triggers a Supabase Auth invitation email containing an exchange token. This token is securely parsed in `main.dart` to establish the new session.

### Audit Logging
Any critical action (loan creation, user block, database import) must log an entry via `SystemAuditService.logAction()`. This writes to an immutable Postgres table for compliance.
