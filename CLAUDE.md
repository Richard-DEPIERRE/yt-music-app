# Project instructions

## Logging (Flutter app)
The app uses a single logger, `AppLog` (`app/lib/core/logging/app_log.dart`).
**Do not use bare `debugPrint`/`print`** — always go through `AppLog` so every
line is timestamped, levelled and tagged (and is a no-op in release builds).

- API: `AppLog.d/i/w/e('Tag', 'message', [error], [stackTrace])`.
- Output format: `[HH:mm:ss.SSS][LEVEL][Tag] message` (shows as `flutter: ...`
  in the run console; also mirrored to DevTools via `dart:developer`).
- Levels: `d` = verbose tracing, `i` = lifecycle/notable events, `w` =
  recoverable problem, `e` = failure (**always pass the error object** so its
  `toString()` is captured — for API errors this includes the backend body).
- Tags are short subsystem names. Established tags: `App`, `Flutter`, `API`,
  `Sync`, `BgSync`, `Downloads`, `Library`, `Health`, `LikedSongs`. Add a new
  one (a screen or subsystem name) rather than overloading an existing tag.

**Add logs liberally, especially in the frontend** — every new feature/screen
should log: when it opens, when it kicks off a network/refresh action, the
outcome (counts/ids), and any caught error (with the error object + stack).
The goal is that a `flutter run` console alone explains what the app did.

- All HTTP traffic is logged automatically by the `API` interceptor in
  `ApiClient` (request line, response status, and the **response body on
  error**). Don't add manual per-request logging in the API client.
- `ApiException` carries the parsed response `body`; its `toString()` includes
  it, so logging a caught `ApiException` shows the backend's `detail` (e.g. the
  real upstream cause behind a 502). Build API errors via
  `ApiException.fromDio(e)`, never the bare constructor in network catch blocks.
- Verbosity knobs (debug-build only): `AppLog.minLevel` raises the floor;
  `AppLog.logNetworkBodies = false` silences request/response body logging.

When a backend call returns 502/5xx, the real cause is in two places: the
`API`-tagged `↳ response body:` line in the app console, **and** the backend's
`logger.exception(...)` traceback in `docker compose logs` on the homelab host.

## Git / commits
- Never add "edited with Claude", "Generated with Claude Code", or a `Co-Authored-By: Claude` trailer to commit messages or PR bodies.

## Second-brain project notes (keep in sync)
This project is documented in the development-second-brain vault. Keep both up to date as the project evolves:
- **Project note:** `~/Documents/development-second-brain/Dev-second-brain/Projects/yt-music.md` — single source of truth for how the project works (architecture, homelab deployment, API surface, roadmap, known issues). Update it whenever the architecture, deployment, endpoints, roadmap status, or known issues change.
- **Change log:** `~/Documents/development-second-brain/Dev-second-brain/Projects/yt-music-logs/` — one file per session/change, named `YYYY-MM-DD-<topic>.md`. Append a new log entry whenever you make a meaningful change (feature, fix, deploy, verification) so progress is tracked. Frontmatter: `type: project-log`, `project: "[[yt-music]]"`, `date:`.
- Note: this is a *different* project from `Projects/Uichaa Player.md` (the older Navidrome/Subsonic client). Don't conflate them.
