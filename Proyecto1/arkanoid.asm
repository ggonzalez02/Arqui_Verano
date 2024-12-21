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
POWER_SHOOT equ 1        ; Tipo de power-up de disparo
POWER_LIFE equ 2         ; Tipo de power-up de vida extra
POWER_BALLS equ 3         ; Tipo de power-up de bolas extra
POWER_STICKY equ 4 

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
msg7: db "        PRESIONE ENTER PARA INICIAR Y ESPACIO PARA LANZAR LA PELOTA O DISPARAR       ", 0xA, 0xD
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
	push rax            ; Guardar registros que vamos a usar
    push rdi
    push rsi
    push rdx
    push rcx           ; Añadido rcx a los registros guardados
    
    mov rax, sys_write ; sys_write
    mov rdi, 1         ; stdout
    mov rsi, %1        ; primer parámetro - dirección del texto
    mov rdx, %2        ; segundo parámetro - longitud
    syscall
    
    pop rcx            ; Restaurar registros en orden inverso
    pop rdx
    pop rsi
    pop rdi
    pop rax
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
    num_buffer: resb 32    ; Buffer más grande para seguridad
    score_buffer: resb 32
    level_buffer: resb 32
    lives_buffer: resb 32

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
    game_started dq 0    ; 0 = waiting for space, 1 = game in progress
	pallet_position dq board + 34 + 27 * (column_cells +2)
	pallet_size dq 3

	ball_x_pos: dq 34
	ball_y_pos: dq 26
    ball_dir_x dq 1
    ball_dir_y dq -1
    ball_counter dq 0        ; Contador actual
    ball_move dq 100          ; Límite para mover la pelota (ajustar este valor para cambiar la velocidad)

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

    score: dq 0          ; Puntaje inicial
    level: dq 1          ; Nivel inicial
    lives: dq 5          ; Vidas iniciales

    cursor_up db 27, "[20A"
    cursor_right db 27, "[75C"
    new_line db 10, 13

    ; Textos
    score_text db "PUNTAJE: "
    score_length equ $ - score_text
    level_text db "NIVEL: "
    level_length equ $ - level_text
    lives_text db "VIDAS: "
    lives_length equ $ - lives_text

    ; Estados de power-ups
    has_shooting dq 0          ; Estado del power-up de disparo
    bullet_active_left dq 0    ; Estado de la bala izquierda
    bullet_active_right dq 0   ; Estado de la bala derecha
    bullet_x_left dq 0        ; Posición X de la bala izquierda
    bullet_y_left dq 0        ; Posición Y de la bala izquierda
    bullet_x_right dq 0       ; Posición X de la bala derecha
    bullet_y_right dq 0       ; Posición Y de la bala derecha
    bullet_char db '^'        ; Carácter para la bala
    ; Variables temporales para check_bullet_collision
    bullet_x dq 0            ; Variable temporal para colisiones
    bullet_y dq 0            ; Variable temporal para colisiones
    bullet_active dq 0       ; Variable temporal para colisiones
    powerup_spawn_rate dq 20   ; Probabilidad de spawn de power-up (ajustar según necesidad)
    powerup_duration dq 2500   ; Duración del power-up (5 segundos: 2500 ciclos * 2ms = 5000ms)
    powerup_timer dq 0         ; Temporizador para el power-up actual
    powerup_x dq 0            ; Posición X del power-up cayendo
    powerup_y dq 0            ; Posición Y del power-up cayendo
    powerup_active dq 0        ; Si hay un power-up cayendo
    powerup_char db 'S'       ; Carácter para el power-up de disparo
    powerup_life_char db 'L'  ; Carácter para el power-up de vida extra
    powerup_type dq 0         ; 0 = ninguno, 1 = disparo, 2 = vida extra
    auto_shoot_timer dq 0      ; Temporizador para el disparo automático
    auto_shoot_rate dq 20      ; Frecuencia de disparo automático
    blocks_destroyed dq 0      ; Contador de bloques destruidos
    blocks_for_powerup dq 3    ; Número de bloques que hay que destruir para que aparezca un power-up
    random_seed dq 12345      ; Semilla para generación de números aleatorios
    powerup_balls_char db 'B'    ; Carácter para el power-up de bolas extra
    active_balls_count dq 1   ; Contador de bolas activas (empieza con 1, la bola principal)
    ball_active dq 1
    powerup_sticky_char db 'P'       ; Carácter para el power-up sticky
    has_sticky dq 0                  ; Estado del power-up sticky
    ball_stuck dq 0                  ; Indica si la bola está pegada a la paleta

    ; Variables para las bolas extra
    ball2_x_pos: dq 34
    ball2_y_pos: dq 26
    ball2_dir_x dq 1
    ball2_dir_y dq -1
    ball2_active dq 0
    
    ball3_x_pos: dq 34
    ball3_y_pos: dq 26
    ball3_dir_x dq -1
    ball3_dir_y dq -1
    ball3_active dq 0
    
    ; Ajustar la velocidad de caída de power-ups
    powerup_fall_rate dq 2000 

