#include <sys/stat.h>
#include <stdio.h>
#include <grp.h>
#include <pwd.h>


int main(int argc, char** argv) {
    struct stat st;

    if (argc != 2) {
        fputs("usage: getowner <file>\n", stderr);
        return 1;
    }

    if (stat(argv[1], &st) == -1) {
        perror("stat failed");
        return 1;
    }

    printf("%ld:%ld\n", (long)st.st_uid, (long)st.st_gid);
    return 0;
}
