@echo off

set CC="%TCC_DIR%\tcc.exe"
set V=1

set R=%~dp0%
set DIST=%R%dist52f
set LUAVER=52f

if 53 == %LUAVER% (
set DIST_BIN=%DIST%\bin
set DIST_INC=%DIST%\include
set DIST_LIB=%DIST%\bin
set DIST_SHARE=%DIST%\share
set DIST_LUA_LIB=%DIST%\lib\lua\5.3
set DIST_LUA_SHARE=%DIST%\share\lua\5.3
) else (
set DIST_BIN=%DIST%
set DIST_INC=%DIST%\include
set DIST_LIB=%DIST%
set DIST_SHARE=%DIST%
set DIST_LUA_LIB=%DIST%
set DIST_LUA_SHARE=%DIST%\lua
)

if 53 == %LUAVER% (
mkdir %DIST_BIN% %DIST_INC% %DIST_LUA_LIB% %DIST_LUA_SHARE% >nul 2>&1
) else (
mkdir %DIST_BIN% %DIST_INC% %DIST_LUA_SHARE% >nul 2>&1
)

set ROOT_SRC=%R%src
set LUALIBVER=lua%LUAVER%

if . == %1. (
    call :make
) else (
    call :%1
)
cd /d %R%
if not defined FAIL echo all done
pause
goto :eof

:make
rem build_libzip build_lua_zip
set BUILD=^
build_lua_%LUAVER% build_zlib build_zziplib build_libpng build_libgd ^
build_luafilesystem build_lua_zlib build_luazip build_lua_gd build_md5 ^
build_luasocket ^
build_serpent build_binaryheap build_timerwheel build_copas build_xavante build_json

for %%i in (%BUILD%) do (
    if defined FAIL goto :break
    echo build %%i...
    call :%%i
)
goto :eof


:build_lua_53
cd /d %ROOT_SRC%\lua-5.3.5

rem core
set SRC=lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c
rem lib
set SRC=%SRC% lauxlib.c lbaselib.c lbitlib.c lcorolib.c ldblib.c liolib.c lmathlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c loadlib.c linit.c
set H=lua.h luaconf.h lualib.h lauxlib.h lua.hpp
set CFLAGS=-DLUA_BUILD_AS_DLL
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER%

call :cmd %CC% -shared -s -o %DIST_BIN%\lua53.dll %CFLAGS% %SRC%
del /q /f %DIST_BIN%\lua53.def >nul 2>&1
call :cmd %CC% -s -o %DIST_BIN%\lua53.exe %CFLAGS% lua.c %LDFLAGS%
call :install . %DIST_INC% %H%

goto :eof


:build_lua_52f
cd /d %ROOT_SRC%\lua-5.2.1.f

rem core
set SRC=lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c
rem lib
set SRC=%SRC% lauxlib.c lbaselib.c lbitlib.c lcorolib.c ldblib.c liolib.c lmathlib.c loslib.c lstrlib.c ltablib.c loadlib.c linit.c
rem lutf8lib.c
set H=lua.h luaconf.h lualib.h lauxlib.h lua.hpp
set CFLAGS=-DLUA_BUILD_AS_DLL -DLUA_COMPAT_ALL -DUSE_LUA_OS -DUSE_LUA_IO -DUSE_LUA_PACKAGE -DUSE_LUA_COROUTINE -DUSE_LUA_LOADFILE -DUSE_LUA_DOFILE
set LDFLAGS=-L%DIST_LIB% -llua%LUAVER%

call :cmd %CC% -shared -s -o %DIST_BIN%\lua52f.dll %CFLAGS% %SRC%
del /q /f %DIST_BIN%\lua52f.def >nul 2>&1
call :cmd %CC% -s -o %DIST_BIN%\lua52f.exe %CFLAGS% lua.c %LDFLAGS%
call :install . %DIST_INC% %H%

goto :eof


:build_zlib
cd /d %ROOT_SRC%\zlib

set SRC=adler32.c compress.c crc32.c deflate.c gzclose.c gzlib.c gzread.c gzwrite.c infback.c inffast.c inflate.c inftrees.c trees.c uncompr.c zutil.c
set H=zlib.h zconf.h
set CFLAGS=-DZLIB_DLL

