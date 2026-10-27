@echo off
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 -X utf8 "%~dp0install.py" %*
) else (
  python -X utf8 "%~dp0install.py" %*
)
pause
