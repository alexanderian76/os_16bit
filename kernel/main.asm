bits 16
start:
    jmp main

main:
    
    mov ah, 0
    int 16h
    xor ah, ah
    push ax
    jmp .keyboard_handler
    


    mov ah, 0x3
    mov bh, 0x0
    int 10h
    
    mov ah, 0x02
    mov bh, 0x0
    mov dl, 0x0
    int 10h

    mov AH, 09h
    mov AL, 0x30 ; character
    mov BL, 43h
    mov BH, 0 ; page number
    mov CX, 5 ; count
    int 10h


    

    add dl, 5
    mov ah, 0x02
    mov bh, 0x0
    int 10h

    mov si, hello_world_msg1
    call puts
    
    hlt


.keyboard_handler:
    mov ah, 0Fh
    int 10h

    mov ah, 0x03
   ; mov bh, 0x0
    int 10h
    

    pop ax
    mov AH, 09h
    mov BL, 43h
 ;   mov BH, 0 ; page number
    mov CX, 1 ; count
    int 10h
jmp .continue
    cmp dl, 256
    jne .add_column
.new_line:
    add dh, 1
    mov dl, 0
    jmp .continue
.add_column:
    add dl, 1

.continue:
add dx, 1
    mov ah, 0x02
   ; mov bh, 0x0
    int 10h
    jmp main



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




hello_world_msg1: db `Hello from kernel.\0`, 0