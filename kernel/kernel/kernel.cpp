#include <stddef.h>
#include <stdio.h>

#include <kernel/tty.h>

extern "C" void kernel_main(void)
{
	terminal_initialize();

	for (size_t i = 0; i < 30; i++) {
		printf("Hello, kernel World!\n");
	}
}