call :cmd %CC% -shared -o %DIST_BIN%\zlib1.dll %CFLAGS% %SRC%
del /q /f %DIST_BIN%\zlib1.def >nul 2>&1
call :install . %DIST_INC% %H%


goto :eof


:build_libzip
cd /d %ROOT_SRC%\libzip

rem !!! zip_source_filep.c
rem !!! need comment create_temp_output() which use _zip_mkstempm() (no in Win build)

set SRC=zip_add.c zip_add_dir.c zip_add_entry.c zip_algorithm_deflate.c zip_buffer.c zip_close.c zip_delete.c zip_dir_add.c zip_dirent.c zip_discard.c zip_entry.c zip_err_str.c zip_error.c zip_error_clear.c zip_error_get.c zip_error_get_sys_type.c zip_error_strerror.c zip_error_to_str.c zip_extra_field.c zip_extra_field_api.c zip_fclose.c zip_fdopen.c zip_file_add.c zip_file_error_clear.c zip_file_error_get.c zip_file_get_comment.c zip_file_get_external_attributes.c zip_file_get_offset.c zip_file_rename.c zip_file_replace.c zip_file_set_comment.c zip_file_set_encryption.c zip_file_set_external_attributes.c zip_file_set_mtime.c zip_file_strerror.c zip_filerange_crc.c zip_fopen.c zip_fopen_encrypted.c zip_fopen_index.c zip_fopen_index_encrypted.c zip_fread.c zip_fseek.c zip_ftell.c zip_get_archive_comment.c zip_get_archive_flag.c zip_get_encryption_implementation.c zip_get_file_comment.c zip_get_name.c zip_get_num_entries.c zip_get_num_files.c zip_hash.c zip_io_util.c zip_libzip_version.c zip_memdup.c zip_name_locate.c zip_new.c zip_open.c zip_progress.c zip_rename.c zip_replace.c zip_set_archive_comment.c zip_set_archive_flag.c zip_set_default_password.c zip_set_file_comment.c zip_set_file_compression.c zip_set_name.c zip_source_accept_empty.c zip_source_begin_write.c zip_source_begin_write_cloning.c zip_source_buffer.c zip_source_call.c zip_source_close.c zip_source_commit_write.c zip_source_compress.c zip_source_crc.c zip_source_error.c zip_source_filep.c zip_source_free.c zip_source_function.c zip_source_get_compression_flags.c zip_source_is_deleted.c zip_source_layered.c zip_source_open.c zip_source_pkware.c zip_source_read.c zip_source_remove.c zip_source_rollback_write.c zip_source_seek.c zip_source_seek_write.c zip_source_stat.c zip_source_supports.c zip_source_tell.c zip_source_tell_write.c zip_source_window.c zip_source_write.c zip_source_zip.c zip_source_zip_new.c zip_stat.c zip_stat_index.c zip_stat_init.c zip_strerror.c zip_string.c zip_unchange.c zip_unchange_all.c zip_unchange_archive.c zip_unchange_data.c zip_utf-8.c
rem windows
set SRC=%SRC% zip_source_win32handle.c zip_source_win32utf8.c zip_source_win32w.c zip_source_win32a.c

set CFLAGS=-DHAVE_CONFIG_H -I%DIST_INC% -I.
set LDFLAGS=-ladvapi32 -L%DIST_LIB% -lzlib1

call :cmd %CC% -shared -o %DIST_BIN%\libzip.dll %CFLAGS% %SRC% %LDFLAGS%
del /q /f %DIST_BIN%\libzip.def >nul 2>&1
call :install . %DIST_INC% zip.h zipconf.h

goto :eof


:build_zziplib
cd /d %ROOT_SRC%\zziplib

set SRC=dir.c err.c fetch.c file.c info.c plugin.c stat.c write.c zip.c

set CFLAGS=-DZZIP_EXPORTS -D_zzip_export=__declspec(dllexport) -I. -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -lzlib1

call :cmd %CC% -shared -o %DIST_BIN%\libzzip.dll %CFLAGS% %SRC% %LDFLAGS%
del /q /f %DIST_BIN%\libzzip.def >nul 2>&1
call :install zzip %DIST_INC%\zzip zzip.h types.h conf.h _config.h


goto :eof


:build_libpng
cd /d %ROOT_SRC%\libpng

