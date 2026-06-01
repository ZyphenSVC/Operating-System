HOST ?= i686-elf
HOSTARCH ?= i686

SYSTEM_HEADER_PROJECTS := libc kernel
PROJECTS := libc kernel

SYSROOT := $(CURDIR)/sysroot
ISODIR := $(CURDIR)/isodir
ISO := myos.iso

PREFIX := /usr
EXEC_PREFIX := $(PREFIX)
BOOTDIR := /boot
LIBDIR := $(EXEC_PREFIX)/lib
INCLUDEDIR := $(PREFIX)/include

AR := $(HOST)-ar
AS := $(HOST)-as
CC := $(HOST)-gcc --sysroot=$(SYSROOT)
CXX := $(HOST)-g++ --sysroot=$(SYSROOT)

CFLAGS ?= -O2 -g
CFLAGS += -Wall -Wextra

CXXFLAGS ?= -O2 -g
CXXFLAGS += -Wall -Wextra -fno-exceptions -fno-rtti

CPPFLAGS ?=

# Your freestanding headers are installed into sysroot/usr/include.
# Do not point the cross compiler at the host /usr/include.
ifneq ($(filter %-elf,$(HOST)),)
CPPFLAGS += -isystem $(SYSROOT)$(INCLUDEDIR)
endif

QEMU := qemu-system-i386
QEMU_MEM ?= 128M

VNC_PASSWORD_FILE ?= .vnc-password
VNC_HOST_FILE ?= .vnc-host
VNC_DISPLAY ?= 1

export HOST
export HOSTARCH
export AR
export AS
export CC
export CXX
export PREFIX
export EXEC_PREFIX
export BOOTDIR
export LIBDIR
export INCLUDEDIR
export SYSROOT
export CFLAGS
export CXXFLAGS
export CPPFLAGS

.PHONY: all clean headers build iso qemu qemu-vnc check-iso check-grub default-host

all: iso

default-host:
	@echo $(HOST)

headers:
	mkdir -p $(SYSROOT)
	set -e; for project in $(SYSTEM_HEADER_PROJECTS); do \
		$(MAKE) -C $$project DESTDIR=$(SYSROOT) install-headers; \
	done

build: headers
	set -e; for project in $(PROJECTS); do \
		$(MAKE) -C $$project DESTDIR=$(SYSROOT) install; \
	done

clean:
	set -e; for project in $(PROJECTS); do \
		$(MAKE) -C $$project clean; \
	done
	rm -rf $(SYSROOT)
	rm -rf $(ISODIR)
	rm -f $(ISO)

iso: build
	rm -rf $(ISODIR)
	mkdir -p $(ISODIR)/boot/grub
	cp $(SYSROOT)$(BOOTDIR)/myos.kernel $(ISODIR)/boot/myos.kernel
	printf '%s\n' \
		'set timeout=0' \
		'set default=0' \
		'' \
		'menuentry "myos" {' \
		'    multiboot /boot/myos.kernel' \
		'    boot' \
		'}' > $(ISODIR)/boot/grub/grub.cfg
	grub-file --is-x86-multiboot $(SYSROOT)$(BOOTDIR)/myos.kernel
	grub-mkrescue -o $(ISO) $(ISODIR)

check-iso: iso
	xorriso -indev $(ISO) -ls /boot
	xorriso -indev $(ISO) -ls /boot/grub
	xorriso -indev $(ISO) -report_el_torito plain

check-grub: iso
	xorriso -indev $(ISO) -ls /boot/grub

qemu: iso
	$(QEMU) \
		-cdrom ./$(ISO) \
		-boot d \
		-machine pc \
		-vga std \
		-monitor stdio \
		-m $(QEMU_MEM)

qemu-vnc: iso
	@test -f $(VNC_PASSWORD_FILE) || (echo "Missing $(VNC_PASSWORD_FILE). Create it with: printf '%s' '<password>' > $(VNC_PASSWORD_FILE) && chmod 600 $(VNC_PASSWORD_FILE)" && exit 1)
	@test -f $(VNC_HOST_FILE) || (echo "Missing $(VNC_HOST_FILE). Create it with: printf '%s' '<remote-private-ip>' > $(VNC_HOST_FILE) && chmod 600 $(VNC_HOST_FILE)" && exit 1)
	$(QEMU) \
		-cdrom ./$(ISO) \
		-boot d \
		-machine pc \
		-vga std \
		-object secret,id=vncpass,file=$(VNC_PASSWORD_FILE) \
		-vnc $$(cat $(VNC_HOST_FILE)):$(VNC_DISPLAY),password-secret=vncpass \
		-monitor stdio \
		-m $(QEMU_MEM)


