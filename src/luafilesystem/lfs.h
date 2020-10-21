/*
** LuaFileSystem
** Copyright Kepler Project 2003 - 2020
** (http://keplerproject.github.io/luafilesystem)
*/

/* Define 'chdir' for systems that do not implement it */
#ifdef NO_CHDIR
#define chdir(p)	(-1)
#define chdir_error	"Function 'chdir' not provided by system"
#else
#define chdir_error	strerror(errno)
#endif

#ifdef _WIN32
#define chdir(p) (_chdir(p))
#define getcwd(d, s) (_getcwd(d, s))
#define rmdir(p) (_rmdir(p))
#define LFS_EXPORT __declspec (dllexport)
#ifndef fileno
#define fileno(f) (_fileno(f))
#endif

#if defined(__TINYC__)
#define FILE_NAME_OPENED 0x8
#ifdef _stati64
#undef _stati64
#define _stati64 _stat64
#endif
    WINBASEAPI BOOLEAN APIENTRY CreateSymbolicLinkA (LPCSTR lpSymlinkFileName, LPCSTR lpTargetFileName, DWORD dwFlags);
    WINBASEAPI BOOLEAN APIENTRY CreateSymbolicLinkW (LPCWSTR lpSymlinkFileName, LPCWSTR lpTargetFileName, DWORD dwFlags);
    #if _WIN32_WINNT >= 0x0600
      WINBASEAPI DWORD WINAPI GetFinalPathNameByHandleA (HANDLE hFile, LPSTR lpszFilePath, DWORD cchFilePath, DWORD dwFlags);
      WINBASEAPI DWORD WINAPI GetFinalPathNameByHandleW (HANDLE hFile, LPWSTR lpszFilePath, DWORD cchFilePath, DWORD dwFlags);
    #endif 
    #ifdef UNICODE
      #define CreateSymbolicLink CreateSymbolicLinkW
      #define GetFinalPathNameByHandle GetFinalPathNameByHandleW
    #else
      #define CreateSymbolicLink CreateSymbolicLinkA
      #define GetFinalPathNameByHandle GetFinalPathNameByHandleA
    #endif
extern int __cdecl memmove_s(void * dst, size_t sizeInBytes, const void * src, size_t count);
#endif

#else
#define LFS_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

  LFS_EXPORT int luaopen_lfs(lua_State * L);

#ifdef __cplusplus
}
#endif
