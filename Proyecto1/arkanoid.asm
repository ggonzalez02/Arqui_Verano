bits 64
default rel


; Here comes the defines
sys_read: equ 0
sys_write:	equ 1
sys_nanosleep:	equ 35
sys_time:	equ 201
sys_fcntl:	equ 72


STDIN_FILENO: equ 0

F_SETFL:	equ 0x0004
O_NONBLOCK: equ 0x0004

;screen clean definition
row_cells:	equ 32	; set to any (reasonable) value you wish
column_cells: 	equ 54 ; set to any (reasonable) value you wish
array_length:	equ row_cells * column_cells + row_cells ; cells are mapped to bytes in the array and a new line char ends each row

;This is regarding the sleep time
timespec:
    tv_sec  dq 0
    tv_nsec dq 2000000


;This is for cleaning up the screen
clear:		db 27, "[2J", 27, "[H"
clear_length:	equ $-clear



; Start Message
msg1: db "        TECNOLOGICO DE COSTA RICA        ", 0xA, 0xD
msg2: db "        MARICRUZ CAMPOS      GABRIEL GONZALEZ        ", 0xA, 0xD
msg3: db "        PROFESOR: ERNESTO RIVERA ALVARADO        ", 0xA, 0xD
msg4: db "        ARQUITECTURA DE COMPUTADORAS        ", 0xA, 0xD
msg5: db "        PROYECTO 1: ARKANOID         ", 0xA, 0xD
msg6: db "        INSTRUCCIONES: PRESIONE A PARA MOVERSE A LA IZQUIERDA Y D PARA MOVERSE A LA DERECHA   ", 0xA, 0xD
msg7: db "        PRESIONE ENTER PARA INICIAR        ", 0xA, 0xD
msg8: db "        PRESIONE Q PARA SALIR        ", 0xA, 0xD
msg1_length:	equ $-msg1
msg2_length:	equ $-msg2
msg3_length:	equ $-msg3
msg4_length:	equ $-msg4
msg5_length:	equ $-msg5
msg6_length:	equ $-msg6
msg7_length:	equ $-msg7
msg8_length:	equ $-msg8

; Usefull macros



%macro setnonblocking 0
	mov rax, sys_fcntl
    mov rdi, STDIN_FILENO
    mov rsi, F_SETFL
    mov rdx, O_NONBLOCK
    syscall
%endmacro

%macro unsetnonblocking 0
	mov rax, sys_fcntl
    mov rdi, STDIN_FILENO
    mov rsi, F_SETFL
    mov rdx, 0
    syscall
%endmacro

%macro full_line 0
    times column_cells db "X"
    db 0x0a, 0xD
%endmacro

%macro hollow_line 0
    db "X"
    times column_cells-2 db " "
    db "X", 0x0a, 0xD
%endmacro


%macro print 2
	mov eax, sys_write
	mov edi, 1 	; stdout
	mov rsi, %1
	mov edx, %2
	syscall
%endmacro

%macro getchar 0
	mov     rax, sys_read
    mov     rdi, STDIN_FILENO
    mov     rsi, input_char
    mov     rdx, 1 ; number of bytes
    syscall         ;read text input from keyboard
%endmacro

%macro sleeptime 0
	mov eax, sys_nanosleep
	mov rdi, timespec
	xor esi, esi		; ignore remaining time in case of call interruption
	syscall			; sleep for tv_sec seconds + tv_nsec nanoseconds
%endmacro



global _start

section .bss

input_char: resb 1

section .data

	board:
		full_line
        %rep 30
        hollow_line
        %endrep
        full_line
	board_size:   equ   $ - board

	; Added for the terminal issue
	termios:        times 36 db 0
	stdin:          equ 0
	ICANON:         equ 1<<1
	ECHO:           equ 1<<3
	VTIME: 			equ 5
	VMIN:			equ 6
	CC_C:			equ 18

section .text
;;;;;;;;;;;;;;;;;;;;for the working of the terminal;;;;;;;;;;;;;;;;;
canonical_off:
        call read_stdin_termios

        ; clear canonical bit in local mode flags
        push rax
        mov eax, ICANON
        not eax
        and [termios+12], eax
		mov byte[termios+CC_C+VTIME], 0
		mov byte[termios+CC_C+VMIN], 0
        pop rax

        call write_stdin_termios
        ret

echo_off:
        call read_stdin_termios

        ; clear echo bit in local mode flags
        push rax
        mov eax, ECHO
        not eax
        and [termios+12], eax
        pop rax

        call write_stdin_termios
        ret

canonical_on:
        call read_stdin_termios

        ; set canonical bit in local mode flags
        or dword [termios+12], ICANON
		mov byte[termios+CC_C+VTIME], 0
		mov byte[termios+CC_C+VMIN], 1
        call write_stdin_termios
        ret

echo_on:
        call read_stdin_termios

        ; set echo bit in local mode flags
        or dword [termios+12], ECHO

        call write_stdin_termios
        ret

read_stdin_termios:
        push rax
        push rbx
        push rcx
        push rdx

        mov eax, 36h
        mov ebx, stdin
        mov ecx, 5401h
        mov edx, termios
        int 80h

        pop rdx
        pop rcx
        pop rbx
        pop rax
        ret