section .text

generate_random:
    push rdx
    mov rax, [random_seed]
    mov rdx, 1103515245
    mul rdx
    add rax, 12345
    mov [random_seed], rax
    shr rax, 16
    and rax, 0x7FFF
    pop rdx
    ret

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
    ; Imprimir bola principal
    mov r8, [ball_y_pos]
    mov r9, [ball_x_pos]
    mov rax, column_cells + 2
    mul r8
    add rax, r9
    add rax, board
    mov byte [rax], char_O
    
    ; Imprimir segunda bola si está activa
    cmp qword [ball2_active], 0
    je .check_ball3
    mov r8, [ball2_y_pos]
    mov r9, [ball2_x_pos]
    mov rax, column_cells + 2
    mul r8
    add rax, r9
    add rax, board
    mov byte [rax], char_O
    
.check_ball3:
    ; Imprimir tercera bola si está activa
    cmp qword [ball3_active], 0
    je .done
    mov r8, [ball3_y_pos]
    mov r9, [ball3_x_pos]
    mov rax, column_cells + 2
    mul r8
    add rax, r9
    add rax, board
    mov byte [rax], char_O
    
.done:
    ret

reset_positions:
    push rbx
    push rcx

    call deactivate_all_powerups 
    
    ; Calcular posición inicial de la bola sobre la paleta
    mov rax, [pallet_position]
    sub rax, board                    ; Obtener offset desde inicio del tablero
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx                          ; rax = fila, rdx = columna
    
    ; Establecer Y una fila arriba de la paleta
    mov [ball_y_pos], rax
    dec qword [ball_y_pos]
    
    ; Calcular X para centrar sobre la paleta
    mov rax, rdx                     ; Usar la columna original
    add rax, 1                       ; Ajustar para centrar
    mov [ball_x_pos], rax
    
    ; Establecer direcciones iniciales
    mov qword [ball_dir_y], -1       ; Irá hacia arriba cuando comience
    mov qword [ball_dir_x], 1        ; Irá hacia la derecha cuando comience
    mov qword [ball_active], 1
    mov qword [game_started], 0
    
    ; Reiniciar bolas extra
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    
    ; Reiniciar contador
    mov qword [ball_counter], 0
    
    pop rcx
    pop rbx
    ret

; Modificar la función move_ball para incluir movimiento y colisiones
; Función para mover la pelota y manejar colisiones
; Función para mover la pelota y manejar todas las colisiones
move_ball:
    cmp qword [ball_stuck], 1
    je .follow_paddle
    ; Verificar si el juego ha comenzado
    cmp qword [game_started], 0
    je .follow_paddle
    
    ; Verificar si la bola está activa
    cmp qword [ball_active], 0
    je .done

    ; Comprobar colisión con bloques primero
    movzx rax, byte [ball_y_pos]
    sub eax, BLOCK_START_ROW      
    cmp rax, 0
    jl .check_walls              
    cmp rax, BLOCK_ROWS
    jge .check_walls
    
    ; Calcular índice del bloque
    push rax                      
    movzx rcx, byte [ball_x_pos]
    sub ecx, 1
    mov eax, ecx
    xor edx, edx
    mov ebx, BLOCK_WIDTH + 1      
    div ebx
    
    cmp eax, BLOCKS_PER_ROW
    jge .check_walls_pop
    
    pop rbx                       
    push rax                      
    
    mov rax, rbx
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    pop rcx
    add rax, rcx
    
    ; Verificar si hay un bloque y actualizarlo
    cmp byte [blocks_state + rax], 1
    jne .check_walls
    
    push rax                        
    call handle_block_destruction   
    pop rax
    
    neg byte [ball_dir_y]          
    jmp .check_walls

