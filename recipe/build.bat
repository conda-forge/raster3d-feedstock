@echo on
setlocal EnableExtensions

set "MSYSTEM=MINGW64"
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
sed -i ^
  -e "s|^prefix[[:space:]]*=[[:space:]]*/usr/local|prefix = %R3D_PREFIX%|" ^
  -e "s|^INCDIRS[[:space:]]*=.*|INCDIRS = -I%R3D_NATIVE_PREFIX%/include|" ^
  -e "s|^LIBDIRS[[:space:]]*=.*|LIBDIRS = -L%R3D_NATIVE_PREFIX%/lib|" ^
  -e "s|^[[:space:]]*GDEFS[[:space:]]*=.*|GDEFS =|" ^
  Makefile.template || exit /b 1

make SHELL=sh.exe linux || exit /b 1

@REM Replace the Linux compiler configuration generated above with the active
@REM conda MinGW-w64 C/gfortran toolchain.
sed -i ^
  -e "s|^OS = linux$|OS = mingw64|" ^
  -e "s|^CC = gcc$|CC = %CC_CMD%|" ^
  -e "s|^FC = gfortran|FC = %FC_CMD%|" ^
  -e "s|^RM = /bin/rm -f$|RM = rm -f|" ^
  -e "s|^OSDEFS =.*|OSDEFS = -DWIN32|" ^
  Makefile.incl || exit /b 1

@REM avs2ps.c includes a Unix-only header and checks WIN32, whereas MinGW-w64
@REM defines _WIN32. GNU sed interprets \n in the replacement as newlines.
sed -i ^
  -e "s|^[[:space:]]*#include[[:space:]]*<netinet/in\.h>[[:space:]]*$|#ifndef _WIN32\n#include <netinet/in.h>\n#endif|" ^
  -e "s|^[[:space:]]*#ifdef[[:space:]][[:space:]]*WIN32[[:space:]]*$|#ifdef _WIN32|" ^
  avs2ps.c || exit /b 1

make SHELL=sh.exe all -j%CPU_COUNT% || exit /b 1
make SHELL=sh.exe install || exit /b 1

endlocal
