/*
 * fsrepro: multi-process file-cache integrity stress test for Haiku.
 *
 * Mimics how cargo/rustc use the file system: several processes write large
 * files to temporary names, rename them into place, sometimes rewrite files in
 * place with O_TRUNC, and read files written by other processes. Every file is
 * self-describing (header: magic, seed, size), so any reader can check every
 * 4 KiB page. Uses read()/write() only unless -m is given (then readers verify
 * through mmap() as well).
 *
 * Usage: fsrepro [-m] <dir> <workers> <minutes> [files-per-worker]
 * Output: one line per bad page to stdout, a summary per worker at the end.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define PAGE 4096
#define MAGIC 0x5253504f52465348ULL	/* "HSFRPROR" */

struct header {
	uint64_t magic, seed, size, writer;
};

static uint64_t splitmix(uint64_t *s)
{
	uint64_t z = (*s += 0x9e3779b97f4a7c15ULL);
	z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
	z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
	return z ^ (z >> 31);
}

/* Page i of a file with this seed. Page 0 starts with the header. */
static void fill_page(uint8_t *p, uint64_t seed, uint64_t i)
{
	uint64_t s = seed * 1000003ULL + i;
	for (int k = 0; k < PAGE / 8; k++)
		((uint64_t *)p)[k] = splitmix(&s);
}

static int write_file(const char *path, uint64_t seed, uint64_t size, int writer,
	int flags)
{
	int fd = open(path, O_WRONLY | O_CREAT | flags, 0644);
	if (fd < 0)
		return -1;
	uint8_t buf[PAGE * 16];
	uint64_t pages = size / PAGE;
	for (uint64_t i = 0; i < pages;) {
		int n = 0;
		for (; n < 16 && i < pages; n++, i++) {
			fill_page(buf + n * PAGE, seed, i);
			if (i == 0) {
				struct header h = { MAGIC, seed, size, (uint64_t)writer };
				memcpy(buf, &h, sizeof h);
			}
		}
		if (write(fd, buf, (size_t)n * PAGE) != (ssize_t)n * PAGE) {
			close(fd);
			return -1;
		}
	}
	return close(fd);
}

static long verify_fd(int fd, const char *path, int me, int use_mmap)
{
	struct header h;
	if (pread(fd, &h, sizeof h, 0) != sizeof h || h.magic != MAGIC)
		return 0;	/* being replaced or not ours: skip */
	struct stat st;
	if (fstat(fd, &st) != 0 || (uint64_t)st.st_size != h.size)
		return 0;
	uint8_t want[PAGE], got[PAGE];
	uint8_t *map = NULL;
	if (use_mmap) {
		map = mmap(NULL, h.size, PROT_READ, MAP_PRIVATE, fd, 0);
		if (map == MAP_FAILED)
			map = NULL;
	}
	long bad = 0;
	for (uint64_t i = 0; i < h.size / PAGE; i++) {
		fill_page(want, h.seed, i);
		if (i == 0)
			memcpy(want, &h, sizeof h);
		const uint8_t *src = got;
		if (map != NULL)
			src = map + i * PAGE;
		else if (pread(fd, got, PAGE, (off_t)(i * PAGE)) != PAGE)
			break;
		if (memcmp(src, want, PAGE) != 0) {
			int diff = 0;
			for (int k = 0; k < PAGE; k++)
				diff += src[k] != want[k];
			printf("BAD worker=%d file=%s writer=%llu seed=%llu page=%llu/%llu "
				"diffbytes=%d via=%s got=%016llx want=%016llx t=%ld\n",
				me, path, (unsigned long long)h.writer,
				(unsigned long long)h.seed, (unsigned long long)i,
				(unsigned long long)(h.size / PAGE), diff,
				map ? "mmap" : "read",
				(unsigned long long)((uint64_t *)src)[8],
				(unsigned long long)((uint64_t *)want)[8], (long)time(NULL));
			fflush(stdout);
			bad++;
		}
	}
	if (map != NULL)
		munmap(map, h.size);
	return bad;
}

static void worker(const char *dir, int me, int workers, int files, time_t end,
	int use_mmap)
{
	uint64_t rng = (uint64_t)me * 7919 + (uint64_t)time(NULL);
	long written = 0, verified = 0, bad = 0;
	char path[512], tmp[512];
	while (time(NULL) < end) {
		uint64_t r = splitmix(&rng);
		uint64_t size = (1 + r % 32) << 20;	/* 1..32 MiB */
		uint64_t seed = splitmix(&rng);
		int slot = (int)((r >> 8) % (uint64_t)files);
		int inplace = (r >> 16) % 4 == 0;
		/* In-place rewrites go to private files (only the owner reads them), so
		 * readers never race a truncating writer. Shared files are replaced by
		 * rename only, which keeps an open reader on the old, complete inode. */
		snprintf(path, sizeof path, inplace ? "%s/w%d-p%d" : "%s/w%d-f%d", dir,
			me, slot);
		if (inplace) {
			if (write_file(path, seed, size, me, O_TRUNC) == 0)
				written++;
		} else {
			snprintf(tmp, sizeof tmp, "%s/tmp-w%d-%llu", dir, me,
				(unsigned long long)written);
			if (write_file(tmp, seed, size, me, O_TRUNC | O_EXCL) == 0
				&& rename(tmp, path) == 0)
				written++;
			else
				unlink(tmp);
		}
		/* verify own fresh file and two random files of other workers */
		for (int k = 0; k < 3; k++) {
			int w = k == 0 ? me : (int)(splitmix(&rng) % (uint64_t)workers);
			int f = k == 0 ? slot : (int)(splitmix(&rng) % (uint64_t)files);
			if (k == 0)
				snprintf(tmp, sizeof tmp, "%s", path);
			else
				snprintf(tmp, sizeof tmp, "%s/w%d-f%d", dir, w, f);
			int fd = open(tmp, O_RDONLY);
			if (fd < 0)
				continue;
			bad += verify_fd(fd, tmp, me, use_mmap && k != 0);
			verified++;
			close(fd);
		}
	}
	printf("SUMMARY worker=%d written=%ld verified=%ld badpages=%ld\n", me,
		written, verified, bad);
	fflush(stdout);
}

int main(int argc, char **argv)
{
	int use_mmap = 0, a = 1;
	if (argc > 1 && strcmp(argv[1], "-m") == 0) {
		use_mmap = 1;
		a++;
	}
	if (argc - a < 3) {
		fprintf(stderr, "usage: %s [-m] <dir> <workers> <minutes> [files]\n",
			argv[0]);
		return 2;
	}
	const char *dir = argv[a];
	int workers = atoi(argv[a + 1]);
	time_t end = time(NULL) + 60 * atoi(argv[a + 2]);
	int files = argc - a > 3 ? atoi(argv[a + 3]) : 8;
	mkdir(dir, 0755);
	setvbuf(stdout, NULL, _IOLBF, 0);
	printf("START workers=%d files=%d mmap=%d\n", workers, files, use_mmap);
	for (int w = 0; w < workers; w++) {
		if (fork() == 0) {
			worker(dir, w, workers, files, end, use_mmap);
			_exit(0);
		}
	}
	int status;
	pid_t pid;
	while ((pid = wait(&status)) > 0) {
		if (WIFSIGNALED(status))
			printf("CHILD pid=%d killed by signal %d\n", (int)pid,
				WTERMSIG(status));
		else if (WEXITSTATUS(status) != 0)
			printf("CHILD pid=%d exit %d\n", (int)pid, WEXITSTATUS(status));
	}
	printf("END\n");
	return 0;
}