.check_walls_pop:
    pop rax

.check_walls:
    ; Mover en X
    movzx rax, byte [ball_x_pos]
    movsx rbx, byte [ball_dir_x]
    add rax, rbx

    ; Verificar colisiones en X
    cmp rax, 1
    jle .bounce_x
    cmp rax, column_cells-1
    jge .bounce_x
    mov [ball_x_pos], al
    jmp .move_y

.bounce_x:
    neg byte [ball_dir_x]
    movzx rax, byte [ball_x_pos]
    movsx rbx, byte [ball_dir_x]
    add rax, rbx
    mov [ball_x_pos], al

.move_y:
    movzx rax, byte [ball_y_pos]
    movsx rbx, byte [ball_dir_y]
    add rax, rbx

    ; Verificar colisiones en Y
    cmp rax, 1
    jle .bounce_y
    cmp rax, row_cells-1
    jge .ball_lost
    mov [ball_y_pos], al
    
    ; Verificar colisión con la paleta
    cmp rax, 27
    jne .done
    
    movzx rcx, byte [ball_x_pos]
    mov rdx, [pallet_position]
    sub rdx, board
    sub rdx, 27 * (column_cells + 2)
    
    cmp rcx, rdx
    jl .done
    
    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .done
    
    ; Aquí es donde añadimos la lógica del sticky power-up
    cmp qword [has_sticky], 1
    jne .regular_bounce
    mov qword [ball_stuck], 1
    mov qword [game_started], 0
    jmp .done

.regular_bounce:
    neg byte [ball_dir_y]
    jmp .done

.bounce_y:
    neg byte [ball_dir_y]
    movzx rax, byte [ball_y_pos]
    movsx rbx, byte [ball_dir_y]
    add rax, rbx
    mov [ball_y_pos], al
    jmp .done

.ball_lost:
    mov qword [ball_active], 0
    dec qword [active_balls_count]
    
    cmp qword [active_balls_count], 0
    jg .done
    
    dec qword [lives]
    mov rax, [lives]
    test rax, rax
    jz exit
    
    call reset_positions
    mov qword [ball_active], 1
    mov qword [active_balls_count], 1
    jmp .done

.follow_paddle:
    ; Si la bola está pegada o el juego no ha comenzado, mantener sobre la paleta
    mov rax, [pallet_position]
    sub rax, board
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx
    mov [ball_y_pos], rax
    dec qword [ball_y_pos]
    
    mov rax, rdx
    add rax, 1
    mov [ball_x_pos], rax

.done:
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

write_score:
    push rcx
.write_loop:
    mov al, [rsi]
    mov [r8], al
    inc rsi
    inc r8
    dec rcx
    jnz .write_loop
    pop rcx
    ret

number_to_string:
    ; rax = número a convertir
    ; rdi = buffer destino
    push rbx
    push rdx
    push rsi
    
    mov rsi, rdi        ; Guardar puntero al buffer
    add rdi, 30         ; Ir casi al final del buffer
    mov byte [rdi], 0   ; Null terminator
    mov rbx, 10
    
    ; Si el número es 0, manejarlo especialmente
    test rax, rax
    jnz .convert
    dec rdi
    mov byte [rdi], '0'
    jmp .done

.convert:
    ; Convertir número
    test rax, rax
    jz .done
    xor rdx, rdx
    div rbx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    jmp .convert

.done:
    ; Mover al inicio del buffer
    mov rcx, rsi
.copy:
    mov al, [rdi]
    mov [rcx], al
    inc rdi
    inc rcx
    cmp byte [rdi-1], 0
    jne .copy
    
    pop rsi
    pop rdx
    pop rbx
    ret

