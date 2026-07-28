@echo off
title STT Server
color 0A

echo ============================================================
echo                    Thai Speech-to-Text
echo ============================================================
echo.

REM ตรวจสอบว่ามี Python หรือไม่
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found!
    echo Please install Python from https://www.python.org
    echo.
    pause
    exit /b 1
)

echo [OK] Python found
echo.

if not exist app.py (
    echo [ERROR] app.py not found in current directory!
    echo Please make sure you're in the correct folder.
    echo.
    pause
    exit /b 1
)

echo [OK] Server file found
echo.

REM ติดตั้ง dependencies (ถ้ายังไม่มี)
echo Checking dependencies...
pip show flask >nul 2>&1
if errorlevel 1 (
    echo [INSTALLING] Installing required packages...
    pip install flask flask-cors torch transformers soundfile librosa numpy
    if errorlevel 1 (
        echo [ERROR] Failed to install packages
        pause
        exit /b 1
    )
    echo [OK] Packages installed successfully
    echo.
)

echo ============================================================
echo                   Starting Server
echo ============================================================
echo.
echo Press Ctrl+C to stop the server
echo.

REM รัน server
python app.py

pause
