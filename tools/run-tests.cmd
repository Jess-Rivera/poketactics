@echo off
:: Runs the data pack rerun check, then every gdUnit4 test in tests/ headless.
:: Needs Python 3 on the path, and GODOT_BIN set to your Godot 4.6.2 executable, for example:
::   set GODOT_BIN=C:\Users\boric\OneDrive\Desktop\Godot.exe
:: Run from the repo root: tools\run-tests.cmd
if "%GODOT_BIN%"=="" (
    echo Set GODOT_BIN to the Godot executable first.
    exit /b 1
)
python tools\export_pack.py --check
if errorlevel 1 exit /b 1
"%GODOT_BIN%" --headless --path . --import
"%GODOT_BIN%" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
exit /b %ERRORLEVEL%
