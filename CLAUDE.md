# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Rules
- **Language:** Always respond and explain in Spanish, regardless of the language used in the prompt (even if prompted in English for model efficiency).
- **Dialect:** Neutral Spanish only — standard "tú" conjugation (tienes, quieres, puedes, avísame, haz clic). **Never use Rioplatense/Argentine voseo** (vos, tenés, querés, podés, hacé, mirá, andá, fijate, entrá, tocá) — this applies to chat responses, `AskUserQuestion` text, and any UI copy written in code (buttons, labels, confirmations, error messages). Rule of thumb: any imperative ending in a stressed "-á"/"-é" is voseo — the neutral form ends in unstressed "-a"/"-e" instead.

## Project overview

Kolexa is a school communication app (Peru-focused, Spanish-language codebase/comments) connecting parents, teachers, and school staff. It's a monorepo with two independent projects that talk over REST:

- `backend/` — NestJS + Prisma + PostgreSQL (Supabase-hosted) REST API
- `mobile/` — Flutter app (BLoC state management) for parents/teachers/staff

There is no root-level build tooling — always `cd` into `backend/` or `mobile/` before running commands. This repo is not currently under git version control.

## Backend (`backend/`)

### Commands
```bash
npm run start:dev        # dev server with watch mode (nest start --watch)
npm run start:debug       # dev server with debugger attached
npm run build              # nest build -> dist/
npm run start               # run built output (node dist/src/main)

npx prisma generate        # regenerate Prisma client after schema changes
npx prisma migrate dev     # create + apply a migration
npx prisma studio            # visual DB browser
npm run seed                  # ts-node prisma/seed.ts
```
There is no test suite or lint script configured in `package.json` yet.

