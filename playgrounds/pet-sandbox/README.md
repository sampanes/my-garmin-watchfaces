# Pet Sandbox

Mobile-first browser playground for the Garmin pet look-and-feel work.

## Dev server identity

The dev server should be identifiable when multiple Vite playgrounds are running.

- Browser title: `Pet Sandbox`
- Package name: `pet-sandbox`
- Dev script: `vite --host`
- Console/window title used by helper scripts: `Pet Sandbox`

The BAT helpers intentionally use the same name so a local port/process dashboard does not
show a generic Vite listener when this sandbox is running.

## Helpers

- `start-pet-sandbox.bat` - starts the Vite server in a console titled `Pet Sandbox`.
- `status-pet-sandbox.bat` - checks the titled window and the port listener.
- `stop-pet-sandbox.bat` - stops the titled window, then falls back to killing the port
  listener if the title changed.

The scripts default to port `5173`, matching Vite's first-choice dev port.
