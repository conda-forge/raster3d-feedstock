@echo on
setlocal EnableExtensions

set "MSYSTEM=MINGW%ARCH%"
set "MSYS2_PATH_TYPE=inherit"
set "CHERE_INVOKING=1"
set "SHELL=sh.exe"

if not defined CPU_COUNT set "CPU_COUNT=1"
if not defined CC set "CC=gcc"
if not defined FC set "FC=gfortran"

rem Raster3D belongs under Library in a Windows conda package. Convert paths
rem to the form understood by Makefile recipes executed through MSYS2 sh.
for /F "delims=" %%I in ('cygpath.exe -u "%LIBRARY_PREFIX%"') do set "R3D_PREFIX=%%I"
set "CC_CMD=%CC:\=/%"
set "FC_CMD=%FC:\=/%"

cd /D "%SRC_DIR%" || exit /b 1

rem Configure the template before `make linux` copies it to Makefile.incl.
rem Keep the locally generated GNU import libraries first in the search path;
rem conda-forge's libgd/libtiff packages otherwise provide MSVC .lib files.
sed -i.bak ^
  -e "s|^prefix[[:space:]]*=[[:space:]]*/usr/local|prefix = %R3D_PREFIX%|" ^
  -e "s|^INCDIRS[[:space:]]*=.*|INCDIRS = -I%R3D_PREFIX%/include|" ^
  -e "s|^LIBDIRS[[:space:]]*=.*|LIBDIRS = -L. -L%R3D_PREFIX%/lib|" ^
  -e "s|^[[:space:]]*GDEFS[[:space:]]*=.*|GDEFS =|" ^
  Makefile.template || exit /b 1
del /Q Makefile.template.bak

make SHELL=sh.exe linux || exit /b 1

rem Replace the Linux compiler configuration generated above with the active
rem conda MinGW-w64 C/gfortran toolchain.
sed -i.bak ^
  -e "s|^OS = linux$|OS = mingw64|" ^
  -e "s|^CC = gcc$|CC = %CC_CMD%|" ^
  -e "s|^FC = gfortran|FC = %FC_CMD%|" ^
  -e "s|^RM = /bin/rm -f$|RM = rm -f|" ^
  -e "s|^OSDEFS =.*|OSDEFS = -DWIN32|" ^
  Makefile.incl || exit /b 1
del /Q Makefile.incl.bak

rem avs2ps.c includes a Unix-only header and checks WIN32, whereas MinGW-w64
rem defines _WIN32. GNU sed interprets \n in the replacement as newlines.
sed -i.bak ^
  -e "s|^[[:space:]]*#include[[:space:]]*<netinet/in\.h>[[:space:]]*$|#ifndef _WIN32\n#include <netinet/in.h>\n#endif|" ^
  -e "s|^[[:space:]]*#ifdef[[:space:]][[:space:]]*WIN32[[:space:]]*$|#ifdef _WIN32|" ^
  avs2ps.c || exit /b 1
del /Q avs2ps.c.bak

rem Generate MinGW-compatible import libraries from the MSVC-built DLLs.
gendef "%LIBRARY_BIN%\libgd.dll" || exit /b 1
x86_64-w64-mingw32-dlltool ^
  --dllname libgd.dll ^
  --def libgd.def ^
  --output-lib libgd.dll.a || exit /b 1

gendef "%LIBRARY_BIN%\libtiff.dll" || exit /b 1
x86_64-w64-mingw32-dlltool ^
  --dllname libtiff.dll ^
  --def libtiff.def ^
  --output-lib libtiff.dll.a || exit /b 1

make SHELL=sh.exe all -j%CPU_COUNT% || exit /b 1
make SHELL=sh.exe install || exit /b 1

rem Conda activation scripts are not part of upstream's install target.
if not exist "%LIBRARY_PREFIX%\etc\conda\activate.d" mkdir "%LIBRARY_PREFIX%\etc\conda\activate.d"
if not exist "%LIBRARY_PREFIX%\etc\conda\deactivate.d" mkdir "%LIBRARY_PREFIX%\etc\conda\deactivate.d"
copy /Y "%RECIPE_DIR%\activate-raster3d.bat" "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.bat" || exit /b 1
copy /Y "%RECIPE_DIR%\deactivate-raster3d.bat" "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.bat" || exit /b 1
copy /Y "%RECIPE_DIR%\activate-raster3d.sh" "%LIBRARY_PREFIX%\etc\conda\activate.d\raster3d.sh" || exit /b 1
copy /Y "%RECIPE_DIR%\deactivate-raster3d.sh" "%LIBRARY_PREFIX%\etc\conda\deactivate.d\raster3d.sh" || exit /b 1

if not exist "%LIBRARY_BIN%\render.exe" exit /b 1
if not exist "%LIBRARY_BIN%\normal3d.exe" exit /b 1

endlocal
