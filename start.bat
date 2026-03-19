@echo off
chcp 65001 >nul
title SimulNote Launcher

echo ============================================
echo   SimulNote - One-Click Launcher
echo ============================================
echo.

:: Check Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found. Please install Python 3.8+.
    pause
    exit /b 1
)

:: Add Flutter to PATH if not already available
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    if exist "E:\flutter\bin\flutter.bat" (
        set "PATH=E:\flutter\bin;%PATH%"
        echo [INFO] Found Flutter at E:\flutter\bin
    ) else (
        echo [ERROR] Flutter not found. Please install Flutter or update this script.
        pause
        exit /b 1
    )
)

:: Install Python dependencies if needed
echo [1/3] Checking Python dependencies...
pip show fastapi uvicorn speechrecognition openai >nul 2>&1
if %errorlevel% neq 0 (
    echo       Installing missing packages...
    pip install fastapi uvicorn speechrecognition openai pydantic -q
)

:: Start backend in a new window
echo [2/3] Starting Python backend...
start "SimulNote Backend" cmd /k "cd /d %~dp0backend && python ai_server.py"

:: Wait a moment for backend to boot
timeout /t 2 /nobreak >nul

:: Start Flutter frontend
echo [3/3] Starting Flutter app...
cd /d %~dp0
flutter pub get
flutter run -d windows

:: When Flutter exits, remind user to close backend
echo.
echo Flutter has exited. You can close the backend window manually.
pause