set SRC=png.c pngerror.c pngget.c pngmem.c pngpread.c pngread.c pngrio.c pngrtran.c pngrutil.c pngset.c pngtrans.c pngwio.c pngwrite.c pngwtran.c pngwutil.c
set H=png.h pngconf.h pnglibconf.h
set CFLAGS=-DPNG_BUILD_DLL -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -lzlib1

call :cmd %CC% -shared -o %DIST_BIN%\libpng16.dll %CFLAGS% %SRC% %LDFLAGS%
del /q /f %DIST_BIN%\libpng16.def >nul 2>&1
call :install . %DIST_INC% %H%


goto :eof


:build_libgd
cd /d %ROOT_SRC%\libgd

set SRC=gd.c gd_bmp.c gd_color.c gd_color_map.c gd_color_match.c gd_crop.c gd_filename.c gd_filter.c gd_gd.c gd_gd2.c gd_gif_in.c gd_gif_out.c gd_interpolation.c gd_io.c gd_io_dp.c gd_io_file.c gd_io_ss.c gd_jpeg.c gd_matrix.c gd_nnquant.c gd_png.c gd_rotate.c gd_security.c gd_ss.c gd_tga.c gd_tiff.c gd_topal.c gd_transform.c gd_version.c gd_wbmp.c gd_webp.c gd_xbm.c gdcache.c gdfontg.c gdfontl.c gdfontmb.c gdfonts.c gdfontt.c gdft.c gdfx.c gdhelpers.c gdkanji.c gdtables.c gdxpm.c wbmp.c
rem set SRC=%src% floorf.c
set H=gd.h gdfx.h gd_io.h gdcache.h gdfontg.h gdfontl.h gdfontmb.h gdfonts.h gdfontt.h entities.h gd_color_map.h gd_errors.h gdpp.h config.h
set CFLAGS=-DHAVE_CONFIG_H -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -lpng16

call :cmd %CC% -shared -o %DIST_BIN%\libgd.dll %CFLAGS% %SRC% %LDFLAGS%
del /q /f %DIST_BIN%\libgd.def >nul 2>&1
call :install . %DIST_INC% %H%


goto :eof


:build_luafilesystem
cd /d %ROOT_SRC%\luafilesystem

set CFLAGS=-I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER%

rem memmove_s.c for tcc
call :cmd %CC% -shared -o %DIST_LUA_LIB%\lfs.dll %CFLAGS% lfs.c %LDFLAGS%
del /q /f %DIST_LUA_LIB%\lfs.def >nul 2>&1

goto :eof


:build_lua_zlib
cd /d %ROOT_SRC%\lua-zlib

set CFLAGS=-DLUA_LIB -DLUA_BUILD_AS_DLL -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER% -lzlib1

call :cmd %CC% -shared -o %DIST_LUA_LIB%\zlib.dll %CFLAGS% lua_zlib.c %LDFLAGS%
del /q /f %DIST_LUA_LIB%\zlib.def >nul 2>&1

goto :eof


:build_lua_zip
rem must be build before luazip!
cd /d %ROOT_SRC%\lua-zip

set CFLAGS=-DLUA_LIB -DLUA_BUILD_AS_DLL -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER% -lzip

mkdir %DIST_LUA_LIB%\brimworks 2>nul

call :cmd %CC% -shared -o %DIST_LUA_LIB%\brimworks\zip.dll %CFLAGS% lua_zip.c %LDFLAGS%
del /q /f %DIST_LUA_LIB%\brimworks\zip.def >nul 2>&1

goto :eof


:build_luazip
cd /d %ROOT_SRC%\luazip

set CFLAGS=-DLUA_LIB -DLUA_BUILD_AS_DLL -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER% -lzzip

call :cmd %CC% -shared -o %DIST_LUA_LIB%\zip.dll %CFLAGS% luazip.c %LDFLAGS%
del /q /f %DIST_LUA_LIB%\zip.def >nul 2>&1

goto :eof


:build_lua_gd
cd /d %R%/src/lua-gd

set CFLAGS=-DVERSION=\"2.0.33r3-git\" -DGD_PNG -DLUA_LIB -DLUA_BUILD_AS_DLL -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER% %DIST_LIB%\libgd.dll

