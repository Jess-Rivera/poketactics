@echo off
:: Runs every gdUnit4 test in tests/ headless. Set GODOT_BIN to your Godot 4.6.2 executable first, for example:
::   set GODOT_BIN=C:\Users\boric\OneDrive\Desktop\Godot.exe
:: Run from the repo root: tools\run-tests.cmd
if "%GODOT_BIN%"=="" (
    echo Set GODOT_BIN to the Godot executable first.
    exit /b 1
)
"%GODOT_BIN%" --headless --path . --import
"%GODOT_BIN%" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
exit /b %ERRORLEVEL%
