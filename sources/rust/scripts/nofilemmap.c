/*
 * nofilemmap: LD_PRELOAD shim for Haiku that replaces read-only/private mmap()
 * of regular files with an anonymous mapping filled by pread().
 *
 * Purpose: test whether build-output corruption on Haiku enters through the
 * file-mapping (VMCache) path. rustc maps .rlib/.rmeta files with memmap2 and
 * GNU ld maps its inputs; with this shim neither touches file mappings.
 *
 * Build:  x86_64-unknown-haiku-gcc -shared -fPIC -O2 -o libnofilemmap.so nofilemmap.c
 * Use:    LD_PRELOAD=/boot/home/rust/libnofilemmap.so <command>
 * Debug:  NOFILEMMAP_LOG=1 prints one line per replaced mapping to stderr.
 */
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

typedef void *(*mmap_fn)(void *, size_t, int, int, int, off_t);

static mmap_fn real_mmap(void)
{
	static mmap_fn fn;
	if (fn == NULL) {
		void *libroot = dlopen("libroot.so", RTLD_LAZY);
		if (libroot != NULL)
			fn = (mmap_fn)dlsym(libroot, "mmap");
	}
	return fn;
}

void *mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off)
{
	mmap_fn real = real_mmap();
	struct stat st;

	if (real == NULL) {
		errno = ENOSYS;
		return MAP_FAILED;
	}

	/* Only private, non-executable mappings of regular files. Shared writable
	 * mappings must stay real: writes through them have to reach the file. */
	if (fd < 0 || (flags & MAP_ANONYMOUS) || (prot & PROT_EXEC)
		|| ((flags & MAP_SHARED) && (prot & PROT_WRITE))
		|| fstat(fd, &st) != 0 || !S_ISREG(st.st_mode))
		return real(addr, len, prot, flags, fd, off);

	int anonFlags = MAP_PRIVATE | MAP_ANONYMOUS | (flags & MAP_FIXED);
	char *p = real(addr, len, PROT_READ | PROT_WRITE, anonFlags, -1, 0);
	if (p == MAP_FAILED)
		return p;

	size_t done = 0;
	while (done < len) {
		ssize_t n = pread(fd, p + done, len - done, off + (off_t)done);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			int e = errno;
			munmap(p, len);
			errno = e;
			return MAP_FAILED;
		}
		if (n == 0)
			break;		/* past EOF: the rest stays zero, like a mapping */
		done += (size_t)n;
	}

	if (!(prot & PROT_WRITE))
		mprotect(p, len, prot);

	if (getenv("NOFILEMMAP_LOG") != NULL)
		fprintf(stderr, "nofilemmap: fd %d len %zu off %lld -> anon %p\n", fd,
			len, (long long)off, (void *)p);
	return p;
}