; Función actualizada para imprimir la información del juego
print_game_info:
    push rax
    push rbx
    push rcx
    push rdx

    ; PUNTAJE
    print cursor_up, 3
    print cursor_right, 5
    print score_text, score_length
    
    mov rax, [score]
    mov rdi, num_buffer
    call number_to_string
    
    ; Calcular longitud
    mov rcx, 0
    mov rdi, num_buffer
.count1:
    cmp byte [rdi + rcx], 0
    je .print1
    inc rcx
    jmp .count1
.print1:
    print num_buffer, rcx
    print new_line, 2
    
    ; NIVEL
    print cursor_right, 5
    print level_text, level_length
    
    mov rax, [level]
    mov rdi, num_buffer
    call number_to_string
    
    mov rcx, 0
    mov rdi, num_buffer
.count2:
    cmp byte [rdi + rcx], 0
    je .print2
    inc rcx
    jmp .count2
.print2:
    print num_buffer, rcx
    print new_line, 2
    
    ; VIDAS
    print cursor_right, 5
    print lives_text, lives_length
    
    mov rax, [lives]
    mov rdi, num_buffer
    call number_to_string
    
    mov rcx, 0
    mov rdi, num_buffer
.count3:
    cmp byte [rdi + rcx], 0
    je .print3
    inc rcx
    jmp .count3
.print3:
    print num_buffer, rcx
    print new_line, 2
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Función compartida para manejar la destrucción de bloques y spawn de power-ups
handle_block_destruction:
     ; rax debe contener el índice del bloque
    mov byte [blocks_state + rax], 0   ; Destruir el bloque
    add qword [score], 1               ; Incrementar score
    inc qword [blocks_destroyed]       ; Incrementar contador de bloques destruidos
    
    mov r10, rax                       ; Guardar el índice del bloque
    
    ; Solo generar power-up si no hay uno activo
    cmp qword [powerup_active], 1
    je .no_spawn
    
    ; Generar power-up cada 3 bloques destruidos
    mov rax, [blocks_destroyed]
    mov rcx, 3
    xor rdx, rdx
    div rcx
    test rdx, rdx     
    jnz .no_spawn
    
    ; Calcular posición del power-up
    mov rax, r10                      
    mov rcx, BLOCKS_PER_ROW
    xor rdx, rdx
    div rcx                           
    
    add rax, BLOCK_START_ROW
    mov [powerup_y], rax
    
    mov rax, rdx
    mov rcx, BLOCK_WIDTH + BLOCK_SPACING
    mul rcx
    add rax, 2                        
    mov [powerup_x], rax
    
    ; Elegir tipo de power-up aleatoriamente (ahora incluye sticky)
    call generate_random
    and rax, 3                        ; 0-3
    inc rax                           ; 1-4
    mov [powerup_type], rax
    
    mov qword [powerup_active], 1

.no_spawn:
    ret

; Función para desactivar todos los power-ups
deactivate_all_powerups:
    mov qword [has_shooting], 0
    mov qword [has_sticky], 0
    mov qword [ball_stuck], 0
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    ret

; Función para activar el power-up de disparo
activate_shooting:
    mov qword [has_shooting], 1
    mov rax, [powerup_duration]    ; Primero movemos el valor a un registro
    mov qword [powerup_timer], rax ; Luego lo movemos del registro a la memoria
    ret

; Función para actualizar el temporizador del power-up y el disparo automático
update_powerup_timer:
    ; Actualizar el temporizador del power-up
    cmp qword [powerup_timer], 0
    je .check_auto_shoot
    dec qword [powerup_timer]
    jnz .check_auto_shoot
    mov qword [has_shooting], 0    ; Desactivar power-up cuando el tiempo se acaba
    jmp .done

.check_auto_shoot:
    ; Si no tenemos el power-up activo, no disparar
    cmp qword [has_shooting], 0
    je .done

    ; Incrementar el temporizador de disparo automático
    inc qword [auto_shoot_timer]
    mov rax, [auto_shoot_timer]
    cmp rax, [auto_shoot_rate]
    jl .done

    ; Resetear el temporizador y disparar
    mov qword [auto_shoot_timer], 0
    call shoot_bullet

