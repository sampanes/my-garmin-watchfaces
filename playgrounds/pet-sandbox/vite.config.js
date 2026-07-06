// Pin the port the BAT helpers assume. Without strictPort, Vite silently
// auto-increments (5173 -> 5174) when another playground (e.g. ink-sandbox)
// already holds 5173, and status-/stop-pet-sandbox.bat then check the wrong port.
export default {
  server: {
    port: 5173,
    strictPort: true,
  },
};