write_stdin_termios:
        push rax
        push rbx
        push rcx
        push rdx

        mov eax, 36h
        mov ebx, stdin
        mov ecx, 5402h
        mov edx, termios
        int 80h

        pop rdx
        pop rcx
        pop rbx
        pop rax
        ret

;;;;;;;;;;;;;;;;;;;;end for the working of the terminal;;;;;;;;;;;;

char_equal: equ 61
char_space: equ 32
char_O: equ 79
left_direction: equ -1
right_direction: equ 1


section .data
	pallet_position dq board + 25 + 28 * (column_cells +2)
	pallet_size dq 3

	ball_x_pos: dq 26
	ball_y_pos: dq 27

	; Bloques 
	block1: db 'OOOO', 0
	block2: db 'UUUU', 0


section .text

;	Function: print_ball
; This function displays the position of the ball
; Arguments: none
;
; Return:
;	Void
print_ball:
	mov r8, [ball_x_pos]
	mov r9, [ball_y_pos]
	add r8, board

	mov rcx, r9
	mov rax, column_cells + 2
	imul rcx

	add r8, rax
	mov byte [r8], char_O
	ret


	;mov rax, board + r8 + r9 * (column_cells + 2)


;	Function: print_pallet
; This function moves the pallet in the game
; Arguments: none
;
; Return;
;	void
print_pallet:
	mov r8, [pallet_position]
	mov rcx, [pallet_size]
	.write_pallet:
		mov byte [r8], char_equal
		inc r8
		dec rcx
		jnz .write_pallet

	ret

;	Function: move_pallet
; This function is in charge of moving the pallet in a given direction
; Arguments:
;	rdi: left direction or right direction
;
; Return:
;	void
move_pallet:
	cmp rdi, left_direction
	jne .move_right
	.move_left:
		mov r8, [pallet_position]
		mov r9, [pallet_size]
		mov byte [r8 + r9 - 1], char_space
		dec r8
		mov [pallet_position], r8
		jmp .end
	.move_right:
		mov r8, [pallet_position]
		mov byte [r8], char_space
		inc r8
		mov [pallet_position], r8
	.end:
	ret

; Funcion: Dibujar bloques
draw_blocks_m:
	push rbx
	push rdx
	push r12
	push r13

	mov r8, board 
	add r8, (column_cells + 3)*6  
	sub r8, 5                         ; Iniciar 6 filas debajo del limite superior
	mov r10, 6                        ; Filas
	lea r12, [block1]      		  ; Guarda la direccion de memoria del bloque 1
	lea r13, [block2]                 ; Guarda la direccion de memoria del bloque 2
	xor rbx, rbx                      ; Para alternar entre bloque 1 y bloque 2

.loop_rows:
    cmp r10, 0
    je .blocks_done

    mov r11, 13                       ; Columnas
    push r8                           ; Posicion inicial de la fila

.loop_columns:
    cmp r11, 0
    je .next_row
	test rbx, 1						  ; Si el resultado es 0 dibuja el bloque 1, si es 1 dibuja el bloque 2
	jz .draw_block1

.draw_block2:
    mov rsi, r13              		  ; Usa bloque 2 (UUUU)
    jmp .draw_block

.draw_block1:
    mov rsi, r12                      ; Usa bloque 1 (OOOO)

.draw_block:
    mov rcx, 4                        ; Contador para los 4 caracteres

.draw_chars:
    mov al, byte [rsi]                ; Copia un caracter del bloque
    mov byte [r8], al				  ; Copia el caracter a la posicion del tablero
    inc rsi							  
    inc r8
    dec rcx
    jnz .draw_chars					  ; Repite hasta que se dibujen todos los caracteres

    not rbx                  		  ; Cambiar el bloque para la siguiente iteracion
    dec r11
    jmp .loop_columns

.next_row:
    pop r8                            ; Recupera la posicion inicial de la fila
    add r8, column_cells + 2          ; Avanza a la siguiente fila
    dec r10
    jmp .loop_rows

.blocks_done:
    pop r13
    pop r12
    pop rdx
    pop rbx
    ret


_start:
	call canonical_off
	print clear, clear_length
	call start_screen


	.main_loop:
		call print_pallet
		call print_ball
		call draw_blocks_m
		print board, board_size
		;setnonblocking
	.read_more:
		getchar

		cmp rax, 1
    	jne .done

		mov al,[input_char]

		cmp al, 'a'
	    jne .not_left
	    mov rdi, left_direction
		call move_pallet
	    jmp .done

		.not_left:
		 	cmp al, 'd'
	    	jne .not_right
			mov rdi, right_direction
	    	call move_pallet
    		jmp .done

		.not_right:

    		cmp al, 'q'
    		je exit

			jmp .read_more

		.done:
			;unsetnonblocking
			sleeptime
			print clear, clear_length
    		jmp .main_loop

		print clear, clear_length

		jmp exit


start_screen:

	call canonical_on
	print msg1, msg1_length
	getchar
	call canonical_off
	print clear, clear_length
	ret

exit:
	call canonical_on
	mov    rax, 60
    mov    rdi, 0
    syscall