.done:
    ret

; Función para disparar las balas
shoot_bullet:
    ; Verificar y disparar bala izquierda
    cmp qword [bullet_active_left], 1
    je .check_right
    
    mov qword [bullet_active_left], 1
    ; Posicionar la bala en el extremo izquierdo de la paleta
    mov rax, [pallet_position]
    sub rax, board
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx
    mov [bullet_y_left], rax           ; Y inicial
    
    mov rax, [pallet_position]
    sub rax, board
    mov [bullet_x_left], rax           ; X inicial (borde izquierdo de la paleta)
    xor rdx, rdx
    div rbx                            ; Dividir por ancho de línea para ajustar
    mov [bullet_x_left], rdx           ; Solo mantener el offset dentro de la línea

.check_right:
    ; Verificar y disparar bala derecha
    cmp qword [bullet_active_right], 1
    je .done
    
    mov qword [bullet_active_right], 1
    ; Posicionar la bala en el extremo derecho de la paleta
    mov rax, [pallet_position]
    sub rax, board
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx
    mov [bullet_y_right], rax          ; Y inicial
    
    ; Calcular posición X del borde derecho
    mov rax, [pallet_position]
    sub rax, board
    add rax, [pallet_size]            ; Añadir el tamaño de la paleta
    dec rax                           ; Ajustar para el último carácter
    mov [bullet_x_right], rax         ; X inicial (borde derecho de la paleta)
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx                          ; Dividir por ancho de línea para ajustar
    mov [bullet_x_right], rdx        ; Solo mantener el offset dentro de la línea

.done:
    ret

; Función para actualizar la posición de las balas
update_bullet:
    ; Actualizar bala izquierda
    cmp qword [bullet_active_left], 0
    je .update_right
    
    ; Mover la bala izquierda hacia arriba
    dec qword [bullet_y_left]
    
    ; Verificar colisión con el borde superior
    cmp qword [bullet_y_left], 1
    jle .deactivate_left
    
    ; Verificar colisión con bloques
    mov rax, [bullet_x_left]
    mov [bullet_x], rax
    mov rax, [bullet_y_left]
    mov [bullet_y], rax
    call check_bullet_collision
    jmp .update_right

.deactivate_left:
    mov qword [bullet_active_left], 0

.update_right:
    ; Actualizar bala derecha
    cmp qword [bullet_active_right], 0
    je .done
    
    ; Mover la bala derecha hacia arriba
    dec qword [bullet_y_right]
    
    ; Verificar colisión con el borde superior
    cmp qword [bullet_y_right], 1
    jle .deactivate_right
    
    ; Verificar colisión con bloques
    mov rax, [bullet_x_right]
    mov [bullet_x], rax
    mov rax, [bullet_y_right]
    mov [bullet_y], rax
    call check_bullet_collision
    jmp .done

.deactivate_right:
    mov qword [bullet_active_right], 0

.done:
    ret

; Función para verificar colisión de la bala con bloques
check_bullet_collision:
    push rbx
    push rcx
    push rdx
    
    ; Obtener posición Y de la bala
    mov rax, [bullet_y]
    sub rax, BLOCK_START_ROW
    cmp rax, 0
    jl .no_collision
    cmp rax, BLOCK_ROWS
    jge .no_collision
    
    ; Calcular índice del bloque
    mov rbx, BLOCKS_PER_ROW
    mul rbx
    
    ; Obtener posición X y calcular columna
    mov rcx, [bullet_x]
    sub rcx, 1
    mov rax, rcx
    mov rbx, BLOCK_WIDTH + BLOCK_SPACING
    xor rdx, rdx
    div rbx
    
    cmp rax, BLOCKS_PER_ROW
    jge .no_collision
    
    ; Calcular índice final del bloque
    mov rbx, [bullet_y]
    sub rbx, BLOCK_START_ROW
    imul rbx, BLOCKS_PER_ROW
    add rax, rbx
    
    ; Verificar si hay un bloque
    cmp byte [blocks_state + rax], 1
    jne .no_collision
    
    push rax                        ; Guardar el índice del bloque
    call handle_block_destruction   ; Manejar la destrucción del bloque
    pop rax
    
    mov qword [bullet_active], 0   ; Desactivar la bala
    
