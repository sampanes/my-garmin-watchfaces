@echo off
REM ============================================================================
REM  stop-pet-sandbox.bat
REM  Teardown for the pet-sandbox dev server: kill by window title (with /T to
REM  take the node child too), then a port-5173 fallback in case the title
REM  ever changed.
REM ============================================================================
setlocal
set "TITLE=Pet Sandbox"
set "PORT=5173"

echo Stopping "%TITLE%" ...
taskkill /FI "WINDOWTITLE eq %TITLE%*" /T /F >nul 2>&1

for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
  echo   killing leftover PID %%p on port %PORT%
  taskkill /PID %%p /F >nul 2>&1
)

echo Done.
endlocal
