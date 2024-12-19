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
column_cells: 	equ 67 ; set to any (reasonable) value you wish
array_length:	equ row_cells * column_cells + row_cells ; cells are mapped to bytes in the array and a new line char ends each row
BLOCK_WIDTH equ 4        ; Ancho de cada bloque
BLOCK_SPACING equ 1      ; Espacio entre bloques

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
	pallet_position dq board + 34 + 27 * (column_cells +2)
	pallet_size dq 3

	ball_x_pos: dq 34
	ball_y_pos: dq 26
    ball_dir_x dq 1
    ball_dir_y dq 1
    ball_counter dq 0        ; Contador actual
    ball_move dq 40          ; Límite para mover la pelota (ajustar este valor para cambiar la velocidad)


	block_chars: db 'OOOUUUOOO', 0  ; Secuencia de bloques
    block_shape db "####"    ; Forma del bloque
    block_empty db "    "    ; Espacio vacío del mismo ancho que un bloque

    ; Estado de los bloques (1=presente, 0=destruido)
    blocks_state: times (13 * 6) db 1  ; 13 columnas x 6 filas
    board_buffer: times (row_cells * (column_cells + 2)) db ' '  ; Buffer para el tablero

   
    ; Añadir constantes para los bloques
    BLOCK_START_ROW equ 5      ; Fila donde empiezan los bloques
    BLOCK_ROWS equ 6           ; Número de filas de bloques
    BLOCKS_PER_ROW equ 13      ; Bloques por fila

    ; Posiciones iniciales para reiniciar
    initial_ball_x dq 34    ; Posición X inicial de la bola
    initial_ball_y dq 26    ; Posición Y inicial de la bola
    initial_pallet_pos dq board + 34 + 27 * (column_cells +2)  ; Posición inicial de la paleta

section .text

clear_board:
    push rbx
    push rcx
    push rdx
    
    ; Limpiar solo el área interna del tablero
    mov r8, 1                      ; Empezar desde la segunda fila
.clear_row:
    cmp r8, row_cells-1
    jge .done
    
    ; Calcular posición inicial de la fila
    mov rax, column_cells + 2
    mul r8
    lea rdi, [board + rax + 1]     ; +1 para saltar el borde izquierdo
    
    ; Limpiar la fila actual
    mov rcx, column_cells - 2      ; -2 para respetar los bordes
    mov al, ' '
    rep stosb
    
    inc r8
    jmp .clear_row

.done:
    pop rdx
    pop rcx
    pop rbx
    ret
    
;	Function: print_ball
; This function displays the position of the ball
; Arguments: none
;
; Return:
;	Void
print_ball:
    push rbx
    push rcx
    
    ; Calcular la posición exacta en el tablero
    mov r8, [ball_y_pos]
    mov r9, [ball_x_pos]
    
    ; Calcular el offset en el tablero
    mov rax, column_cells + 2
    mul r8
    add rax, r9
    
    ; Colocar la pelota en la posición correcta
    add rax, board
    mov byte [rax], char_O
    
    pop rcx
    pop rbx
    ret

reset_positions:
    push rbx
    push rcx
    
    ; Reiniciar posición de la bola
    mov rax, [initial_ball_x]
    mov [ball_x_pos], rax
    mov rax, [initial_ball_y]
    mov [ball_y_pos], rax
    
    ; Reiniciar dirección de la bola (hacia arriba)
    mov rax, 1
    neg rax
    mov [ball_dir_y], rax   ; Dirección Y negativa (hacia arriba)
    mov rax, 1
    mov [ball_dir_x], rax   ; Dirección X positiva
    
    ; Reiniciar posición de la paleta
    mov rax, [initial_pallet_pos]
    mov [pallet_position], rax
    
    ; Reiniciar contador de la bola
    mov qword [ball_counter], 0
    
    pop rcx
    pop rbx
    ret