.no_collision:
    pop rdx
    pop rcx
    pop rbx
    ret

; Función para manejar la caída del power-up
update_powerup:
    cmp qword [powerup_active], 0
    je .done
    
    ; Mover el power-up hacia abajo más lento
    mov rax, [ball_counter]
    mov rcx, [powerup_fall_rate]    ; Usar la nueva variable de velocidad
    xor rdx, rdx
    div rcx
    test rdx, rdx
    jnz .done
    
    inc qword [powerup_y]
    
    ; Verificar si llegó al fondo
    cmp qword [powerup_y], row_cells-2
    jge .deactivate
    
    ; Verificar colisión con la paleta
    mov rax, [powerup_y]
    cmp rax, 27                  
    jne .done
    
    mov rcx, [powerup_x]
    mov rdx, [pallet_position]
    sub rdx, board
    sub rdx, 27 * (column_cells + 2)
    
    cmp rcx, rdx
    jl .done
    
    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .done

    call deactivate_all_powerups
    
    ; Verificar tipo de power-up
    mov rax, [powerup_type]
    cmp rax, POWER_SHOOT
    je .activate_shoot
    cmp rax, POWER_LIFE
    je .activate_life
    cmp rax, POWER_BALLS
    je .activate_balls
    cmp rax, POWER_STICKY
    je .activate_sticky
    jmp .deactivate

.activate_shoot:
    call activate_shooting
    jmp .deactivate

.activate_life:
    call activate_extra_life
    jmp .deactivate

.activate_balls:
    call activate_extra_balls
    jmp .deactivate

.activate_sticky:
    mov qword [has_sticky], 1
    jmp .deactivate

.deactivate:
    mov qword [powerup_active], 0

.done:
    ret

; Función para dibujar las balas
print_bullet:
    ; Dibujar bala izquierda
    cmp qword [bullet_active_left], 0
    je .print_right
    
    mov rax, [bullet_y_left]
    mov rbx, column_cells + 2
    mul rbx
    add rax, [bullet_x_left]
    add rax, board
    mov bl, [bullet_char]
    mov [rax], bl

.print_right:
    ; Dibujar bala derecha
    cmp qword [bullet_active_right], 0
    je .done
    
    mov rax, [bullet_y_right]
    mov rbx, column_cells + 2
    mul rbx
    add rax, [bullet_x_right]
    add rax, board
    mov bl, [bullet_char]
    mov [rax], bl
    
.done:
    ret

; Función para dibujar el power-up
print_powerup:
    cmp qword [powerup_active], 0
    je .done
    
    mov rax, [powerup_y]
    mov rbx, column_cells + 2
    mul rbx
    add rax, [powerup_x]
    add rax, board
    
    mov rcx, [powerup_type]
    cmp rcx, POWER_SHOOT
    je .print_shoot
    cmp rcx, POWER_LIFE
    je .print_life
    cmp rcx, POWER_BALLS
    je .print_balls
    cmp rcx, POWER_STICKY          ; Añadir comprobación para power-up sticky
    je .print_sticky
    jmp .done

.print_shoot:
    mov bl, [powerup_char]
    jmp .draw

.print_life:
    mov bl, [powerup_life_char]
    jmp .draw

.print_balls:
    mov bl, [powerup_balls_char]
    jmp .draw

.print_sticky:                     ; Añadir sección para imprimir power-up sticky
    mov bl, [powerup_sticky_char]

.draw:
    mov [rax], bl
    
.done:
    ret

activate_extra_life:
    inc qword [lives]
    ret

activate_extra_balls:
    ; Incrementar contador de bolas activas
    add qword [active_balls_count], 2

    ; Activar segunda bola
    mov qword [ball2_active], 1
    mov rax, [ball_x_pos]
    mov [ball2_x_pos], rax
    mov rax, [ball_y_pos]
    mov [ball2_y_pos], rax
    mov qword [ball2_dir_x], 1    ; Dirección inicial diferente
    mov qword [ball2_dir_y], -1
    
    ; Activar tercera bola
    mov qword [ball3_active], 1
    mov rax, [ball_x_pos]
    mov [ball3_x_pos], rax
    mov rax, [ball_y_pos]
    mov [ball3_y_pos], rax
    mov qword [ball3_dir_x], -1   ; Dirección inicial diferente
    mov qword [ball3_dir_y], -1
    ret

