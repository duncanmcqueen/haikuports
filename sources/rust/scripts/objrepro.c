/*
 * objrepro: reproduce the rustc "archive a freshly written object" pattern.
 *
 * Evidence (corrupt librustc_target rlib, 2026-10-03): wrong 4 KiB pages are
 * page-aligned relative to a member .rcgu.o file, i.e. the object file's
 * content was already wrong when rustc mapped it to copy it into the .rlib.
 * rustc does: LLVM worker threads write <name>.rcgu.o with write() (and may
 * back-patch the start with pwrite), close; the main thread then mmap()s each
 * object, copies it into the archive, munmap()s, and deletes the objects.
 * The next build reuses the same object file names.
 *
 * Each process here runs that cycle in a loop with T writer threads and checks
 * every page it maps against the expected content.
 *
 * Usage: objrepro [-r] [-n] [-u] <dir> <processes> <threads> <minutes>
 *   -r  verify with read() instead of mmap() (control)
 *   -n  no back-patch: write page 0 first instead of pwrite() at the end
 *   -u  unique object file names (no reuse of a just-deleted name)
 */
#include <fcntl.h>
#include <pthread.h>
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

static uint64_t splitmix(uint64_t *s)
{
	uint64_t z = (*s += 0x9e3779b97f4a7c15ULL);
	z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
	z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
	return z ^ (z >> 31);
}

#define TAG 0x4741545045474150ULL	/* "PAGETPAG" */

/* Page i of generation `seed`: words 0..2 are a tag (magic, seed, index) so a
 * wrong page tells where its content came from; the rest is pseudo-random. */
static void fill_page(uint8_t *p, uint64_t seed, uint64_t i)
{
	uint64_t s = seed * 1000003ULL + i;
	for (int k = 0; k < PAGE / 8; k++)
		((uint64_t *)p)[k] = splitmix(&s);
	((uint64_t *)p)[0] = TAG;
	((uint64_t *)p)[1] = seed;
	((uint64_t *)p)[2] = i;
}

static int opt_nopatch, opt_unique;
static uint64_t prev_seed[64];	/* last generation written per slot */

struct job {
	char path[512];
	uint64_t seed, prev, pages;
	int ok;
};

static void *writer(void *arg)
{
	struct job *j = arg;
	int fd = open(j->path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0)
		return NULL;
	/* like raw_fd_ostream: buffered sequential writes of odd sizes */
	uint8_t *buf = malloc(j->pages * PAGE);
	for (uint64_t i = 0; i < j->pages; i++)
		fill_page(buf + i * PAGE, j->seed, i);
	/* write page 0 as zeros first, patch it at the end (ELF header style) */
	uint8_t zero[PAGE] = { 0 };
	size_t total = j->pages * PAGE, done = PAGE;
	write(fd, opt_nopatch ? buf : zero, PAGE);
	uint64_t r = j->seed;
	while (done < total) {
		size_t chunk = 1000 + splitmix(&r) % 70000;
		if (chunk > total - done)
			chunk = total - done;
		if (write(fd, buf + done, chunk) != (ssize_t)chunk)
			break;
		done += chunk;
	}
	if (!opt_nopatch)
		pwrite(fd, buf, PAGE, 0);
	j->ok = close(fd) == 0 && done == total;
	free(buf);
	return NULL;
}

static long check(struct job *j, int use_read, int proc, int *archive_fd)
{
	int fd = open(j->path, O_RDONLY);
	if (fd < 0)
		return 0;
	size_t len = j->pages * PAGE;
	uint8_t *data;
	if (use_read) {
		data = malloc(len);
		size_t d = 0;
		while (d < len) {
			ssize_t n = pread(fd, data + d, len - d, (off_t)d);
			if (n <= 0)
				break;
			d += (size_t)n;
		}
	} else {
		data = mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, 0);
		if (data == MAP_FAILED) {
			close(fd);
			return 0;
		}
	}
	long bad = 0;
	uint8_t want[PAGE];
	for (uint64_t i = 0; i < j->pages; i++) {
		fill_page(want, j->seed, i);
		if (memcmp(data + i * PAGE, want, PAGE) != 0) {
			int diff = 0, zeros = 0;
			for (int k = 0; k < PAGE; k++) {
				diff += data[i * PAGE + k] != want[k];
				zeros += data[i * PAGE + k] == 0;
			}
			const uint64_t *w = (const uint64_t *)(data + i * PAGE);
			const char *origin = w[0] != TAG ? "untagged"
				: w[1] == j->seed ? "same-gen"
				: w[1] == j->prev ? "prev-gen-same-name" : "other-gen";
			if (bad < 8)
				printf("BAD proc=%d file=%s page=%llu/%llu diff=%d zeros=%d "
					"via=%s origin=%s tagpage=%llu t=%ld\n", proc, j->path,
					(unsigned long long)i, (unsigned long long)j->pages, diff,
					zeros, use_read ? "read" : "mmap", origin,
					(unsigned long long)(w[0] == TAG ? w[2] : 0),
					(long)time(NULL));
			bad++;
		}
	}
	if (bad)
		printf("BADFILE proc=%d file=%s badpages=%ld of %llu\n", proc, j->path,
			bad, (unsigned long long)j->pages);
	/* copy into the "archive" like ArArchiveBuilder */
	write(*archive_fd, data, len);
	if (use_read)
		free(data);
	else
		munmap(data, len);
	close(fd);
	return bad;
}