; Modificar la función move_ball para incluir movimiento y colisiones
; Función para mover la pelota y manejar colisiones
; Función para mover la pelota y manejar todas las colisiones
move_ball:
    ; Comprobar colisión con bloques primero
    movzx rax, byte [ball_y_pos]
    sub eax, BLOCK_START_ROW      ; Ajustar para región de bloques
    cmp rax, 0
    jl .check_paddle              ; Si está fuera de región de bloques, verificar paleta
    cmp rax, BLOCK_ROWS
    jge .check_paddle
    
    ; Calcular índice del bloque
    push rax                      ; Guardar fila actual
    movzx rcx, byte [ball_x_pos]
    sub ecx, 1
    mov eax, ecx
    xor edx, edx
    mov ebx, BLOCK_WIDTH + 1      ; +1 por el espacio entre bloques
    div ebx
    
    cmp eax, BLOCKS_PER_ROW
    jge .check_paddle_pop
    
    pop rbx                       ; Recuperar fila
    push rax                      ; Guardar columna
    
    mov rax, rbx
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    pop rcx
    add rax, rcx
    
    ; Verificar si hay un bloque
    cmp byte [blocks_state + rax], 1
    jne .check_paddle
    
    ; Destruir bloque y rebotar
    mov byte [blocks_state + rax], 0
    neg byte [ball_dir_y]
    jmp .move_x

.check_paddle_pop:
    pop rax

.check_paddle:
    ; Verificar colisión con la paleta
    movzx rax, byte [ball_y_pos]
    cmp rax, 27                  ; Altura de la paleta
    jne .move_x
    
    movzx rcx, byte [ball_x_pos]
    mov rdx, [pallet_position]
    sub rdx, board
    sub rdx, 27 * (column_cells + 2)  ; Ajustar posición relativa
    
    cmp rcx, rdx
    jl .move_x
    
    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .move_x
    
    neg byte [ball_dir_y]        ; Rebotar en la paleta

.move_x:
    movzx rax, byte [ball_x_pos] ; Obtener posición X actual
    movsx rbx, byte [ball_dir_x] ; Obtener dirección X
    add rax, rbx                 ; Calcular nueva posición X
    
    ; Verificar límites X
    cmp rax, 1                   ; Verificar límite izquierdo
    jle .bounce_x
    cmp rax, column_cells-2      ; Verificar límite derecho
    jge .bounce_x
    mov [ball_x_pos], al         ; Actualizar posición X si no hay colisión
    jmp .move_y

.bounce_x:
    neg byte [ball_dir_x]        ; Invertir dirección X
    movzx rax, byte [ball_x_pos]
    movsx rbx, byte [ball_dir_x]
    add rax, rbx
    mov [ball_x_pos], al

.move_y:
    movzx rax, byte [ball_y_pos] ; Obtener posición Y actual
    movsx rbx, byte [ball_dir_y] ; Obtener dirección Y
    add rax, rbx                 ; Calcular nueva posición Y
    
    ; Verificar límites Y
    cmp rax, 1                   ; Verificar límite superior
    jle .bounce_y
    cmp rax, row_cells-2        ; Verificar límite inferior
    je .reset_game
    mov [ball_y_pos], al         ; Actualizar posición Y si no hay colisión
    ret

.bounce_y:
    neg byte [ball_dir_y]        ; Invertir dirección Y
    movzx rax, byte [ball_y_pos]
    movsx rbx, byte [ball_dir_y]
    add rax, rbx
    mov [ball_y_pos], al
    ret

.reset_game:
    call reset_positions         ; Llamar a función de reinicio
    ret

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
        ; Verificar si hay una X en la siguiente posición a la izquierda
        cmp byte [r8-1], 'X'
        je .end                ; Si hay una X, no mover
        mov r9, [pallet_size]
        mov byte [r8 + r9 - 1], char_space
        dec r8
        mov [pallet_position], r8
        jmp .end
    .move_right:
        mov r8, [pallet_position]
        mov r9, [pallet_size]
        ; Verificar si hay una X en la siguiente posición después de la paleta
        cmp byte [r8 + r9], 'X'
        je .end                ; Si hay una X, no mover
        mov byte [r8], char_space
        inc r8
        mov [pallet_position], r8
    .end:
    ret

; Funcion: Dibujar bloques
draw_blocks_m:
    push rbx
    push rdx

    mov r8, board
    mov rax, column_cells + 2    ; +2 por los saltos de línea
    mov rbx, BLOCK_START_ROW
    mul rbx
    add r8, rax                  ; r8 ahora apunta a la fila inicial de bloques
    add r8, 1                    ; Ajustar por el borde izquierdo
    
    mov r10, BLOCK_ROWS         ; Contador de filas (6)