move_extra_balls:
    ; Verificar ball2
    cmp qword [ball2_active], 0
    je .check_ball3

    ; Comprobar colisión con bloques para ball2
    movzx rax, byte [ball2_y_pos]
    sub eax, BLOCK_START_ROW      
    cmp rax, 0
    jl .move_ball2              
    cmp rax, BLOCK_ROWS
    jge .move_ball2
    
    ; Calcular índice del bloque para ball2
    push rax                      
    movzx rcx, byte [ball2_x_pos]
    sub ecx, 1
    mov eax, ecx
    xor edx, edx
    mov ebx, BLOCK_WIDTH + 1      
    div ebx
    
    cmp eax, BLOCKS_PER_ROW
    jge .move_ball2_pop
    
    pop rbx                       
    push rax                      
    
    mov rax, rbx
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    pop rcx
    add rax, rcx
    
    cmp byte [blocks_state + rax], 1
    jne .move_ball2
    
    push rax                        
    call handle_block_destruction   
    pop rax
    
    neg byte [ball2_dir_y]         
    jmp .move_ball2

.move_ball2_pop:
    pop rax

.move_ball2:
    ; Mover ball2 en X
    movzx rax, byte [ball2_x_pos]
    movsx rbx, byte [ball2_dir_x]
    add rax, rbx
    
    cmp rax, 1
    jle .bounce_x2
    cmp rax, column_cells-1
    jge .bounce_x2
    mov [ball2_x_pos], al
    jmp .move_y2

.bounce_x2:
    neg byte [ball2_dir_x]
    movzx rax, byte [ball2_x_pos]
    movsx rbx, byte [ball2_dir_x]
    add rax, rbx
    mov [ball2_x_pos], al

.move_y2:
    movzx rax, byte [ball2_y_pos]
    movsx rbx, byte [ball2_dir_y]
    add rax, rbx
    
    cmp rax, 1
    jle .bounce_y2
    cmp rax, row_cells-1
    jge .deactivate_ball2
    mov [ball2_y_pos], al
    
    ; Verificar colisión con la paleta para ball2
    cmp rax, 27
    jne .check_ball3
    
    movzx rcx, byte [ball2_x_pos]
    mov rdx, [pallet_position]
    sub rdx, board
    sub rdx, 27 * (column_cells + 2)
    
    cmp rcx, rdx
    jl .check_ball3
    
    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .check_ball3
    
    neg byte [ball2_dir_y]
    jmp .check_ball3

.bounce_y2:
    neg byte [ball2_dir_y]
    movzx rax, byte [ball2_y_pos]
    movsx rbx, byte [ball2_dir_y]
    add rax, rbx
    mov [ball2_y_pos], al
    jmp .check_ball3

.deactivate_ball2:
    mov qword [ball2_active], 0
    dec qword [active_balls_count]   ; Reducir contador
    
    ; Si era la última bola, perder vida
    cmp qword [active_balls_count], 0
    jg .check_ball3                  ; Si quedan bolas, continuar
    
    dec qword [lives]
    mov rax, [lives]
    test rax, rax
    jz exit
    call reset_positions
    mov qword [ball_active], 1
    mov qword [active_balls_count], 1
    jmp .done

.check_ball3:
    cmp qword [ball3_active], 0
    je .done

    ; Comprobar colisión con bloques para ball3
    movzx rax, byte [ball3_y_pos]
    sub eax, BLOCK_START_ROW      
    cmp rax, 0
    jl .move_ball3              
    cmp rax, BLOCK_ROWS
    jge .move_ball3
    
    ; Calcular índice del bloque para ball3
    push rax                      
    movzx rcx, byte [ball3_x_pos]
    sub ecx, 1
    mov eax, ecx
    xor edx, edx
    mov ebx, BLOCK_WIDTH + 1      
    div ebx
    
    cmp eax, BLOCKS_PER_ROW
    jge .move_ball3_pop
    
    pop rbx                       
    push rax                      
    
    mov rax, rbx
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    pop rcx
    add rax, rcx
    
    cmp byte [blocks_state + rax], 1
    jne .move_ball3
    
    push rax                        
    call handle_block_destruction   
    pop rax
    
    neg byte [ball3_dir_y]         
    jmp .move_ball3