static void process(const char *dir, int proc, int threads, time_t end,
	int use_read)
{
	uint64_t rng = (uint64_t)proc * 104729 + (uint64_t)time(NULL);
	long rounds = 0, files = 0, bad = 0;
	char apath[512];
	snprintf(apath, sizeof apath, "%s/p%d.rlib", dir, proc);
	struct job *jobs = calloc((size_t)threads, sizeof *jobs);
	pthread_t *tid = calloc((size_t)threads, sizeof *tid);
	while (time(NULL) < end) {
		for (int t = 0; t < threads; t++) {
			/* same names every round, like <crate>-<hash>.<cgu>.rcgu.o */
			if (opt_unique)
				snprintf(jobs[t].path, sizeof jobs[t].path,
					"%s/p%d.r%ld.cgu.%02d.rcgu.o", dir, proc, rounds, t);
			else
				snprintf(jobs[t].path, sizeof jobs[t].path,
					"%s/p%d.cgu.%02d.rcgu.o", dir, proc, t);
			jobs[t].prev = prev_seed[t];
			jobs[t].seed = splitmix(&rng);
			prev_seed[t] = jobs[t].seed;
			jobs[t].pages = 1 + splitmix(&rng) % 4096;	/* up to 16 MiB */
			jobs[t].ok = 0;
			pthread_create(&tid[t], NULL, writer, &jobs[t]);
		}
		for (int t = 0; t < threads; t++)
			pthread_join(tid[t], NULL);
		int afd = open(apath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
		for (int t = 0; t < threads; t++) {
			if (!jobs[t].ok)
				continue;
			bad += check(&jobs[t], use_read, proc, &afd);
			files++;
		}
		close(afd);
		for (int t = 0; t < threads; t++)
			unlink(jobs[t].path);
		rounds++;
	}
	printf("SUMMARY proc=%d rounds=%ld files=%ld badpages=%ld\n", proc, rounds,
		files, bad);
}

int main(int argc, char **argv)
{
	int use_read = 0, a = 1;
	for (; a < argc && argv[a][0] == '-'; a++) {
		if (strcmp(argv[a], "-r") == 0)
			use_read = 1;
		else if (strcmp(argv[a], "-n") == 0)
			opt_nopatch = 1;
		else if (strcmp(argv[a], "-u") == 0)
			opt_unique = 1;
	}
	if (argc - a < 4) {
		fprintf(stderr, "usage: %s [-r] <dir> <procs> <threads> <minutes>\n",
			argv[0]);
		return 2;
	}
	const char *dir = argv[a];
	int procs = atoi(argv[a + 1]), threads = atoi(argv[a + 2]);
	time_t end = time(NULL) + 60 * atoi(argv[a + 3]);
	mkdir(dir, 0755);
	setvbuf(stdout, NULL, _IOLBF, 0);
	printf("START procs=%d threads=%d via=%s backpatch=%d unique-names=%d\n",
		procs, threads, use_read ? "read" : "mmap", !opt_nopatch, opt_unique);
	for (int p = 0; p < procs; p++)
		if (fork() == 0) {
			process(dir, p, threads, end, use_read);
			_exit(0);
		}
	int st;
	pid_t pid;
	while ((pid = wait(&st)) > 0)
		if (WIFSIGNALED(st))
			printf("CHILD pid=%d signal %d\n", (int)pid, WTERMSIG(st));
	printf("END\n");
	return 0;
}
