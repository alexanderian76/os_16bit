
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







    mov ax, 1
    mov cl, 4
    mov bx, 0x7e00 ; address after 512 bytes of bootloader

    call disk_read
