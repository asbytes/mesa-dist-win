@setlocal
@set canspvtools=1
@IF NOT EXIST "%devroot%\spirv-tools\" IF %gitstate% EQU 0 set canspvtools=0
@IF EXIST "%devroot%\spirv-tools\DEPS" IF NOT EXIST "%devroot%\spirv-tools\external\spirv-headers\" IF %gitstate% EQU 0 set canspvtools=0
@if %cmakestate% EQU 0 set canspvtools=0

@set spvtoolsrel=v2022.2
@IF EXIST "%devroot%\spirv-tools\external\" IF %gitstate% GTR 0 (
@echo Updating SPIRV tools source code...
@cd "%devroot%\spirv-tools"
@git checkout master
@git pull -v --progress --recurse-submodules origin
@git checkout %spvtoolsrel%
@echo.
)
@IF EXIST "%devroot%\spirv-tools\DEPS" IF EXIST "%devroot%\spirv-tools\external\spirv-headers\" IF %gitstate% GTR 0 for /f tokens^=2^,4^ delims^=^'^ eol^= %%a IN ('type "%devroot%\spirv-tools\DEPS"') do @IF /I "%%a"=="spirv_headers_revision" IF NOT "%%b"=="" for /f delims^=^ eol^= %%c IN ('type "%devroot%\spirv-tools\external\spirv-headers\.git\HEAD"') do @IF NOT %%b==%%c (
@echo Updating source code of SPIRV headers used by SPIRV tools...
@cd "%devroot%\spirv-tools\external\spirv-headers"
@git checkout master
@git pull -v --progress --recurse-submodules origin
@git checkout %%b
@echo.
)

@IF %canspvtools% EQU 1 set /p buildspvtools=Build SPIRV Tools (y/n):
@IF %canspvtools% EQU 1 echo.
@IF /I NOT "%buildspvtools%"=="y" GOTO skipspvtools

@IF NOT EXIST "%devroot%\spirv-tools\external\" IF %gitstate% GTR 0 (
@echo Getting SPIRV tools source code...
@git clone https://github.com/KhronosGroup/SPIRV-Tools "%devroot%\spirv-tools"
@cd "%devroot%\spirv-tools"
@git checkout %spvtoolsrel%
@echo.
)
@IF EXIST "%devroot%\spirv-tools\DEPS" IF NOT EXIST "%devroot%\spirv-tools\external\spirv-headers\" IF %gitstate% GTR 0 (
@echo Getting source code of SPIRV headers used by SPIRV tools...
@git clone https://github.com/KhronosGroup/SPIRV-Headers "%devroot%\spirv-tools\external\spirv-headers"
@cd "%devroot%\spirv-tools\external\spirv-headers"
@for /f tokens^=2^,4^ delims^=^'^ eol^= %%a IN ('type "%devroot%\spirv-tools\DEPS"') do @IF /I "%%a"=="spirv_headers_revision" IF NOT "%%b"=="" git checkout %%b
@echo.
)

@rem Ask for Ninja use if exists. Load it if opted for it.
@set ninja=n
@if NOT %ninjastate%==0 set /p ninja=Use Ninja build system instead of MsBuild (y/n); less storage device strain, faster and more efficient build:
@if NOT %ninjastate%==0 echo.
@if /I "%ninja%"=="y" if %ninjastate%==1 set PATH=%devroot%\ninja\;%PATH%

@rem Load cmake into build environment.
@if %cmakestate%==1 set PATH=%devroot%\cmake\bin\;%PATH%

@rem Construct build configuration command.
@set buildconf=cmake "%devroot%\spirv-tools" -G
@if /I NOT "%ninja%"=="y" set buildconf=%buildconf% "Visual Studio %toolset%"
@if %abi%==x86 if /I NOT "%ninja%"=="y" set buildconf=%buildconf% -A Win32
@if %abi%==x64 if /I NOT "%ninja%"=="y" set buildconf=%buildconf% -A x64
@if /I NOT "%ninja%"=="y" IF /I %PROCESSOR_ARCHITECTURE%==AMD64 set buildconf=%buildconf% -Thost=x64
@if /I "%ninja%"=="y" set buildconf=%buildconf%Ninja
@set buildconf=%buildconf% -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DCMAKE_INSTALL_PREFIX="%devroot%\spirv-tools\build\%abi%"

@echo SPIRV Tools build configuration command^: %buildconf%
@echo.

@rem Always clean build
@cd "%devroot%\spirv-tools"
@pause
@echo.
@echo Cleanning SPIRV Tools build. Please wait...
@echo.
@if EXIST "build\%abi%\" RD /S /Q build\%abi%
@if EXIST "out\%abi%\" RD /S /Q out\%abi%
@if NOT EXIST "out\" md out
@md out\%abi%
@cd out\%abi%
@pause
@echo.

@rem Load Visual Studio environment. Can only be loaded in the background when using MsBuild.
@if /I "%ninja%"=="y" call %vsenv% %vsabi%
@if /I "%ninja%"=="y" cd "%devroot%\spirv-tools\out\%abi%"
@if /I "%ninja%"=="y" echo.

@rem Configure and execute the build with the configuration made above.
@%buildconf%
@echo.
@pause
@echo.
@if /I NOT "%ninja%"=="y" cmake --build . -j %throttle% --config Release --target install
@if /I "%ninja%"=="y" ninja -j %throttle% install
@echo.

@rem Avoid race condition in LLVM sources checkout.
@pause
@echo.

:skipspvtools
@rem Reset environment after SPIRV Tools build.
@endlocal
@cd "%devroot%"