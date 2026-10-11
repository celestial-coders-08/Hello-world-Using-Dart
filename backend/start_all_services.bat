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
echo   [8003] Seller API     -^> backend\seller\main.py
echo   [8004] Payment API    -^> backend\payment\main.py
echo.

REM Resolve backend directory relative to this .bat file
set BACKEND_DIR=%~dp0

if not exist "%BACKEND_DIR%venv\Scripts\python.exe" (
    echo ERROR: Backend virtual environment was not found:
    echo   "%BACKEND_DIR%venv\Scripts\python.exe"
    echo Create the backend environment and install backend\requirements.txt first.
    pause
    exit /b 1
)

if not exist "%BACKEND_DIR%.env" (
    echo WARNING: backend\.env was not found. Razorpay checkout will be unavailable
    echo until RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are configured there.
) else (
    findstr /r /c:"^[ ]*RAZORPAY_KEY_ID[ ]*=" /c:"^[ ]*RAZORPAY_API_KEY[ ]*=" "%BACKEND_DIR%.env" >nul
    if errorlevel 1 echo WARNING: backend\.env has no Razorpay key ID configured.
    findstr /r /c:"^[ ]*RAZORPAY_KEY_SECRET[ ]*=" "%BACKEND_DIR%.env" >nul
    if errorlevel 1 echo WARNING: backend\.env has no Razorpay key secret configured.
)
echo.
echo For a physical Android phone, keep it on the same Wi-Fi as this computer.
echo Flutter uses the LAN IP configured in ApiConfig.deviceIp, or the
echo PAWSTAY_API_HOST Dart define if you need to override it.
echo.

REM ── Service 1: Main API (port 8000) ────────────────────────────────────────
start "PawStay Main API [8000]" cmd /k "cd /d "%BACKEND_DIR%" && call venv\Scripts\activate && python main.py"

REM Short wait so the main service initialises first
timeout /t 2 /nobreak >nul

REM ── Service 2: Message Microservice (port 8001) ────────────────────────────
start "PawStay Message Service [8001]" cmd /k "cd /d "%BACKEND_DIR%messages" && call "%BACKEND_DIR%venv\Scripts\activate" && python main.py"

REM ── Service 3: Service Provider API (port 8002) ────────────────────────────
start "PawStay Provider API [8002]" cmd /k "cd /d "%BACKEND_DIR%service_provider" && call "%BACKEND_DIR%venv\Scripts\activate" && python main.py"

REM ── Service 4: Seller API (port 8003) ─────────────────────────────────────
start "PawStay Seller API [8003]" cmd /k "cd /d "%BACKEND_DIR%seller" && call "%BACKEND_DIR%venv\Scripts\activate" && python main.py"

REM Allow the seller API to finish initializing the shared seller database
timeout /t 2 /nobreak >nul

REM ── Service 5: Payment API (port 8004) ────────────────────────────────────
start "PawStay Payment API [8004]" cmd /k "cd /d "%BACKEND_DIR%" && call venv\Scripts\activate && python -m payment.main"

echo.
echo All 5 services launched in separate windows.
echo   Main API      : http://localhost:8000
echo   Message Service: http://localhost:8001
echo   Provider API  : http://localhost:8002
echo   Seller API    : http://localhost:8003
echo   Payment API   : http://localhost:8004
echo.
echo Close those windows to stop the services.
pause
