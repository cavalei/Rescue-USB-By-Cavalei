@echo off
setlocal enabledelayedexpansion
chcp 936 >nul
title 一键复制救急盘
color 0B

set "SRC=%~dp0"
set "SRCDRV=%~d0"

cls
echo.
echo  ==============================================================
echo                     救 急 盘  一 键 复 制
echo  ==============================================================
echo.
echo   把当前盘（%SRCDRV%\）的全部救急工具复制到另一张 U 盘。
echo   个人文件夹 _个人 会被自动跳过，不会复制。
echo.
echo  --------------------------------------------------------------
echo                       免 责 声 明
echo  --------------------------------------------------------------
echo   1. 本盘由 Cavalei 整理分发，仅以本人给出的版本为准。
echo   2. 从其他渠道获得的拷贝无法保证未经改动，请自行判断。
echo   3. 本盘不提供任何担保，不对使用后果承担责任。
echo   4. 分区、格式化、数据恢复、引导修复等操作具有破坏性，
echo      请务必先备份重要数据，并确认目标磁盘正确。
echo   5. 第三方与破解类软件仅建议用于自有设备，商用请自行确认授权。
echo   6. 安全软件可能对部分工具报毒，属预期行为，是否放行请自行判断。
echo.
echo   完整声明见：00_说明\免责声明.txt
echo  --------------------------------------------------------------
echo.
set "AGREE="
set /p AGREE=  已阅读并同意以上内容？输入 Y 继续，其他键退出：
if /i not "%AGREE%"=="Y" (
    echo.
    echo   已取消。
    timeout /t 2 >nul
    exit /b 0
)

:TARGET
cls
echo.
echo   源盘：%SRCDRV%\
echo.
echo   目标盘必须是已经装好 Ventoy 的空 U 盘。
echo   如果还没装，请先关掉本窗口去装，装完再运行。
echo.
set "DL="
set /p DL=  请输入目标盘符（例如 E，不带冒号）：
if "%DL%"=="" goto TARGET
set "DL=%DL::=%"
set "DL=%DL:\=%"

if /i "%DL%"=="%SRCDRV:~0,1%" (
    echo.
    echo   [错误] 目标盘不能是源盘本身。
    pause
    goto TARGET
)
if not exist "%DL%:\" (
    echo.
    echo   [错误] 找不到 %DL%:\，请确认盘符是否正确。
    pause
    goto TARGET
)

set "FREEGB="
for /f "delims=" %%A in ('powershell -NoProfile -Command "[int]((New-Object System.IO.DriveInfo('%DL%:\')).AvailableFreeSpace/1GB)"') do set "FREEGB=%%A"
if defined FREEGB (
    if %FREEGB% LSS 24 (
        echo.
        echo   [警告] 目标盘可用 %FREEGB% GB，而本盘救急工具需要约 24 GB。
        echo          建议换一张至少 32 GB 的盘。
        pause
        goto TARGET
    )
    echo.
    echo   目标盘可用空间：%FREEGB% GB  OK
)

echo.
echo  即将开始复制，目标：%DL%:\
echo  预计耗时 4 - 10 分钟（取决于 USB 速度），期间请不要关闭窗口。
echo.
set "GO="
set /p GO=  确认开始？输入 Y 开始：
if /i not "%GO%"=="Y" goto TARGET

echo.
echo  正在复制...
echo.

for /d %%D in ("%SRC%*") do (
    set "NAME=%%~nxD"
    if /i not "!NAME!"=="System Volume Information" (
        if /i not "!NAME!"=="$RECYCLE.BIN" (
            if /i not "!NAME!"=="autorun.inf" (
                if not "!NAME:~0,1!"=="_" (
                    echo    ^> !NAME!
                    robocopy "%%~fD" "%DL%:\!NAME!" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /MT:8 >nul
                )
            )
        )
    )
)

echo    ^> 根目录文件
xcopy "%SRC%*.*" "%DL%:\" /Y /Q >nul 2>&1

echo.
echo  --------------------------------------------------------------
echo   复制完成。
echo.

if exist "%DL%:\08_便携工具\哈希校验\HashChecker-cli.exe" (
    echo   正在用哈希台账校验复制结果（约 30 秒）...
    echo.
    "%DL%:\08_便携工具\哈希校验\HashChecker-cli.exe" --ledger "%DL%:\00_说明\哈希台账.csv" "%DL%:\"
    echo.
) else (
    echo   [提示] 没找到校验工具，已跳过完整性检查。
    echo.
)

echo  --------------------------------------------------------------
echo   接下来：
echo     1. 拔出这张新盘，插到目标电脑上试启动一次
echo     2. 首次启动可能提示 Verification failed - Security Violation，
echo        需要按流程注册一次密钥（详见 00_说明\救急流程卡.txt）
echo  --------------------------------------------------------------
echo.
pause
exit /b 0
