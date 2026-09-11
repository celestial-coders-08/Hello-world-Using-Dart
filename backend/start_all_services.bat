@echo off
title PawStay Backend Launcher
echo ============================================================
echo   PawStay Backend Services Launcher
echo ============================================================
echo.
echo Starting all backend services...
echo   [8000] Main API       -^> backend\main.py
echo   [8001] Message Service -^> backend\messages\main.py
echo   [8002] Provider API   -^> backend\service_provider\main.py
echo.

REM Resolve backend directory relative to this .bat file
set BACKEND_DIR=%~dp0

REM ── Service 1: Main API (port 8000) ────────────────────────────────────────
start "PawStay Main API [8000]" cmd /k "cd /d "%BACKEND_DIR%" && call venv\Scripts\activate && python main.py"

REM Short wait so the main service initialises first
timeout /t 2 /nobreak >nul

REM ── Service 2: Message Microservice (port 8001) ────────────────────────────
start "PawStay Message Service [8001]" cmd /k "cd /d "%BACKEND_DIR%messages" && call "%BACKEND_DIR%venv\Scripts\activate" && python main.py"

REM ── Service 3: Service Provider API (port 8002) ────────────────────────────
start "PawStay Provider API [8002]" cmd /k "cd /d "%BACKEND_DIR%service_provider" && call "%BACKEND_DIR%venv\Scripts\activate" && python main.py"

echo.
echo All 3 services launched in separate windows.
echo   Main API      : http://localhost:8000
echo   Message Service: http://localhost:8001
echo   Provider API  : http://localhost:8002
echo.
echo Close those windows to stop the services.
pause
