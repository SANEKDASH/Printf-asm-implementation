#include <stdio.h>

extern "C"

int MyPrintf(const char *, ...) __attribute__((format(printf, 1, 2)));



int main(int argc, char *argv[])
{
	int a = MyPrintf("%o\n", 64);

	/*printf("%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
					 -1,
					 -1,
					 "love",
					 3802,
					 100,
					 33,
					 127,
					 -1,
					"love", 3802, 100, 33, 127);
*/
	return 0;
}
