#include <stdlib.h>
#include <string.h>

#ifndef _VALIDATE_RETURN_ERRCODE
#define _VALIDATE_RETURN_ERRCODE(c, e) \
    if (!(c)) return e
#endif

#ifndef ENOMEM
#define ENOMEM 12
#endif

#ifndef EINVAL
#define EINVAL 22
#endif

#ifndef ERANGE
#define ERANGE 34
#endif

void* __cdecl memmove_xplat(
    void * dst,
    const void * src,
    size_t count
)
{
    return memmove(dst, src, count);
}

/*
usage: see https://msdn.microsoft.com/en-us/library/e2851we8.aspx
dest
    Destination object.
sizeInBytes
    Size of the destination buffer.
src
    Source object.
count
    Number of bytes (memmove_s) or characters (wmemmove_s) to copy.
*/
int __cdecl memmove_s(
    void * dst,
    size_t sizeInBytes,
    const void * src,
    size_t count
)
{
    if (count == 0)
    {
        /* nothing to do */
        return 0;
    }

    /* validation section */
    _VALIDATE_RETURN_ERRCODE(dst != NULL, EINVAL);
    _VALIDATE_RETURN_ERRCODE(src != NULL, EINVAL);
    _VALIDATE_RETURN_ERRCODE(sizeInBytes >= count, ERANGE);

    void *ret_val = memmove_xplat(dst, src, count);
    return ret_val != NULL ? 0 : ENOMEM; // memmove_xplat returns `NULL` only if ENOMEM
}
