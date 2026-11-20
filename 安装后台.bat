@echo off
chcp 65001 >nul
cd /d "%~dp0"
title 安装 trit-mc 后台守护（开机自启，按 F8 接管）

echo.
echo   安装后台守护
echo   -----------
echo   装完之后：开机自动启动，全程在后台，不弹黑窗口。
echo   进游戏后直接按 F8 接管，再按 F8 交还。
echo.
echo   装到: %LOCALAPPDATA%\trit-mc
echo.

if not exist target\release\trit-mc-daemon.exe (
    echo   [错误] 没找到 target\release\trit-mc-daemon.exe
    echo          先在本目录跑一次: cargo build --release
    echo.
    pause
    exit /b 1
)

target\release\trit-mc-daemon.exe --install
if errorlevel 1 (
    echo.
    echo   [失败] 安装没成功，看日志: %LOCALAPPDATA%\trit-mc\trit-mc-daemon.log
    echo.
    pause
    exit /b 1
)

echo.
echo   装好了。
echo.
echo   现在就能用：进游戏 -&gt; 按 F8 接管。
echo   查看状态:  target\release\trit-mc.exe status
echo   停掉它:    target\release\trit-mc.exe stop
echo   卸载自启:  双击 卸载后台.bat
echo.
pause
