@echo off
chcp 65001 >nul
REM ================================================================
REM PyIsland SideV - Nuitka 打包脚本
REM 说明：打包为多文件目录模式，无黑窗、无弹窗、无 UAC 提示
REM 图标：img/PyislandLogo.ico
REM 产物：./Pyisland_sideV.dist/Pyisland_sideV.exe
REM ================================================================

setlocal

REM --- 基础配置 ---
set "ENTRY_SCRIPT=small_capsule.py"
set "OUTPUT_NAME=Pyisland_sideV"
set "ICON_FILE=img\PyislandLogo.ico"
set "TEMP_ENTRY=%OUTPUT_NAME%.py"

REM --- 图标回退：如果主图标不存在则尝试 img/icon.ico ---
if not exist "%ICON_FILE%" (
    if exist "img\icon.ico" (
        set "ICON_FILE=img\icon.ico"
    ) else (
        echo [警告] 未找到图标文件 %ICON_FILE%，将继续打包但不附带图标
        set "ICON_FILE="
    )
)

if not "%ICON_FILE%"=="" (
    echo [信息] 使用图标：%ICON_FILE%
)

REM --- 检查入口文件 ---
if not exist "%ENTRY_SCRIPT%" (
    echo [错误] 入口文件不存在：%ENTRY_SCRIPT%
    echo 请在项目根目录执行本脚本。
    pause
    exit /b 1
)

REM --- 检查 Nuitka ---
python -m nuitka --version >nul 2>&1
if errorlevel 1 (
    echo [错误] Nuitka 未安装，正在尝试安装...
    pip install nuitka
    if errorlevel 1 (
        echo [错误] 安装 Nuitka 失败，请手动执行：pip install nuitka
        pause
        exit /b 1
    )
)

echo.
echo ================================================================
echo  开始打包：%OUTPUT_NAME%
echo  入口脚本：%ENTRY_SCRIPT%
echo  图标：%ICON_FILE%
echo  模式：多文件目录模式 / 无控制台 / 无 UAC
echo ================================================================
echo.

REM --- 清理旧产物 ---
if exist "%OUTPUT_NAME%.dist" (
    echo [信息] 发现旧打包目录，清理中...
    rmdir /s /q "%OUTPUT_NAME%.dist"
)
if exist "%OUTPUT_NAME%.build" (
    rmdir /s /q "%OUTPUT_NAME%.build"
)

REM --- 生成临时入口文件（以产物名命名，Nuitka 默认以入口文件名生成 exe） ---
echo [信息] 准备临时入口文件...
copy /y "%ENTRY_SCRIPT%" "%TEMP_ENTRY%" >nul
if errorlevel 1 (
    echo [错误] 无法创建临时入口文件。
    pause
    exit /b 1
)

REM --- 构建参数（只用 Nuitka 明确支持的参数） ---
set "NUITKA_ARGS="
set "NUITKA_ARGS=%NUITKA_ARGS% --standalone"
set "NUITKA_ARGS=%NUITKA_ARGS% --enable-plugin=pyside6"
set "NUITKA_ARGS=%NUITKA_ARGS% --windows-console-mode=disable"
set "NUITKA_ARGS=%NUITKA_ARGS% --assume-yes-for-downloads"
set "NUITKA_ARGS=%NUITKA_ARGS% --follow-imports"
set "NUITKA_ARGS=%NUITKA_ARGS% --include-package=capsule_app"
set "NUITKA_ARGS=%NUITKA_ARGS% --include-data-dir=pyisland_sideV\dist=pyisland_sideV\dist"
set "NUITKA_ARGS=%NUITKA_ARGS% --include-data-dir=img=img"
set "NUITKA_ARGS=%NUITKA_ARGS% --include-data-files=widget.html=widget.html"
set "NUITKA_ARGS=%NUITKA_ARGS% --jobs=%NUMBER_OF_PROCESSORS%"
if not "%ICON_FILE%"=="" (
    set "NUITKA_ARGS=%NUITKA_ARGS% --windows-icon-from-ico=%ICON_FILE%"
)

REM --- 执行打包 ---
echo [信息] 正在执行 Nuitka 打包，请耐心等待（首次执行可能耗时较长）...
echo [信息] 命令：python -m nuitka %NUITKA_ARGS% %TEMP_ENTRY%
echo.

python -m nuitka %NUITKA_ARGS% %TEMP_ENTRY%
set BUILD_STATUS=%errorlevel%

REM --- 清理临时入口文件 ---
if exist "%TEMP_ENTRY%" (
    del /q "%TEMP_ENTRY%"
)

if %BUILD_STATUS% neq 0 (
    echo.
    echo [错误] 打包失败，请查看上方日志。
    pause
    exit /b 1
)

echo.
echo ================================================================
echo  打包完成！
echo  可执行文件：.\%OUTPUT_NAME%.dist\%OUTPUT_NAME%.exe
echo  运行时双击 exe 即可，不会出现命令行黑窗。
echo  如需分发，压缩整个 %OUTPUT_NAME%.dist 目录即可。
echo ================================================================
echo.
pause
endlocal