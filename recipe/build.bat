@echo on
setlocal EnableExtensions

set "MSYSTEM=MINGW%ARCH%"
set "MSYS2_PATH_TYPE=inherit"
set "CHERE_INVOKING=1"
set "SHELL=sh.exe"

if not defined CPU_COUNT set "CPU_COUNT=1"
if not defined CC set "CC=gcc"
if not defined FC set "FC=gfortran"

@REM Raster3D belongs under Library in a Windows conda package. Convert paths
@REM separately for MSYS2 install commands and native MinGW compiler flags.
for /F "delims=" %%I in ('cygpath.exe -u "%LIBRARY_PREFIX%"') do set "R3D_PREFIX=%%I"
for /F "delims=" %%I in ('cygpath.exe -m "%LIBRARY_PREFIX%"') do set "R3D_NATIVE_PREFIX=%%I"
set "CC_CMD=%CC:\=/%"
set "FC_CMD=%FC:\=/%"

cd /D "%SRC_DIR%" || exit /b 1

@REM Fail early if a host package was installed without its development files.
if not exist "%LIBRARY_PREFIX%\include\tiff.h" exit /b 1
if not exist "%LIBRARY_PREFIX%\include\tiffio.h" exit /b 1
if not exist "%LIBRARY_PREFIX%\include\gd.h" exit /b 1

@REM Configure the template before `make linux` copies it to Makefile.incl.
@REM MinGW ld can consume conda-forge's COFF .lib import libraries directly.
sed -i.bak ^
  -e "s|^prefix[[:space:]]*=[[:space:]]*/usr/local|prefix = %R3D_PREFIX%|" ^
  -e "s|^INCDIRS[[:space:]]*=.*|INCDIRS = -I%R3D_NATIVE_PREFIX%/include|" ^
  -e "s|^LIBDIRS[[:space:]]*=.*|LIBDIRS = -L%R3D_NATIVE_PREFIX%/lib|" ^
  -e "s|^[[:space:]]*GDEFS[[:space:]]*=.*|GDEFS =|" ^
  Makefile.template || exit /b 1
del /Q Makefile.template.bak

make SHELL=sh.exe linux || exit /b 1

@REM Replace the Linux compiler configuration generated above with the active
@REM conda MinGW-w64 C/gfortran toolchain.
sed -i.bak ^
  -e "s|^OS = linux$|OS = mingw64|" ^
  -e "s|^CC = gcc$|CC = %CC_CMD%|" ^
  -e "s|^FC = gfortran|FC = %FC_CMD%|" ^
  -e "s|^RM = /bin/rm -f$|RM = rm -f|" ^
  -e "s|^OSDEFS =.*|OSDEFS = -DWIN32|" ^
  Makefile.incl || exit /b 1
del /Q Makefile.incl.bak

@REM avs2ps.c includes a Unix-only header and checks WIN32, whereas MinGW-w64
@REM defines _WIN32. GNU sed interprets \n in the replacement as newlines.
sed -i.bak ^
  -e "s|^[[:space:]]*#include[[:space:]]*<netinet/in\.h>[[:space:]]*$|#ifndef _WIN32\n#include <netinet/in.h>\n#endif|" ^
  -e "s|^[[:space:]]*#ifdef[[:space:]][[:space:]]*WIN32[[:space:]]*$|#ifdef _WIN32|" ^
  avs2ps.c || exit /b 1
del /Q avs2ps.c.bak

make SHELL=sh.exe all -j%CPU_COUNT% || exit /b 1
make SHELL=sh.exe install || exit /b 1

@REM Conda activation scripts are not part of upstream's install target.
if not exist "%LIBRARY_PREFIX%\etc\conda\activate.d" mkdir "%LIBRARY_PREFIX%\etc\conda\activate.d"
if not exist "%LIBRARY_PREFIX%\etc\conda\deactivate.d" mkdir "%LIBRARY_PREFIX%\etc\conda\deactivate.d"

> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.bat" echo @set "RASTER3D_CONDA_R3D_LIB_WAS_SET="
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.bat" echo @if defined R3D_LIB set "RASTER3D_CONDA_R3D_LIB_WAS_SET=1"
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.bat" echo @set "RASTER3D_CONDA_BACKUP_R3D_LIB=%%R3D_LIB%%"
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.bat" echo @set "R3D_LIB=%%CONDA_PREFIX%%\Library\share\Raster3D\materials"

> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo @if defined RASTER3D_CONDA_R3D_LIB_WAS_SET ^(
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo   @set "R3D_LIB=%%RASTER3D_CONDA_BACKUP_R3D_LIB%%"
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo ^) else ^(
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo   @set "R3D_LIB="
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo ^)
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo @set "RASTER3D_CONDA_BACKUP_R3D_LIB="
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" echo @set "RASTER3D_CONDA_R3D_LIB_WAS_SET="

> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo if [[ ${R3D_LIB+x} ]]; then
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo     export RASTER3D_CONDA_R3D_LIB_WAS_SET=1
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo else
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo     unset RASTER3D_CONDA_R3D_LIB_WAS_SET
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo fi
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo export RASTER3D_CONDA_BACKUP_R3D_LIB="${R3D_LIB-}"
>> "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" echo export R3D_LIB="${CONDA_PREFIX}/Library/share/Raster3D/materials"

> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo if [[ ${RASTER3D_CONDA_R3D_LIB_WAS_SET+x} ]]; then
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo     export R3D_LIB="${RASTER3D_CONDA_BACKUP_R3D_LIB}"
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo else
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo     unset R3D_LIB
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo fi
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo unset RASTER3D_CONDA_BACKUP_R3D_LIB
>> "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" echo unset RASTER3D_CONDA_R3D_LIB_WAS_SET

if not exist "%LIBRARY_BIN%\render.exe" exit /b 1
if not exist "%LIBRARY_BIN%\normal3d.exe" exit /b 1

endlocal
