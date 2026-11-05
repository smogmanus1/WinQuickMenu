@echo off
rem Builds WinQuickMenu.exe from WinQuickMenu.ahk using the Ahk2Exe compiler
rem that comes with AutoHotkey v2. Double-click to run.

setlocal
cd /d "%~dp0"

set "AHKDIR=%ProgramFiles%\AutoHotkey"
if not exist "%AHKDIR%\Compiler\Ahk2Exe.exe" set "AHKDIR=%LocalAppData%\Programs\AutoHotkey"

set "COMPILER=%AHKDIR%\Compiler\Ahk2Exe.exe"
set "BASE=%AHKDIR%\v2\AutoHotkey64.exe"

if not exist "%COMPILER%" (
    echo Ahk2Exe not found. Install AutoHotkey v2 from https://www.autohotkey.com/
    echo If AutoHotkey is installed, open its Dash and choose "Compile" to install the compiler.
    pause
    exit /b 1
)
if not exist "%BASE%" (
    echo AutoHotkey v2 base file not found at "%BASE%"
    pause
    exit /b 1
)

echo Building WinQuickMenu.exe ...
"%COMPILER%" /in "WinQuickMenu.ahk" /out "WinQuickMenu.exe" /base "%BASE%"

if exist "WinQuickMenu.exe" (
    echo Done: %~dp0WinQuickMenu.exe
) else (
    echo Build failed.
)
pause