Server listens on `PORT` (default 3000) with global prefix `/api/v1`. `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, Firebase, and Supabase storage vars are read from `.env` (see `.env.example`).

### Architecture
Standard NestJS module-per-feature layout under `src/modules/<feature>/`: `*.controller.ts` → `*.service.ts` (+ optional `dto/`). `AppModule` (`src/app.module.ts`) wires every feature module and groups them by product phase in comments (Fase 2: attendance/homework/announcements/messages/chat; Fase 3: grades/appointments/pickup/payments; Fase 4: anecdotes/suggestions/coupons) — check this file first to see the full feature surface.

Cross-cutting pieces to know about:
- **Global auth guard**: `JwtAuthGuard` is registered as `APP_GUARD` inside `AuthModule` (not in `AppModule`), so **every route requires a valid JWT by default**. Opt a route out with `@Public()` (`src/common/decorators/public.decorator.ts`). Get the authenticated user via `@CurrentUser()` (`src/common/decorators/current-user.decorator.ts`), which returns a `UserPayload { sub, email, roles, schoolId }` decoded from the JWT — `sub` is the user's `bigint` id.
- **Global exception filter**: `HttpExceptionFilter` (`src/common/filters/http-exception.filter.ts`) normalizes every error response to `{ success, statusCode, message, timestamp, path }`.
- **Global validation**: `ValidationPipe` in `main.ts` runs with `whitelist`, `forbidNonWhitelisted`, and `transform` all `true` — DTOs are strict allowlists, and extra/unknown body fields are rejected with 400.
- **BigInt serialization**: Prisma returns `bigint` for all `BIGINT` PK/FK columns. `main.ts` monkey-patches `BigInt.prototype.toJSON` globally so responses serialize cleanly — don't re-solve this per-endpoint, but do remember to call `.toString()` on bigints you embed in DTOs/response shapes yourself (see `auth.service.ts`).
- **Prisma**: single global `PrismaModule`/`PrismaService` (`src/prisma/`) injected into services. Schema is in `backend/prisma/schema.prisma`. Field names are camelCase in Prisma/TS; the underlying Postgres columns are snake_case via `@map`/`@@map` — when debugging at the SQL level, translate names accordingly. Soft-deletes are common (`deletedAt` columns) — filter these explicitly in queries, Prisma doesn't do it for you.

### Data model shape
Multi-tenant by `School` (a school can have multiple `SchoolLocation`s and `Classroom`s). Access control is `User` → `UserRole` (role + optional school scope) and `User` → `UserClassroom` (role scoped to one classroom, e.g. a teacher). Parents relate to `Student`s via `UserStudent`. Feature modules generally hang off `Student`, `Classroom`, or `School` directly (attendance, homework, grades, anecdotes, announcements, appointments, pickup, payments, chat, suggestions, coupons — one schema section per module, in registration order).

**Note**: ADRs in `docs/v2/` (see below) describe an `Organization`/`Network` entity for multi-campus branding that does **not** yet exist in `schema.prisma` — that's a documented target, not current state. Don't assume it's implemented.

## Mobile (`mobile/`)

### Commands
```bash
flutter pub get           # install dependencies
flutter run                  # run on connected device/emulator/web
flutter analyze              # static analysis (flutter_lints ruleset)
flutter test                  # run tests (only a placeholder widget_test.dart exists today)
```

### Architecture
Feature-first structure under `lib/features/<feature>/`, using `flutter_bloc`. Two levels of layering coexist depending on feature complexity:
- **Fully layered** (e.g. `attendance`, `auth`, `homework`): separate `bloc/` (`*_bloc.dart` + `*_event.dart` + `*_state.dart`), `data/models/`, `data/datasources/`, `data/repositories/`, and `ui/`. The BLoC talks only to the Repository; the Repository coordinates the remote DataSource (and, for `attendance`, an in-memory cache).
- **Single-file features** (e.g. `anecdotes`, `announcements`, `appointments`, `chat`, `coupons`, `grades`, `messages`, `payments`, `pickup`, `suggestions`): model, DataSource, events, states, and BLoC are all defined in one `bloc/<feature>_bloc.dart` file, with just a `ui/` page alongside. When touching one of these, match its existing single-file convention rather than splitting it into the layered structure unless asked to.

Networking: `core/api/api_client.dart` wraps a single `Dio` instance (base URL, timeouts, JSON headers) used by every datasource. `core/api/interceptors/auth_interceptor.dart` injects the `Authorization: Bearer <token>` header on every request from an in-memory token cache (backed by `flutter_secure_storage`), and on a `401` response transparently calls `auth/refresh` and retries the original request once before giving up and clearing tokens.

Navigation: `core/router/app_router.dart` uses `go_router` with a single global `redirect` driven by `AuthBloc` state (via a `Stream`→`ChangeNotifier` adapter, `_GoRouterRefreshStream`) — auth-gated routing logic lives there, not scattered across pages.

`ApiClient._baseUrl` is a hardcoded platform-dependent local dev URL (`10.0.2.2` for Android emulator vs `localhost` for iOS/web) — check this before assuming API calls will reach a real backend.

## Docs (`docs/`)

`docs/v1/` and `docs/v2/` hold ADRs and a UX specification; `v2` is the current version. `kolexa-ux-specification.md` is the primary product spec (branding boundaries in §8.2, brand values in §8.3, positioning in §8.5, etc.), and the ADRs record binding decisions against it:
- **ADR-001**: multi-tenant branding — schools get exactly one swappable accent color (from a pre-approved, accessibility-vetted palette) and one logo slot; no free color picker, no full re-theming.
- **ADR-002**: any branding exception requires joint Design System Architect + PM sign-off and a logged change record; new languages require native-speaker voice/tone review, not just translation.
- **ADR-003**: public copy making specific legal/compliance claims (FERPA, COPPA, Peru's Ley N° 29733, etc.) requires legal review before publication; named competitors are internal-only.

`database/` contains raw SQL dumps (`bk_BeeperSchool_20190303.sql`, `schema_postgresql_v2.sql`) from a prior/legacy system — these are reference material, not the live schema (Prisma's `schema.prisma` is authoritative for the current backend).

## Figma connection (`docs/figma-conexion-guia.md`)

When the user asks to connect to or query Figma designs, follow **`docs/figma-conexion-guia.md`** — it documents the exact working pattern (MCP `figma-console` via WebSocket bridge, and the `figma_execute` + `figma_get_console_logs` combo to read results). Do NOT re-experiment; reuse the base script and only change the `code` inside `figma_execute`. Key facts: file `kolexApp` (fileKey `4CPj5362nic2yoMDS7r7y0`), page `logo`, plugin Desktop Bridge v1.35.0 on port 9223.
