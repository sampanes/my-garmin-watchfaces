@echo off
REM ============================================================================
REM  start-pet-sandbox.bat
REM  Launch the pet-sandbox Vite dev server in a console TITLED "Pet Sandbox"
REM  so the ports dashboard (and you) can identify it on port 5173 instead of
REM  the generic "Vite dev server" port label.
REM  Idempotent: kills any prior copy of itself first, so re-running never
REM  stacks duplicate dev servers.
REM ============================================================================
setlocal
set "TITLE=Pet Sandbox"
set "PORT=5173"
cd /d "%~dp0"

echo Stopping any prior "%TITLE%" ...
taskkill /FI "WINDOWTITLE eq %TITLE%*" /T /F >nul 2>&1
REM --- port fallback, in case the window title ever got rewritten ---
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do taskkill /PID %%p /F >nul 2>&1

echo Starting "%TITLE%" on http://localhost:%PORT%/ ...
start "%TITLE%" cmd /k npm run dev

echo Done -- look for the "%TITLE%" console window.
endlocal
