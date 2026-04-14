#define _GNU_SOURCE
#include <fcntl.h>
#include <stdarg.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

int open64(const char *path, int flags, ...) {
    mode_t mode = 0;

    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
        return open(path, flags, mode);
    }

    return open(path, flags);
}

int stat64(const char *restrict path, struct stat64 *restrict buf) {
    return stat(path, buf);
}

int fstat64(int fd, struct stat64 *buf) {
    return fstat(fd, buf);
}

int ftruncate64(int fd, off_t length) {
    return ftruncate(fd, length);
}

int fcntl64(int fd, int cmd, ...) {
    va_list ap;
    void *arg;
    int result;

    va_start(ap, cmd);
    if (cmd == F_GETFD || cmd == F_GETFL) {
        result = fcntl(fd, cmd);
    } else {
        arg = va_arg(ap, void *);
        result = fcntl(fd, cmd, arg);
    }
    va_end(ap);

    return result;
}

ssize_t pread64(int fd, void *buf, size_t count, off_t offset) {
    return pread(fd, buf, count, offset);
}

ssize_t pwrite64(int fd, const void *buf, size_t count, off_t offset) {
    return pwrite(fd, buf, count, offset);
}

void *mmap64(void *addr, size_t length, int prot, int flags, int fd, off_t offset) {
    return mmap(addr, length, prot, flags, fd, offset);
}

int lstat64(const char *restrict path, struct stat64 *restrict buf) {
    return lstat(path, buf);
}
