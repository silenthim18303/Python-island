@echo off
title Python Dynamic Island
echo Starting Python Dynamic Island...
python dynamic_island.py
if %errorlevel% neq 0 (
    echo.
    echo Error: Failed to start the application. 
    echo Please make sure dependencies are installed: pip install -r requirements.txt
    pause
)