.loop_rows:
    cmp r10, 0
    je .blocks_done

    mov r11, BLOCKS_PER_ROW     ; Contador de columnas (13)
    push r8                     ; Guardar posición inicial de la fila

.loop_columns:
    cmp r11, 0
    je .next_row

    ; Calcular índice del bloque
    mov rax, BLOCK_ROWS
    sub rax, r10               ; Obtener fila actual (0-5)
    mov rbx, BLOCKS_PER_ROW
    mul rbx                    ; rax = fila * bloques_por_fila
    add rax, BLOCKS_PER_ROW
    sub rax, r11              ; Añadir columna actual
    
    ; Verificar si el bloque existe
    cmp byte [blocks_state + rax], 1
    jne .draw_empty

    ; Dibujar bloque ####
    mov rcx, BLOCK_WIDTH
.draw_block_chars:
    mov byte [r8], '#'
    inc r8
    dec rcx
    jnz .draw_block_chars
    jmp .after_block

.draw_empty:
    ; Dibujar espacio vacío
    mov rcx, BLOCK_WIDTH
.draw_empty_chars:
    mov byte [r8], ' '
    inc r8
    dec rcx
    jnz .draw_empty_chars

.after_block:
    ; Añadir espacio entre bloques
    cmp r11, 1                ; Si no es el último bloque
    je .skip_space
    mov byte [r8], ' '        ; Añadir espacio
    inc r8

.skip_space:
    dec r11
    jmp .loop_columns

.next_row:
    pop r8                    ; Recuperar inicio de la fila
    add r8, column_cells + 2  ; Avanzar a la siguiente fila
    dec r10
    jmp .loop_rows

.blocks_done:
    pop rdx
    pop rbx
    ret

check_block_collision:
    push rbx
    push rcx
    push rdx

    ; Obtener posición Y de la pelota
    mov rax, [ball_y_pos]
    sub rax, BLOCK_START_ROW
    cmp rax, 0
    jl .no_collision
    cmp rax, BLOCK_ROWS
    jge .no_collision

    ; Calcular índice del bloque
    mov rbx, BLOCKS_PER_ROW
    mul rbx                    ; rax = fila * bloques_por_fila
    
    ; Obtener posición X y calcular columna
    mov rcx, [ball_x_pos]
    sub rcx, 1                ; Ajustar por el borde izquierdo
    mov rax, rcx
    mov rbx, BLOCK_WIDTH + BLOCK_SPACING
    xor rdx, rdx
    div rbx                   ; Dividir por (ancho_bloque + espacio)
    
    cmp rax, BLOCKS_PER_ROW
    jge .no_collision
    
    ; Calcular índice final del bloque
    mov rbx, [ball_y_pos]
    sub rbx, BLOCK_START_ROW
    imul rbx, BLOCKS_PER_ROW
    add rax, rbx
    
    ; Verificar si hay un bloque
    cmp byte [blocks_state + rax], 1
    jne .no_collision

    ; Destruir el bloque
    mov byte [blocks_state + rax], 0
    
    ; Hacer que la pelota rebote
    neg qword [ball_dir_y]

.no_collision:
    pop rdx
    pop rcx
    pop rbx
    ret


_start:
	call canonical_off
	print clear, clear_length
	call start_screen


	.main_loop:
        ; Incrementar contador de la pelota
        inc qword [ball_counter]
        mov rax, [ball_counter]
        cmp rax, [ball_move]
        jl .skip_ball_move
    
        ; Reiniciar contador y mover pelota
        mov qword [ball_counter], 0
        call move_ball

    .skip_ball_move:
        ; Limpiar la posición anterior de la pelota
        print clear, clear_length
        call clear_board
        
        call draw_blocks_m
		call print_pallet
		call print_ball
		print board, board_size

		getchar

		cmp rax, 1
    	jne .done

		mov al,[input_char]

		cmp al, 'a'
	    je .move_left2
        cmp al, 'd'
	    je .move_right2
        cmp al, 'q'
        je exit
        jmp .done

    .move_left2:
	    mov rdi, left_direction
		call move_pallet
	    jmp .done

	.move_right2:
		mov rdi, right_direction
	    call move_pallet

	.done:
		sleeptime
    	jmp .main_loop
		

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