call :cmd %CC% -shared -o %DIST_LUA_LIB%\gd.dll %CFLAGS% luagd.c %LDFLAGS%
del /q /f %DIST_LUA_LIB%\gd.def >nul 2>&1

goto :eof


:build_luasocket
cd /d %ROOT_SRC%\luasocket

rem socket
set SRC=luasocket.c timeout.c buffer.c io.c auxiliar.c options.c inet.c except.c select.c tcp.c udp.c compat.c
set SRC=%SRC% wsocket.c gai_strerror.c
set CFLAGS=-I%DIST_INC%
set LDFLAGS=-lws2_32 -L%DIST_LIB% -l%LUALIBVER%
mkdir %DIST_LUA_LIB%\socket 2>nul
mkdir %DIST_LUA_LIB%\mime 2>nul

call :cmd %CC% -shared -o %DIST_LUA_LIB%\socket\core.dll %CFLAGS% %SRC% %LDFLAGS%
del /q /f %DIST_LUA_LIB%\socket\core.def >nul 2>&1

rem mime
set SRC=mime.c compat.c

echo build mime...
call :cmd %CC% -shared -o %DIST_LUA_LIB%\mime\core.dll %CFLAGS% %SRC% %LDFLAGS%
del /q /f %DIST_LUA_LIB%\mime\core.def >nul 2>&1

set SOCK_T=ltn12.lua socket.lua mime.lua
set SOCK_S=http.lua url.lua tp.lua ftp.lua headers.lua smtp.lua
mkdir %DIST_LUA_SHARE%\socket 2>nul
call :install . %DIST_LUA_SHARE% %SOCK_T%
call :install . %DIST_LUA_SHARE%\socket %SOCK_S%

goto :eof


:build_md5
cd /d %ROOT_SRC%\md5

set CFLAGS=-DLUA_LIB -DLUA_BUILD_AS_DLL -I%DIST_INC%
set LDFLAGS=-L%DIST_LIB% -l%LUALIBVER%

call :cmd %CC% -shared -o %DIST_LUA_LIB%\md5.dll %CFLAGS% md5.c md5lib.c %LDFLAGS%
del /q /f %DIST_LUA_LIB%\md5.def >nul 2>&1

call :install . %DIST_LUA_SHARE% md5.lua

goto :eof


:build_serpent
cd /d %ROOT_SRC%\serpent

call :install . %DIST_LUA_SHARE% serpent.lua

goto :eof


:build_binaryheap
cd /d %ROOT_SRC%\binaryheap

call :install . %DIST_LUA_SHARE% binaryheap.lua

goto :eof


:build_timerwheel
cd /d %ROOT_SRC%\timerwheel

rem !!! need to comment 'require("coxpcall")'

call :install . %DIST_LUA_SHARE% timerwheel.lua

goto :eof


:build_copas
cd /d %ROOT_SRC%\copas

mkdir %DIST_LUA_SHARE%\copas 2>nul

call :install . %DIST_LUA_SHARE% copas.lua
call :install .\copas %DIST_LUA_SHARE%\copas *.lua

goto :eof


:build_xavante
cd /d %ROOT_SRC%\xavante

set H=cgiluahandler.lua encoding.lua filehandler.lua httpd.lua indexhandler.lua mime.lua patternhandler.lua redirecthandler.lua ruleshandler.lua urlhandler.lua vhostshandler.lua
mkdir %DIST_LUA_SHARE%\xavante 2>nul

call :install . %DIST_LUA_SHARE% xavante.lua
call :install . %DIST_LUA_SHARE%\xavante %H%

goto :eof


:build_json
cd /d %ROOT_SRC%\json

call :install . %DIST_LUA_SHARE% JSON.lua
goto eof


:cmd
set CMD=%*
if 1. == %V%. echo =^> %CMD%
%CMD%
if ERRORLEVEL 1 set FAIL=1
goto :eof


:install
if defined FAIL goto :break
set CMD=%*
if 1. == %V%. echo =^> robocopy %CMD%
robocopy %CMD% /nfl /njh /njs /ndl /nc /ns >nul
goto :eof


:move
if defined FAIL goto :break
set CMD=%*
if 1. == %V%. echo =^> move %CMD%
move %CMD%
goto :eof


:break
rem echo FAIL

:eof
