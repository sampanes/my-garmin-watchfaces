# Project Conventions

## Playgrounds

Each playground under `playgrounds/` runs its own Vite dev server. To keep
ports identifiable when multiple are running:

1. **`<title>` tag** — set a unique, descriptive `<title>` in `index.html`
   (e.g. `Pet Sandbox`, `Ink Sandbox`). This is the browser tab label.
2. **`name` in `package.json`** — use a kebab-case name matching the directory
   (e.g. `pet-sandbox`, `ink-sandbox`).
3. **`--host` flag** — always include `--host` in the `dev` script so the
   server is reachable on LAN / Tailscale without manual flags.
