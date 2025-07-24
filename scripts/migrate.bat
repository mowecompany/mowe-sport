@echo off
REM =====================================================
REM MOWE SPORT - DATABASE MIGRATION SCRIPT (Windows)
REM =====================================================

setlocal enabledelayedexpansion

REM Load environment variables from .env file
if exist ".env" (
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
        if not "%%a"=="" if not "%%a:~0,1%"=="#" (
            set "%%a=%%b"
        )
    )
)

REM Default values if not set in .env
if not defined DATABASE_URL set DATABASE_URL=postgresql://postgres.xxxxxxxxxxxxxxxx:xxxxxxxxxxxxxxxx@aws-0-us-west-1.pooler.supabase.com:5432/postgres?sslmode=require
set MIGRATIONS_PATH=file://migrations
set COMMAND=%1
set STEPS=%2

REM Check if command is provided
if "%COMMAND%"=="" (
    echo Usage: migrate.bat [command] [steps]
    echo Commands:
    echo   up [steps]     - Apply migrations
    echo   down [steps]   - Rollback migrations
    echo   version        - Show current version
    echo   force [version] - Force version
    echo   status         - Show migration status
    echo.
    echo Examples:
    echo   migrate.bat up           - Apply all pending migrations
    echo   migrate.bat up 1         - Apply next 1 migration
    echo   migrate.bat down 1       - Rollback last 1 migration
    echo   migrate.bat version      - Show current version
    echo   migrate.bat status       - Show detailed status
    exit /b 1
)

REM Build the migrate tool if it doesn't exist
if not exist "bin\migrate.exe" (
    echo Building migration tool...
    go build -o bin\migrate.exe cmd\migrate\main.go
    if errorlevel 1 (
        echo Failed to build migration tool
        exit /b 1
    )
)

REM Handle different commands
if "%COMMAND%"=="status" (
    echo =====================================================
    echo MIGRATION STATUS
    echo =====================================================
    bin\migrate.exe -database-url="%DATABASE_URL%" -migrations-path="%MIGRATIONS_PATH%" -command=version
    echo.
    echo Available migrations:
    dir /b migrations\*.up.sql
    echo =====================================================
    exit /b 0
)

REM Execute migration command
if "%STEPS%"=="" (
    bin\migrate.exe -database-url="%DATABASE_URL%" -migrations-path="%MIGRATIONS_PATH%" -command=%COMMAND%
) else (
    if "%COMMAND%"=="force" (
        bin\migrate.exe -database-url="%DATABASE_URL%" -migrations-path="%MIGRATIONS_PATH%" -command=%COMMAND% -version=%STEPS%
    ) else (
        bin\migrate.exe -database-url="%DATABASE_URL%" -migrations-path="%MIGRATIONS_PATH%" -command=%COMMAND% -steps=%STEPS%
    )
)

if errorlevel 1 (
    echo Migration failed!
    exit /b 1
)

echo Migration completed successfully!