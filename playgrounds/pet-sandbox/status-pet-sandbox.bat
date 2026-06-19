@echo off
REM ============================================================================
REM  status-pet-sandbox.bat  --  quick "is it running?" check
REM ============================================================================
setlocal
set "TITLE=Pet Sandbox"
set "PORT=5173"

echo === window-title check ("%TITLE%") ===
tasklist /v /FI "WINDOWTITLE eq %TITLE%*" 2>nul | findstr /I "node cmd" || echo   not running (by title)

echo.
echo === port %PORT% listener check ===
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" || echo   nothing listening on %PORT%
endlocal
