org 0x7c00
bits 16

; FAT 12 header

    jmp short start
    nop

bdb_oem:    db    "MSWIN4.1" ; 8 any bytes
bdb_bytes_per_sector:   dw  512 
bdb_sectors_per_claster:    db 1
bdb_reserved_sectors:   dw 1
bdb_fat_allocation_table_counter:   db 2
bdb_dir_entries_count:  dw 0E0h
bdb_total_sectors:  dw 2880
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:    dw 9
bdb_sectors_per_track:  dw 18
bdb_heads:  dw 2 
bdb_hidden_sector_count: dd 0
bdb_large_sector_count: dd 0

;extended boot record


ebr_drive_number:   db  0       ; 0x0 floopy, 0x80 hdd
                    db  0   ; reserved
ebr_signature:      db  29      
ebr_volume_id:      db  0x3B, 0xBB, 0x55, 0x22      ; serial number
ebr_volume_label:   db  "My OS      "   ; 11 bytes label
ebr_system_id:      db  "FAT12   " ; 8 bytes 


; Code goes here

start:
    mov ax, 0
    mov ds, ax
    mov es, ax

    mov ss, ax
    mov sp, 0x7c00

    ; some BIOSes might start us at 07C0:0000 instead of 0000:7C00 make sure you are in the expected location 
    push es
    push word .after
    retf
.after


    ; read from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, loading_msg
    call puts
    

    ; read drive parameters (sector per track and head count)
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F    ; remove top 2 bits (reserved)
    xor ch,ch 
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh ; head count 

    ;read FAT root directory
    mov ax, [bdb_sectors_per_fat]   ; compute LBA of root directory = reserved + fats * sectors_per_fat
    mov bl, [bdb_fat_allocation_table_counter]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax


    ;compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5   ; ax *= 32
    xor dx, dx
    div word [bdb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx ; if dx != 0 add 1 
    jz .root_dir_after
    inc ax

.root_dir_after:
    ; read root directory
    mov cl, al ;        number of sectors to read = size of root directory
    pop ax      ; ax = LBA of root directory
    mov dl, [ebr_drive_number]  ; dl = drive number (we saved it previosly)
    mov bx, buffer ; es:bx = buffer
    call disk_read

    ;search for the kernel load bin file in directory entries
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11  ; compare to 11 characters (length of the file name)
    push di 
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel


    ;kernel not found
    jmp kernel_not_found_error

.found_kernel:
    ; di should have the address to the entry
    mov ax, [di + 26] ; first logical cluster field (offset 26)
    mov [kernel_cluster], ax 
    
    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; read next cluster 
    mov ax, [kernel_cluster]
    
    add ax, 31 ; HARD CODE for 1.44mb disks only!

    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of the next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx
    
    mov si, buffer
    add si, ax
    mov ax, [ds:si] ; read FAT table at index ax

    or dx, dx
    jz .even 


.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8      ; end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; boot device in dl
    mov dl, [ebr_drive_number]
    mov ax, KERNEL_LOAD_SEGMENT

    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot

; should never be happaned
   ; mov si, 0x7e05 ; get read data in the display
 ;   call puts 
  ;  jmp 0x7e00
    
    cli
    hlt



; Error handler

floppy_error:
    mov si, message_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot


wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0ffffh:0 ; jmp to the begining of the BIOS 

.halt
    cli 
    hlt







puts:
    push si
    push ax
    push bx

.loop:
    lodsb ; load next char to al
    or al, al ; if null jmp to done_puts
    jz .done_puts
    mov ah, 0x0e
    mov bh, 0x0
    int 10h
    jmp .loop
.done_puts:
    pop bx
    pop ax
    pop si
    ret










; Disk routines
;Converts LBA address to a CHS address
; Parameters:
;   ax - LBA address
; Returns:
;   cx - [bits 0-5]: sector number 
;   cx - [bits 6-15]: cylinder 
;   dh: head

lba_to_chs:
    push ax
    push dx


    xor dx, dx                              ; dx = 0
    div word [bdb_sectors_per_track]        ; ax = LBA / Sectors per track
                                            ; dx = LBA % Sectors per track
    inc dx                                  ; dx = (LBA % Sectors per track + 1) = sector
    mov cx, dx                              ; cx = sector
    xor dx, dx
    div word [bdb_heads]


    mov dh, dl
    mov ch, al
    shl ah, 6
    or  cl, ah

    pop ax
    mov dl, al
    pop ax

    ret



;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret

; dl: drive number 
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret




loading_msg: db `Loading...\n`, 0
message_read_failed:    db  "Read from disk failed", 0
file_kernel_bin:        db  "KERNEL  BIN"
msg_kernel_not_found: db  "KERNEL.BIN file not found!", 0
kernel_cluster:         dw  0

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0


times 510-($-$$) db 0 
dw 0xAA55


buffer: