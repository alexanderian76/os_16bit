ASM=nasm

BUILD_DIR=build
KERNEL_DIR=kernel
TOOLS_DIR=tools

all: first second third mcopy

first:
	nasm $(KERNEL_DIR)/basic.asm -f bin -o $(BUILD_DIR)/kernel.bin
	nasm boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

second:
	cp $(BUILD_DIR)/kernel.bin $(BUILD_DIR)/main_floppy.img
third:

	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880 
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img 
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc 
fourth:
	dd if=$(BUILD_DIR)/kernel.bin of=$(BUILD_DIR)/main_floppy.img seek=1
	
mcopy:
	mcopy -i $(BUILD_DIR)/main_floppy.img  $(BUILD_DIR)/kernel.bin "::kernel.bin"


run:
	qemu-system-i386 -fda build/main_floppy.img



tools_fat:
	mkdir -p $(BUILD_DIR)/tools
	gcc -g -o $(BUILD_DIR)/tools/fat $(TOOLS_DIR)/fat/fat.c


always:
	mkdir -p $(BUILD_DIR)


clean:
	rm -rf $(BUILD_DIR)/*