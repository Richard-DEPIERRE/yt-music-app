# Project instructions

## Git / commits
- Never add "edited with Claude", "Generated with Claude Code", or a `Co-Authored-By: Claude` trailer to commit messages or PR bodies.

## Second-brain project notes (keep in sync)
This project is documented in the development-second-brain vault. Keep both up to date as the project evolves:
- **Project note:** `~/Documents/development-second-brain/Dev-second-brain/Projects/yt-music.md` — single source of truth for how the project works (architecture, homelab deployment, API surface, roadmap, known issues). Update it whenever the architecture, deployment, endpoints, roadmap status, or known issues change.
- **Change log:** `~/Documents/development-second-brain/Dev-second-brain/Projects/yt-music-logs/` — one file per session/change, named `YYYY-MM-DD-<topic>.md`. Append a new log entry whenever you make a meaningful change (feature, fix, deploy, verification) so progress is tracked. Frontmatter: `type: project-log`, `project: "[[yt-music]]"`, `date:`.
- Note: this is a *different* project from `Projects/Uichaa Player.md` (the older Navidrome/Subsonic client). Don't conflate them.
