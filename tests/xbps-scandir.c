// test that the scandir -> scandir64 redirection works properly
// if _REDIRECT isn't supported, scandir is macro'd to scandir64 which is only
//  visible with _GNU_SOURCE

#include <stddef.h>
#include <dirent.h>

void walk_dir(const char *path)
{
	struct dirent **list;
	int rv = scandir(path, &list, NULL, alphasort);
}