.move_ball3_pop:
    pop rax

.move_ball3:    
    ; Mover ball3 en X
    movzx rax, byte [ball3_x_pos]
    movsx rbx, byte [ball3_dir_x]
    add rax, rbx
    
    cmp rax, 1
    jle .bounce_x3
    cmp rax, column_cells-1
    jge .bounce_x3
    mov [ball3_x_pos], al
    jmp .move_y3

.bounce_x3:
    neg byte [ball3_dir_x]
    movzx rax, byte [ball3_x_pos]
    movsx rbx, byte [ball3_dir_x]
    add rax, rbx
    mov [ball3_x_pos], al

.move_y3:
    movzx rax, byte [ball3_y_pos]
    movsx rbx, byte [ball3_dir_y]
    add rax, rbx
    
    cmp rax, 1
    jle .bounce_y3
    cmp rax, row_cells-1
    jge .deactivate_ball3
    mov [ball3_y_pos], al
    
    ; Verificar colisión con la paleta para ball3
    cmp rax, 27
    jne .done
    
    movzx rcx, byte [ball3_x_pos]
    mov rdx, [pallet_position]
    sub rdx, board
    sub rdx, 27 * (column_cells + 2)
    
    cmp rcx, rdx
    jl .done
    
    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .done
    
    neg byte [ball3_dir_y]
    jmp .done

.bounce_y3:
    neg byte [ball3_dir_y]
    movzx rax, byte [ball3_y_pos]
    movsx rbx, byte [ball3_dir_y]
    add rax, rbx
    mov [ball3_y_pos], al
    jmp .done

.deactivate_ball3:
    mov qword [ball3_active], 0
    dec qword [active_balls_count]
    
    ; Si era la última bola, perder vida
    cmp qword [active_balls_count], 0
    jg .done                        ; Si quedan bolas, continuar
    
    dec qword [lives]
    mov rax, [lives]
    test rax, rax
    jz exit
    call reset_positions
    mov qword [ball_active], 1
    mov qword [active_balls_count], 1

.done:
    ret

_start:
    ; Inicializar variables
    mov qword [score], 0             ; Inicializar score en 0
    mov qword [level], 1             ; Inicializar level en 1
    mov qword [lives], 5             ; Inicializar lives en 5
    mov qword [blocks_destroyed], 0
    mov qword [powerup_active], 0    
    mov qword [powerup_type], 0      
    mov qword [active_balls_count], 1 
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [ball_active], 1
    mov qword [game_started], 0      ; Inicializar estado del juego

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
        call move_extra_balls

    .skip_ball_move:
        ; Limpiar y actualizar pantalla
        print clear, clear_length
        call clear_board
        call draw_blocks_m
        call print_pallet
        call print_ball
        call print_bullet
        call print_powerup
        call update_powerup
        call update_powerup_timer
        print board, board_size
        call print_game_info

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
        cmp al, ' '                   ; Check for space key
        je .start_game
        jmp .done

    .start_game:
        cmp qword [ball_stuck], 1
        je .release_ball
        cmp qword [game_started], 0
        jne .done
        mov qword [game_started], 1
        mov qword [ball_dir_y], -1
        mov qword [ball_dir_x], 1
        jmp .done

    .release_ball:
        mov qword [ball_stuck], 0
        mov qword [game_started], 1
        mov qword [ball_dir_y], -1
        mov qword [ball_dir_x], 1
        jmp .done

    .move_left2:
        mov rdi, left_direction
        call move_pallet
        jmp .done

    .move_right2:
        mov rdi, right_direction
        call move_pallet

    .done:
        call update_bullet
        call update_powerup
        call update_powerup_timer
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
