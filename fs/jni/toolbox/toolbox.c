#include <sys/stat.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <fts.h>
#include <grp.h>
#include <pwd.h>


int getowner(char* path) {
    struct stat st;

    if (stat(path, &st) == -1) {
        perror("stat failed");
        return 1;
    }

    printf("%ld:%ld\n", (long)st.st_uid, (long)st.st_gid);
    return 0;
}


int getusage(char* path) {
    size_t apparent = 0, actual = 0, apparent_backbuf = 0, actual_backbuf = 0;
    char* paths[] = {path, NULL};

    FTS* fts = fts_open(paths, FTS_PHYSICAL | FTS_XDEV, NULL);
    if (fts == NULL) {
        perror("fts_open failed");
        return 1;
    }

    FTSENT* child;
    errno = 0;
    while ((child = fts_read(fts)) != NULL) {
        if ((child->fts_info == FTS_F || child->fts_info == FTS_D) && child->fts_statp) {
            apparent += child->fts_statp->st_size / 1024;
            actual += child->fts_statp->st_blocks / 2;
            apparent_backbuf += child->fts_statp->st_size % 1024;
            actual_backbuf += child->fts_statp->st_blocks % 2;

            while (apparent_backbuf > 1024) {
                apparent_backbuf -= 1024;
                apparent++;
            }

            while (actual_backbuf > 2) {
                actual_backbuf -= 2;
                actual++;
            }

            printf("%zu %zu\n", apparent, actual);
        }

        errno = 0;
    }

    if (errno != 0) {
        perror("fts_read failed");
        return 1;
    }

    return 0;
}


int main(int argc, char** argv) {

    if (argc != 3) {
        fputs("usage: toolbox [owner|usage] <path>\n", stderr);
        return 1;
    }

    if (strcmp(argv[1], "owner") == 0) {
        return getowner(argv[2]);
    } else if (strcmp(argv[1], "usage") == 0) {
        return getusage(argv[2]);
    } else {
        fprintf(stderr, "invalid action: %s\n", argv[1]);
        return 1;
    }
}
