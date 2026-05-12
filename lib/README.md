# Library Structure

The `lib` folder is split by responsibility:

- `app`: app composition, global providers, and top-level route decisions.
- `core`: shared constants and pure helpers.
- `models`: domain data types.
- `providers`: app state containers.
- `screens`: full page-level UI.
- `services`: IO and business operations.
- `theme`: visual system.
- `widgets`: shared UI components.

Prefer focused files with clear ownership. If a screen grows large, extract
reusable pieces into `widgets` or move pure business logic into `services` or
`core`.
