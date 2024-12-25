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
POWER_LASER equ 1        ; Tipo de power-up de disparo
POWER_LIFE equ 2         ; Tipo de power-up de vida extra
POWER_BALLS equ 3         ; Tipo de power-up de bolas extra
POWER_CATCH equ 4
POWER_ENLARGE equ 5
POWER_SLOW equ 6
POWER_BREAK equ 7        ; Tipo de power-up de break


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

    ; Definición de tipos de bloques
    BLOCK_GREEN     equ 'G'
    BLOCK_PINK      equ 'I'
    BLOCK_BLUE      equ 'U'
    BLOCK_YELLOW    equ 'Y'
    BLOCK_RED       equ 'R'
    BLOCK_WHITE     equ 'W'
    BLOCK_ORANGE    equ 'O'
    BLOCK_LIGHTBLUE equ 'H'
    BLOCK_GRAY      equ 'A'
    BLOCK_GOLD      equ '#'

    ; Patrones de caracteres para cada tipo de bloque
    block_pattern_green:     db "GGGG", 0    ; Verde (80 pts)
    block_pattern_pink:      db "IIII", 0    ; Rosa (110 pts)
    block_pattern_blue:      db "UUUU", 0    ; Azul (100 pts)
    block_pattern_yellow:    db "YYYY", 0    ; Amarillo (120 pts)
    block_pattern_red:       db "RRRR", 0    ; Rojo (90 pts)
    block_pattern_white:     db "WWWW", 0    ; Blanco (50 pts)
    block_pattern_orange:    db "OOOO", 0    ; Naranja (60 pts)
    block_pattern_lightblue: db "HHHH", 0    ; Azul claro (70 pts)
    block_pattern_gray:      db "AAAA", 0    ; Gris (50 pts, 2 golpes)
    block_pattern_gold:      db "####", 0    ; Dorado (indestructible)
    block_empty db "    "    ; Espacio vacío del mismo ancho que un bloque

    ; Puntuaciones para cada tipo de bloque
    block_scores:
        db 80   ; BLOCK_GREEN (G)
        db 110  ; BLOCK_PINK (I)
        db 100  ; BLOCK_BLUE (U)
        db 120  ; BLOCK_YELLOW (Y)
        db 90   ; BLOCK_RED (R)
        db 50   ; BLOCK_WHITE (W)
        db 60   ; BLOCK_ORANGE (O)
        db 70   ; BLOCK_LIGHTBLUE (H)
        db 50   ; BLOCK_GRAY (A)
        db 0    ; BLOCK_GOLD (#)

     ; Array con el número de bloques por nivel
    blocks_per_level:
        dq 78    ; Nivel 1
        dq 91    ; Nivel 2
        dq 64    ; Nivel 3 (no se cuentan los bloques dorados)
        dq 140   ; Nivel 4
        dq 98    ; Nivel 5

    ; Patrones de niveles (13x6 bloques por nivel)
    level1_pattern:
        db 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A'
        db 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R'
        db 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'
        db 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U'
        db 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I'
        db 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '

    level2_pattern:
        db 'W', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', 'I', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', 'I', 'Y', ' ', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', 'I', 'Y', 'W', ' ', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', 'I', 'Y', 'W', 'O', ' ', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', 'I', 'Y', 'W', 'O', 'H', ' ', ' '
        db 'W', 'O', 'H', 'G', 'R', 'U', 'I', 'Y', 'W', 'O', 'H', 'G', ' '
        db 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'R'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '


    level3_pattern:
        db 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'W', 'W', 'W', '#', '#', '#', '#', '#', '#', '#', '#', '#', '#'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db '#', '#', '#', '#', '#', '#', '#', '#', '#', '#', 'W', 'W', 'W'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'U', 'U', 'U', '#', '#', '#', '#', '#', '#', '#', '#', '#', '#'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db '#', '#', '#', '#', '#', '#', '#', '#', '#', '#', 'H', 'H', 'H'
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '


    level4_pattern:
        db ' ', 'O', 'H', 'G', 'A', 'U', ' ', 'Y', 'W', 'O', 'H', 'G', ' '
        db ' ', 'H', 'G', 'A', 'U', 'I', ' ', 'W', 'O', 'H', 'G', 'A', ' '
        db ' ', 'G', 'A', 'U', 'I', 'Y', ' ', 'O', 'H', 'G', 'A', 'U', ' '
        db ' ', 'A', 'U', 'I', 'Y', 'W', ' ', 'H', 'G', 'A', 'U', 'I', ' '
        db ' ', 'U', 'I', 'Y', 'W', 'O', ' ', 'G', 'A', 'U', 'I', 'Y', ' '
        db ' ', 'I', 'Y', 'W', 'O', 'H', ' ', 'A', 'U', 'I', 'Y', 'W', ' '
        db ' ', 'Y', 'W', 'O', 'H', 'G', ' ', 'U', 'I', 'Y', 'W', 'O', ' '
        db ' ', 'W', 'O', 'H', 'G', 'A', ' ', 'I', 'Y', 'W', 'O', 'H', ' '
        db ' ', 'O', 'H', 'G', 'A', 'U', ' ', 'Y', 'W', 'O', 'H', 'G', ' '
        db ' ', 'H', 'G', 'A', 'U', 'I', ' ', 'W', 'O', 'H', 'G', 'A', ' '
        db ' ', 'G', 'A', 'U', 'I', 'Y', ' ', 'O', 'H', 'G', 'A', 'U', ' '
        db ' ', 'A', 'U', 'I', 'Y', 'W', ' ', 'H', 'G', 'A', 'U', 'I', ' '
        db ' ', 'U', 'I', 'Y', 'W', 'O', ' ', 'G', 'A', 'U', 'I', 'Y', ' '
        db ' ', 'I', 'Y', 'W', 'O', 'H', ' ', 'A', 'U', 'I', 'Y', 'W', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '

    level5_pattern:
        db ' ', ' ', ' ', 'Y', ' ', ' ', ' ', ' ', ' ', 'Y', ' ', ' ', ' '
        db ' ', ' ', ' ', 'Y', ' ', ' ', ' ', ' ', ' ', 'Y', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', 'Y', ' ', ' ', ' ', 'Y', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', 'Y', ' ', ' ', ' ', 'Y', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', 'A', 'A', 'A', 'A', 'A', 'A', 'A', ' ', ' ', ' '
        db ' ', ' ', ' ', 'A', 'A', 'A', 'A', 'A', 'A', 'A', ' ', ' ', ' '
        db ' ', ' ', 'A', 'A', 'R', 'A', 'A', 'A', 'R', 'A', ' ', ' ', ' '
        db ' ', ' ', 'A', 'A', 'R', 'A', 'A', 'A', 'R', 'A', 'A', ' ', ' '
        db ' ', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', ' '
        db ' ', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', ' '
        db ' ', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', ' '
        db ' ', 'A', ' ', 'A', 'A', 'A', 'A', 'A', 'A', 'A', ' ', 'A', ' '
        db ' ', 'A', ' ', 'A', ' ', ' ', ' ', ' ', ' ', 'A', ' ', 'A', ' '
        db ' ', 'A', ' ', 'A', ' ', ' ', ' ', ' ', ' ', 'A', ' ', 'A', ' '
        db ' ', ' ', ' ', ' ', 'A', 'A', ' ', 'A', 'A', ' ', ' ', ' ', ' '
        db ' ', ' ', ' ', ' ', 'A', 'A', ' ', 'A', 'A', ' ', ' ', ' ', ' '


    ; Array de punteros a los patrones de nivel
    level_patterns:
        dq level1_pattern
        dq level2_pattern
        dq level3_pattern
        dq level4_pattern
        dq level5_pattern

    ; Estado de los bloques (1=presente, 0=destruido)
    blocks_state: times (13 * 16) db 1  ; 13 columnas x 6 filas
    board_buffer: times (row_cells * (column_cells + 2)) db ' '  ; Buffer para el tablero


    ; Añadir constantes para los bloques
    BLOCK_START_ROW equ 5      ; Fila donde empiezan los bloques
    BLOCK_ROWS equ 16           ; Número de filas de bloques
    BLOCKS_PER_ROW equ 13      ; Bloques por fila
    PATTERN_SIZE equ BLOCK_ROWS * BLOCKS_PER_ROW

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
    powerup_x dq 0            ; Posición X del power-up cayendo
    powerup_y dq 0            ; Posición Y del power-up cayendo
    powerup_active dq 0        ; Si hay un power-up cayendo
    powerup_char_laser db 'L'       ; Carácter para el power-up de disparo
    powerup_life_char db 'P'  ; Carácter para el power-up de vida extra
    powerup_type dq 0         ; 0 = ninguno, 1 = disparo, 2 = vida extra
    blocks_destroyed dq 0      ; Contador de bloques destruidos
    blocks_for_powerup dq 3    ; Número de bloques que hay que destruir para que aparezca un power-up
    random_seed dq 12345      ; Semilla para generación de números aleatorios
    powerup_balls_char db 'D'    ; Carácter para el power-up de bolas extra
    active_balls_count dq 1   ; Contador de bolas activas (empieza con 1, la bola principal)
    ball_active dq 1
    powerup_catch_char db 'C'       ; Carácter para el power-up sticky
    has_catch dq 0                  ; Estado del power-up sticky
    ball_stuck dq 0                  ; Indica si la bola está pegada a la paleta
    powerup_enlarge_char db 'E'
    has_enlarge dq 0
    default_pallet_size dq 3        ; Tamaño normal de la paleta
    wide_pallet_size dq 5           ; Tamaño aumentado de la paleta
    powerup_slow_char db 'S'
    ball_speed dq 100       ; Velocidad normal (el valor que tenías en ball_move)
    slow_ball_speed dq 200  ; Velocidad más lenta
    has_slow dq 0          ; Estado del power-up de velocidad lenta
    powerup_break_char db 'B'
    has_break dq 0              ; Estado del power-up de break
    break_position dq 0         ; Posición X de la abertura
    break_width dq 5            ; Ancho de la abertura

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
    powerup_fall_rate dq 400
    powerup_counter dq 0

    level_complete db 0          ; Flag para indicar si el nivel está completo
    total_blocks dq 78           ; Bloques totales en el nivel actual
    blocks_left dq 78            ; Bloques restantes en el nivel actual
    max_level dq 5               ; Número máximo de niveles
    blocks_increment dq 39       ; Incremento de bloques por nivellevel_complete db 0          ; Flag para indicar si el nivel está completo

    MAX_ENEMIES equ 3
    ENEMY_CHAR db '@'
    
    ; Structure for each enemy: x_pos(8), y_pos(8), dir_x(8), dir_y(8), active(8)
    enemies_data: times (MAX_ENEMIES * 40) db 0
    enemy_count dq 0
    enemy_spawn_rate dq 200
    enemy_spawn_counter dq 0
    enemy_move_rate dq 100        ; Larger number = slower movement 
    enemy_move_counter dq 0

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

    ; Reiniciar posiciones de bolas extra (aunque estén inactivas)
    mov rax, [ball_x_pos]
    mov [ball2_x_pos], rax
    mov [ball3_x_pos], rax
    mov rax, [ball_y_pos]
    mov [ball2_y_pos], rax
    mov [ball3_y_pos], rax

    pop rcx
    pop rbx
    ret

; Función para mover la pelota y manejar colisiones
move_ball:
    cmp qword [ball_stuck], 1
    je .follow_paddle
    
    cmp qword [game_started], 0
    je .follow_paddle

    cmp qword [ball_active], 0
    je .done

    ; Comprobar colisión con bloques
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

    ; Calcular índice final del bloque
    pop rbx
    push rax
    mov rax, rbx
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    pop rcx
    add rax, rcx

    ; Verificar si hay un bloque
    cmp byte [blocks_state + rax], 0
    je .check_walls

    ; Obtener tipo de bloque del patrón
    mov rbx, [level]
    dec rbx
    imul rbx, PATTERN_SIZE
    add rbx, [level_patterns]
    movzx rbx, byte [rbx + rax]    ; Obtener el carácter del patrón

    ; Verificar si es espacio en blanco
    cmp bl, ' '
    je .check_walls
    
    ; Si es un bloque dorado, solo rebotar
    cmp bl, '#'
    je .bounce_only

    ; Si no es dorado, destruirlo
    push rax
    call handle_block_destruction
    pop rax

.bounce_only:
    neg byte [ball_dir_y]
    jmp .check_walls

.check_walls_pop:
    pop rax

.check_walls:
    ; El resto de la función permanece igual
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

    cmp qword [has_catch], 1
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
    
    ; Si hay bolas extra activas, convertir una en la principal
    cmp qword [ball2_active], 1
    je .convert_ball2_to_main
    cmp qword [ball3_active], 1
    je .convert_ball3_to_main
    
    ; Si no hay bolas extra, perder vida
    dec qword [lives]
    mov rax, [lives]
    test rax, rax
    jz exit
    call reset_positions
    mov qword [ball_active], 1
    mov qword [active_balls_count], 1
    jmp .done

.convert_ball2_to_main:
    ; Convertir ball2 en la bola principal
    mov qword [ball2_active], 0
    mov qword [ball_active], 1
    mov rax, [ball2_x_pos]
    mov [ball_x_pos], rax
    mov rax, [ball2_y_pos]
    mov [ball_y_pos], rax
    mov rax, [ball2_dir_x]
    mov [ball_dir_x], rax
    mov rax, [ball2_dir_y]
    mov [ball_dir_y], rax
    jmp .done

.convert_ball3_to_main:
    ; Convertir ball3 en la bola principal
    mov qword [ball3_active], 0
    mov qword [ball_active], 1
    mov rax, [ball3_x_pos]
    mov [ball_x_pos], rax
    mov rax, [ball3_y_pos]
    mov [ball_y_pos], rax
    mov rax, [ball3_dir_x]
    mov [ball_dir_x], rax
    mov rax, [ball3_dir_y]
    mov [ball_dir_y], rax
    jmp .done

.follow_paddle:
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
; Return;
;	void
print_pallet:
    ; Primero dibujamos la paleta normal
    mov r8, [pallet_position]
    mov rcx, [pallet_size]
    .write_pallet:
        mov byte [r8], char_equal
        inc r8
        dec rcx
        jnz .write_pallet

    ; Si el power-up de break está activo, crear la abertura en el borde
    cmp qword [has_break], 1
    jne .done

    ; Calcular la posición del borde derecho
    mov rax, [pallet_position]
    sub rax, board
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx                  ; rax = fila actual
    mul rbx                  ; rax = fila * ancho
    add rax, column_cells + 1  ; añadir el offset para llegar al borde derecho

    ; Crear la abertura en el borde
    mov byte [board + rax], ' '  ; Reemplazar la X con un espacio

    ; Actualizar la posición de la abertura
    mov rax, [pallet_position]
    sub rax, board
    mov rbx, column_cells + 2
    xor rdx, rdx
    div rbx
    mov [break_position], rdx    ; Guardar la posición X actual

.done:
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
        cmp byte [r8-1], 'X'
        je .end
        mov r9, [pallet_size]
        mov byte [r8 + r9 - 1], char_space
        dec r8
        mov [pallet_position], r8
        jmp .end
    .move_right:
        mov r8, [pallet_position]
        mov r9, [pallet_size]

        cmp qword [has_break], 1
        je .allow_movement

        cmp byte [r8+r9], 'X'
        je .end

    .allow_movement:
        mov byte [r8], char_space
        inc r8
        mov [pallet_position], r8

        cmp qword [has_break], 1
        jne .end

        mov rax, [pallet_position]
        add rax, [pallet_size]
        sub rax, board
        mov rcx, column_cells + 2
        xor rdx, rdx
        div rcx

        cmp rdx, column_cells
        jl .end

        ; Si la paleta sale completamente, pasar de nivel
        add qword [score], 10000
        push qword [score]
        inc qword [level]
        mov rax, [level]
        cmp rax, [max_level]
        jg exit

        call init_level
        call reset_positions
        call deactivate_all_powerups
        pop qword [score]

    .end:
        ret

; Funcion: Dibujar bloques
draw_blocks_m:
    push rbx
    push rdx

    ; Obtener el patrón del nivel actual
    mov rbx, [level]
    dec rbx
    mov rax, PATTERN_SIZE      ; Usar el nuevo tamaño del patrón
    mul rbx
    mov rbx, [level_patterns]
    add rbx, rax

    mov r8, board
    mov rax, column_cells + 2
    mov rcx, BLOCK_START_ROW
    mul rcx
    add r8, rax
    add r8, 1

    mov r10, BLOCK_ROWS         ; Ahora usará 16 filas
    xor r12, r12                ; Índice global para los bloques

.loop_rows:
    test r10, r10
    jz .blocks_done

    mov r11, BLOCKS_PER_ROW
    push r8

.loop_columns:
    test r11, r11
    jz .next_row

    cmp r12, PATTERN_SIZE
    jge .draw_empty

    ; Obtener el tipo de bloque
    movzx rax, byte [rbx + r12]

    ; Obtener el tipo de bloque del patrón
    ;mov al, [rbx + r12]

    ; Si es espacio o el bloque no existe, dibujar espacio
    cmp al, ' '
    je .draw_empty
    cmp byte [blocks_state + r12], 0
    je .draw_empty

    ; Dibujar el bloque
    mov rcx, BLOCK_WIDTH
.draw_block_loop:
    mov [r8], al
    inc r8
    dec rcx
    jnz .draw_block_loop
    jmp .after_block

.draw_empty:
    mov rcx, BLOCK_WIDTH
.draw_empty_loop:
    mov byte [r8], ' '
    inc r8
    dec rcx
    jnz .draw_empty_loop

.after_block:
    ; Añadir espacio entre bloques si no es el último bloque
    cmp r11, 1
    je .skip_space
    mov byte [r8], ' '
    inc r8

.skip_space:
    inc r12
    dec r11
    jmp .loop_columns

.next_row:
    pop r8
    add r8, column_cells + 2
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
    sub eax, BLOCK_START_ROW
    cmp rax, 0
    jl .no_collision
    cmp rax, BLOCK_ROWS
    jge .no_collision

    push rax
    movzx rcx, byte [ball_x_pos]
    sub ecx, 1
    mov eax, ecx
    xor edx, edx
    mov ebx, BLOCK_WIDTH + 1
    div ebx

    ; Verificar si la columna es válida
    cmp eax, BLOCKS_PER_ROW
    jge .pop_and_no_collision

    pop rbx
    push rax

    mov rax, rbx
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    pop rcx
    add rax, rcx

    ; Obtener el tipo de bloque del patrón actual
    push rax
    mov rbx, [level]
    dec rbx
    mov rcx, PATTERN_SIZE
    mul rcx
    mov rcx, [level_patterns]
    add rcx, rax
    pop rax

    ; Verificar el estado del bloque
    cmp byte [blocks_state + rax], 0
    je .no_collision

    ; Si es un bloque dorado (estado 2), solo rebotar
    cmp byte [blocks_state + rax], 2
    je .bounce_only

    ; Si es un bloque normal, destruirlo
    push rax
    call handle_block_destruction
    pop rax

.bounce_only:
    neg qword [ball_dir_y]
    jmp .no_collision

.pop_and_no_collision:
    pop rax

.no_collision:
    pop rdx
    pop rcx
    pop rbx
    ret

; Función para obtener el puntaje de un bloque
get_block_score:
    ; Entrada: AL = tipo de bloque
    ; Salida: AL = puntaje
    push rbx
    push rcx
    push rdx

    ; Guardar el tipo de bloque
    mov cl, al

    ; Puntajes por defecto
    mov al, 0      ; Valor por defecto

    cmp cl, 'G'    ; Verde
    jne .check_pink
    mov al, 80
    jmp .done

.check_pink:
    cmp cl, 'I'    ; Rosa
    jne .check_blue
    mov al, 110
    jmp .done

.check_blue:
    cmp cl, 'U'    ; Azul
    jne .check_yellow
    mov al, 100
    jmp .done

.check_yellow:
    cmp cl, 'Y'    ; Amarillo
    jne .check_red
    mov al, 120
    jmp .done

.check_red:
    cmp cl, 'R'    ; Rojo
    jne .check_white
    mov al, 90
    jmp .done

.check_white:
    cmp cl, 'W'    ; Blanco
    jne .check_orange
    mov al, 50
    jmp .done

.check_orange:
    cmp cl, 'O'    ; Naranja
    jne .check_lightblue
    mov al, 60
    jmp .done

.check_lightblue:
    cmp cl, 'H'    ; Azul claro
    jne .check_gray
    mov al, 70
    jmp .done

.check_gray:
    cmp cl, 'A'    ; Gris
    jne .check_gold
    mov al, 50
    jmp .done

.check_gold:
    cmp cl, '#'    ; Dorado
    jne .done
    mov al, 0

.done:
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
    push rbx
    push rcx
    push rdx
    push rax

    ; Verificar si el bloque existe
    cmp byte [blocks_state + rax], 2    ; 2 = bloque dorado
    je .skip_points
    cmp byte [blocks_state + rax], 0    ; 0 = ya destruido
    je .skip_points

    ; Obtener el tipo de bloque del patrón del nivel actual
    mov rbx, [level]
    dec rbx
    imul rbx, PATTERN_SIZE
    mov rcx, [level_patterns]
    add rcx, rbx
    add rcx, rax
    movzx rbx, byte [rcx]

    ; Verificar si es bloque dorado
    cmp bl, '#'
    je .skip_points

    ; Marcar el bloque como destruido
    mov byte [blocks_state + rax], 0
    dec qword [blocks_left]

    ; Calcular y sumar puntos
    push rax
    mov al, bl
    call get_block_score      ; Esta función devuelve los puntos en al
    movzx rax, al            ; Extender al a rax
    add [score], rax         ; Sumar al score total
    pop rax

    ; Incrementar contador de bloques destruidos
    inc qword [blocks_destroyed]

    ; Verificar si generar power-up
    mov rax, [blocks_destroyed]
    mov rcx, [blocks_for_powerup]
    xor rdx, rdx
    div rcx
    test rdx, rdx
    jnz .skip_points

    ; Generar power-up si no hay uno activo
    cmp qword [powerup_active], 0
    jne .skip_points

    ; Inicializar power-up
    mov qword [powerup_active], 1

    ; Calcular posición del power-up
    pop rax
    push rax
    mov rdx, 0
    mov rcx, BLOCKS_PER_ROW
    div rcx
    add rax, BLOCK_START_ROW
    mov [powerup_y], rax

    mov rax, rdx
    mov rbx, BLOCK_WIDTH + 1
    mul rbx
    add rax, 2
    mov [powerup_x], rax

    ; Generar tipo aleatorio de power-up
    call generate_random
    mov rbx, 7
    xor rdx, rdx
    div rbx
    inc rdx
    mov [powerup_type], rdx

.skip_points:
    pop rax
    pop rdx
    pop rcx
    pop rbx
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

    ; Obtener el patrón del nivel actual
    push rax
    mov rbx, [level]
    dec rbx
    imul rbx, PATTERN_SIZE
    mov rcx, [level_patterns]
    add rcx, rbx
    pop rax
    push rax

    ; Verificar si hay un bloque en el patrón
    movzx rbx, byte [rcx + rax]
    cmp bl, ' '
    je .pop_and_no_collision
    
    ; Verificar si el bloque está activo
    cmp byte [blocks_state + rax], 0
    je .pop_and_no_collision
    
    ; Verificar si es un bloque dorado
    cmp bl, '#'
    je .pop_and_no_collision

    call handle_block_destruction

    ; Desactivar la bala actual
    mov qword [bullet_active], 0

    ; Determinar cuál bala fue y desactivarla específicamente
    mov rax, [bullet_x]
    mov rbx, [bullet_x_left]
    cmp rax, rbx
    je .deactivate_left

    mov rbx, [bullet_x_right]
    cmp rax, rbx
    je .deactivate_right
    jmp .pop_and_no_collision

.deactivate_left:
    mov qword [bullet_active_left], 0
    pop rax
    jmp .no_collision

.deactivate_right:
    mov qword [bullet_active_right], 0
    pop rax
    jmp .no_collision

.pop_and_no_collision:
    pop rax

.no_collision:
    pop rdx
    pop rcx
    pop rbx
    ret

; Función para activar el power-up de disparo
activate_shooting:
    mov qword [has_shooting], 1
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

; Función para desactivar todos los power-ups
deactivate_all_powerups:
    mov qword [powerup_active], 0
    mov qword [powerup_type], 0
    mov qword [bullet_active_left], 0
    mov qword [bullet_active_right], 0
    mov qword [has_shooting], 0
    mov qword [ball_stuck], 0
    mov qword [has_catch], 0
    mov qword [has_enlarge], 0
    mov rax, [default_pallet_size]
    mov [pallet_size], rax
    mov qword [has_slow], 0
    mov rax, [ball_speed]
    mov [ball_move], rax
    mov qword [has_break], 0

    ; Mantener una sola bola activa
    cmp qword [ball_active], 1
    je .keep_main_ball
    
    ; Si la principal no está activa, convertir ball2 o ball3 en principal
    cmp qword [ball2_active], 1
    je .convert_ball2
    cmp qword [ball3_active], 1
    je .convert_ball3
    jmp .done

.keep_main_ball:
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    jmp .done

.convert_ball2:
    mov qword [ball_active], 1
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    mov rax, [ball2_x_pos]
    mov [ball_x_pos], rax
    mov rax, [ball2_y_pos]
    mov [ball_y_pos], rax
    mov rax, [ball2_dir_x]
    mov [ball_dir_x], rax
    mov rax, [ball2_dir_y]
    mov [ball_dir_y], rax
    jmp .done

.convert_ball3:
    mov qword [ball_active], 1
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    mov rax, [ball3_x_pos]
    mov [ball_x_pos], rax
    mov rax, [ball3_y_pos]
    mov [ball_y_pos], rax
    mov rax, [ball3_dir_x]
    mov [ball_dir_x], rax
    mov rax, [ball3_dir_y]
    mov [ball_dir_y], rax

.done:
    ret

; Función para desactivar el power-up actual
deactivate_current_powerup:
    push rax                        ; Guardar rax ya que lo vamos a usar

    ; Verificar y desactivar cada power-up si está activo
    cmp qword [has_shooting], 1
    je .disable_shooting
    cmp qword [has_catch], 1
    je .disable_catch
    cmp qword [has_enlarge], 1
    je .disable_enlarge
    cmp qword [has_slow], 1
    je .disable_slow
    cmp qword [has_break], 1
    je .disable_break
    jmp .done

.disable_shooting:
    mov qword [has_shooting], 0
    mov qword [bullet_active_left], 0
    mov qword [bullet_active_right], 0
    jmp .done

.disable_catch:
    mov qword [has_catch], 0
    mov qword [ball_stuck], 0
    jmp .done

.disable_enlarge:
    mov qword [has_enlarge], 0
    mov rax, [default_pallet_size]
    mov [pallet_size], rax
    jmp .done

.disable_slow:
    mov qword [has_slow], 0
    mov rax, [ball_speed]
    mov [ball_move], rax
    jmp .done

.disable_break:
    mov qword [has_break], 0

.done:
    pop rax                         ; Restaurar rax
    ret

; Función para manejar la caída del power-up
update_powerup:
    cmp qword [powerup_active], 0    ; Si no hay power-up activo, salir
    je .done

    ; Incrementar contador de caída
    inc qword [powerup_counter]
    mov rax, [powerup_counter]
    cmp rax, [powerup_fall_rate]     ; Comparar con la tasa de caída
    jl .done                         ; Si no es tiempo de caer, salir

    ; Reiniciar contador y mover power-up
    mov qword [powerup_counter], 0
    inc qword [powerup_y]            ; Mover power-up hacia abajo

    ; Verificar si llegó al fondo
    mov rax, [powerup_y]
    cmp rax, row_cells - 2
    jge .deactivate_powerup

    ; Verificar colisión con la paleta
    mov rax, [powerup_y]
    cmp rax, 27                      ; Fila de la paleta
    jne .done

    ; Verificar colisión horizontal con la paleta
    mov rcx, [powerup_x]             ; Posición X del power-up
    mov rdx, [pallet_position]
    sub rdx, board                   ; Obtener el offset de la paleta
    sub rdx, 27 * (column_cells + 2) ; Ajustar a la posición X real

    ; Comparar con el rango de la paleta
    cmp rcx, rdx
    jl .done                         ; Si está a la izquierda, no hay colisión

    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .done                         ; Si está a la derecha, no hay colisión

    ; Convertir una bola en principal si hay múltiples
    cmp qword [active_balls_count], 1
    jle .continue_powerup
    
    ; Si la bola principal está activa, mantenerla
    cmp qword [ball_active], 1
    je .keep_main_ball
    
    ; Si no, convertir ball2 o ball3 en principal
    cmp qword [ball2_active], 1
    je .convert_ball2_powerup
    cmp qword [ball3_active], 1
    je .convert_ball3_powerup
    
.keep_main_ball:
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    jmp .continue_powerup

.convert_ball2_powerup:
    mov qword [ball_active], 1
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    mov rax, [ball2_x_pos]
    mov [ball_x_pos], rax
    mov rax, [ball2_y_pos]
    mov [ball_y_pos], rax
    mov rax, [ball2_dir_x]
    mov [ball_dir_x], rax
    mov rax, [ball2_dir_y]
    mov [ball_dir_y], rax
    jmp .continue_powerup

.convert_ball3_powerup:
    mov qword [ball_active], 1
    mov qword [ball2_active], 0
    mov qword [ball3_active], 0
    mov qword [active_balls_count], 1
    mov rax, [ball3_x_pos]
    mov [ball_x_pos], rax
    mov rax, [ball3_y_pos]
    mov [ball_y_pos], rax
    mov rax, [ball3_dir_x]
    mov [ball_dir_x], rax
    mov rax, [ball3_dir_y]
    mov [ball_dir_y], rax

.continue_powerup:
    ; Desactivar cualquier power-up activo actual
    call deactivate_current_powerup

    ; Activar el nuevo power-up según su tipo
    mov rax, [powerup_type]

    cmp rax, POWER_LASER            ; Power-up de disparo
    jne .check_life
    mov qword [has_shooting], 1
    add qword [score], 1000
    jmp .deactivate_powerup

.check_life:
    cmp rax, POWER_LIFE             ; Power-up de vida extra
    jne .check_balls
    inc qword [lives]
    add qword [score], 1000
    jmp .deactivate_powerup

.check_balls:
    cmp rax, POWER_BALLS            ; Power-up de bolas extra
    jne .check_catch
    call activate_extra_balls
    add qword [score], 1000
    jmp .deactivate_powerup

.check_catch:
    cmp rax, POWER_CATCH            ; Power-up sticky
    jne .check_enlarge
    mov qword [has_catch], 1
    add qword [score], 1000
    jmp .deactivate_powerup

.check_enlarge:
    cmp rax, POWER_ENLARGE          ; Power-up de agrandar paleta
    jne .check_slow
    mov qword [has_enlarge], 1
    mov rax, [wide_pallet_size]
    mov [pallet_size], rax
    add qword [score], 1000
    jmp .deactivate_powerup

.check_slow:
    cmp rax, POWER_SLOW             ; Power-up de pelota lenta
    jne .check_break
    mov qword [has_slow], 1
    mov rax, [slow_ball_speed]
    mov [ball_move], rax
    add qword [score], 1000
    jmp .deactivate_powerup

.check_break:
    cmp rax, POWER_BREAK            ; Power-up de break
    jne .deactivate_powerup
    mov qword [has_break], 1
    add qword [score], 1000

.deactivate_powerup:
    mov qword [powerup_active], 0
    mov qword [powerup_type], 0
    mov qword [powerup_counter], 0

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
    cmp rcx, POWER_LASER
    je .print_shoot
    cmp rcx, POWER_LIFE
    je .print_life
    cmp rcx, POWER_BALLS
    je .print_balls
    cmp rcx, POWER_CATCH          ; Añadir comprobación para power-up sticky
    je .print_catch
    cmp rcx, POWER_ENLARGE
    je .print_enlarge
    cmp rcx, POWER_SLOW
    je .print_slow
    cmp rcx, POWER_BREAK
    je .print_break
    jmp .done

.print_shoot:
    mov bl, [powerup_char_laser]
    jmp .draw

.print_life:
    mov bl, [powerup_life_char]
    jmp .draw

.print_balls:
    mov bl, [powerup_balls_char]
    jmp .draw

.print_catch:                     ; Añadir sección para imprimir power-up sticky
    mov bl, [powerup_catch_char]
    jmp .draw

.print_enlarge:
    mov bl, [powerup_enlarge_char]
    jmp .draw

.print_slow:
    mov bl, [powerup_slow_char]
    jmp .draw

.print_break:
    mov bl, [powerup_break_char]
    jmp .draw

.draw:
    mov [rax], bl

.done:
    ret

activate_extra_life:
    inc qword [lives]
    ret

activate_enlarge_pallet:
    mov qword [has_enlarge], 1
    mov rax, [wide_pallet_size]
    mov [pallet_size], rax         ; Cambiar el tamaño de la paleta
    ret

activate_slow_ball:
    mov qword [has_slow], 1          ; Activar el estado del power-up
    mov rax, [slow_ball_speed]       ; Cargar la velocidad lenta
    mov [ball_move], rax             ; Aplicar la velocidad lenta
    ret

activate_break:
    mov qword [has_break], 1
    ret

activate_extra_balls:
    ; No activar bolas extra si la principal está perdida
    cmp qword [ball_active], 0
    je .done

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

.done:
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

; Función para inicializar el nivel actual
init_level:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push qword [score]  ; Guardar el score actual antes de inicializar

    ; Reset board to initial state with borders
    mov rcx, row_cells
.draw_lines:
    push rcx

    ; Calculate current line position
    mov rax, row_cells
    sub rax, rcx
    mov rbx, column_cells + 2
    mul rbx
    mov rdi, board
    add rdi, rax

    ; Draw left border
    mov byte [rdi], 'X'

    ; Draw middle (space)
    mov rcx, column_cells - 2
    inc rdi
.fill_middle:
    mov byte [rdi], ' '
    inc rdi
    loop .fill_middle

    ; Draw right border
    mov byte [rdi], 'X'
    mov byte [rdi + 1], 0x0a
    mov byte [rdi + 2], 0xD

    pop rcx
    loop .draw_lines

    ; Draw top and bottom borders
    mov rcx, column_cells
    mov rdi, board
.draw_top:
    mov byte [rdi], 'X'
    inc rdi
    loop .draw_top

    mov rcx, column_cells
    mov rdi, board + (row_cells - 1) * (column_cells + 2)
.draw_bottom:
    mov byte [rdi], 'X'
    inc rdi
    loop .draw_bottom

    ; Reset paddle position
    mov rax, [initial_pallet_pos]
    mov [pallet_position], rax

    ; Reset blocks_state para asegurar un estado limpio
    mov rcx, PATTERN_SIZE
    mov rdi, blocks_state
    mov al, 1  ; Inicializar todos los bloques como activos
    rep stosb

    ; Initialize blocks
    mov rax, [level]
    dec rax
    mov rcx, PATTERN_SIZE
    mul rcx
    mov rbx, [level_patterns]
    add rbx, rax

    mov rax, [level]
    dec rax
    mov rcx, 8
    mul rcx
    lea rcx, [blocks_per_level]
    mov rcx, [rcx + rax]
    mov [blocks_left], rcx

    ; Initialize blocks_state
    xor r8, r8

.init_loop:
    cmp r8, PATTERN_SIZE
    jge .restore_score

    mov al, [rbx + r8]
    cmp al, '#'
    je .set_indestructible
    cmp al, ' '
    je .set_empty

    mov byte [blocks_state + r8], 1
    jmp .next_block

.set_indestructible:
    mov byte [blocks_state + r8], 2
    jmp .next_block

.set_empty:
    mov byte [blocks_state + r8], 0

.next_block:
    inc r8
    jmp .init_loop

    mov qword [enemy_count], 0
    mov qword [enemy_spawn_counter], 0

.restore_score:
    pop qword [score]  ; Restaurar el score guardado

    ; Asegurarse de que el estado del juego esté limpio
    mov qword [blocks_destroyed], 0
    mov qword [powerup_active], 0
    mov qword [powerup_counter], 0

    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret


; Funcion para verificar que el nivel se ha completado
check_level_complete:
    push rax
    push rbx

    ; Verificar si quedan bloques
    mov rax, [blocks_left]
    test rax, rax            ; Comprueba si blocks_left = 0
    jnz .not_complete

    ; Incrementar nivel
    inc qword [level]
    mov rax, [level]
    cmp rax, 6              ; Verificar si completamos el nivel 5
    jg exit                 ; Si completamos el nivel 5, terminar el juego

    ; Obtener el número de bloques para el siguiente nivel
    dec rax                 ; Ajustar para índice base 0
    mov rbx, 8              ; Tamaño de cada entrada
    mul rbx
    lea rbx, [blocks_per_level]
    mov rax, [rbx + rax]    ; Obtener número de bloques del nuevo nivel
    mov [blocks_left], rax  ; Establecer blocks_left para el nuevo nivel

    ; Reinicializar el juego para el nuevo nivel
    call init_level
    call reset_positions
    call deactivate_all_powerups
    mov byte [game_started], 0

.not_complete:
    pop rbx
    pop rax
    retcheck_level_complete:
    push rax
    push rbx

    ; Verificar si quedan bloques
    mov rax, [blocks_left]
    test rax, rax            ; Comprueba si blocks_left = 0
    jnz .not_complete

    ; Incrementar nivel
    inc qword [level]
    mov rax, [level]
    cmp rax, 5              ; Verificar si llegamos al nivel máximo
    jg exit

    ; Preparar siguiente nivel
    mov rax, [blocks_increment]
    add [total_blocks], rax     ; Aumentar el número total de bloques
    mov rax, [total_blocks]
    mov [blocks_left], rax      ; Reiniciar contador de bloques restantes

    ; Reinicializar los bloques
    mov rcx, 78                 ; Número total de bloques
    mov rdi, blocks_state
    mov al, 1
    rep stosb                   ; Llenar con 1's

    ; Reiniciar estado del juego
    call reset_positions
    call deactivate_all_powerups
    mov byte [game_started], 0

.not_complete:
    pop rbx
    pop rax
    ret

init_enemy:
    push rbx
    push rcx
    push rdx
    
    ; Find free enemy slot
    mov rcx, 0
    .find_slot:
        cmp rcx, MAX_ENEMIES
        jge .done
        
        mov rax, 40          ; Size of each enemy structure
        mul rcx
        lea rbx, [enemies_data + rax]
        cmp qword [rbx + 32], 0  ; Check active flag
        je .init_slot
        
        inc rcx
        jmp .find_slot
        
    .init_slot:
        mov rax, 40
        mul rcx             ; rax = rcx * 40
        lea rdi, [enemies_data + rax]  ; rdi = base address for this enemy

        ; Set random X position
        call generate_random
        xor rdx, rdx
        mov rbx, column_cells - 4
        div rbx
        add rdx, 2
        mov [rdi], rdx          ; x_pos
        
        ; Set initial Y position
        mov qword [rdi + 8], 2   ; y_pos
        
        ; Set random directions
        call generate_random
        and rax, 1
        mov rbx, 2
        mul rbx
        sub rax, 1
        mov [rdi + 16], rax     ; dir_x
        
        call generate_random
        and rax, 1
        mov rbx, 2
        mul rbx
        sub rax, 1
        mov [rdi + 24], rax     ; dir_y
        
        ; Set active flag
        mov qword [rdi + 32], 1
        
    .done:
        pop rdx
        pop rcx
        pop rbx
        ret

update_enemies:
    push rbx
    push rcx
    push rdx
    
    inc qword [enemy_move_counter]
    mov rax, [enemy_move_counter]
    cmp rax, [enemy_move_rate]
    jl .done
    
    mov qword [enemy_move_counter], 0
    mov rcx, 0
    .loop:
        cmp rcx, MAX_ENEMIES
        jge .done
        
        ; Check if enemy is active
        mov rax, 40
        mul rcx
        lea rbx, [enemies_data + rax]
        cmp qword [rbx + 32], 0
        je .next_enemy
        
        ; Update X position
        mov rax, [rbx]           ; x_pos
        mov rdx, [rbx + 16]      ; dir_x
        add rax, rdx
        
        ; Check X boundaries
        cmp rax, 1
        jle .reverse_x
        cmp rax, column_cells-1
        jge .reverse_x
        mov [rbx], rax           ; Update x_pos
        jmp .update_y
        
    .reverse_x:
        neg qword [rbx + 16]     ; Reverse dir_x
        jmp .update_y
        
    .update_y:
        mov rax, [rbx + 8]       ; y_pos
        mov rdx, [rbx + 24]      ; dir_y
        add rax, rdx
        
        ; Check Y boundaries
        cmp rax, 1
        jle .reverse_y
        cmp rax, row_cells-2
        jge .deactivate_enemy
        mov [rbx + 8], rax       ; Update y_pos
        
        ; Check collisions with blocks
        push rcx
        push rbx
        call check_enemy_block_collision
        pop rbx
        pop rcx
        cmp rax, 1
        je .reverse_y
        
        ; Check collision with paddle
        call check_enemy_paddle_collision
        cmp rax, 1
        je .deactivate_enemy
        
        ; Check collision with ball
        call check_enemy_ball_collision
        cmp rax, 1
        je .deactivate_enemy
        
        ; Check collision with bullets
        call check_enemy_bullet_collision
        cmp rax, 1
        je .deactivate_enemy
        
        jmp .next_enemy
        
    .reverse_y:
        neg qword [rbx + 24]     ; Reverse dir_y
        jmp .next_enemy
        
    .deactivate_enemy:
        mov qword [rbx + 32], 0  ; Deactivate enemy
        dec qword [enemy_count]
        
    .next_enemy:
        inc rcx
        jmp .loop
        
    .done:
        ; Check if we should spawn a new enemy
        inc qword [enemy_spawn_counter]
        mov rax, [enemy_spawn_counter]
        cmp rax, [enemy_spawn_rate]
        jl .exit
        
        mov qword [enemy_spawn_counter], 0
        mov rax, [enemy_count]
        cmp rax, MAX_ENEMIES
        jge .exit
        
        call init_enemy
        
    .exit:
        pop rdx
        pop rcx
        pop rbx
        ret

print_enemies:
    push rbx
    push rcx
    push rdx
    
    mov rcx, 0
    .loop:
        cmp rcx, MAX_ENEMIES
        jge .done
        
        mov rax, 40
        mul rcx
        lea rbx, [enemies_data + rax]
        
        cmp qword [rbx + 32], 0  ; Check if active
        je .next_enemy
        
        ; Calculate position in board
        mov rax, [rbx + 8]       ; y_pos
        mov rdx, column_cells + 2
        mul rdx
        add rax, [rbx]           ; Add x_pos
        add rax, board
        
        mov dl, [ENEMY_CHAR]
        mov [rax], dl
        
    .next_enemy:
        inc rcx
        jmp .loop
        
    .done:
        pop rdx
        pop rcx
        pop rbx
        ret

check_enemy_block_collision:
    ; rbx contains pointer to current enemy
    push rbx
    push rcx
    push rdx
    
    mov rax, [rbx + 8]          ; y_pos
    sub eax, BLOCK_START_ROW
    cmp rax, 0
    jl .no_collision
    cmp rax, BLOCK_ROWS
    jge .no_collision
    
    ; Calculate block index
    mov rcx, [rbx]              ; x_pos
    sub ecx, 1
    mov rax, rcx
    xor rdx, rdx
    mov rbx, BLOCK_WIDTH + 1
    div rbx
    
    cmp rax, BLOCKS_PER_ROW
    jge .no_collision
    
    ; Check if block exists
    mov rcx, BLOCKS_PER_ROW
    mul rcx
    add rax, rdx
    
    cmp byte [blocks_state + rax], 0
    je .no_collision
    
    mov rax, 1                  ; Collision detected
    jmp .done
    
.no_collision:
    xor rax, rax                ; No collision
    
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

check_enemy_paddle_collision:
    ; rbx contains pointer to current enemy
    push rdx
    push rcx
    
    mov rax, [rbx + 8]          ; y_pos
    cmp rax, 27                 ; Paddle row
    jne .no_collision
    
    mov rcx, [rbx]              ; x_pos
    mov rdx, [pallet_position]
    sub rdx, board
    sub rdx, 27 * (column_cells + 2)
    
    cmp rcx, rdx
    jl .no_collision
    
    add rdx, [pallet_size]
    cmp rcx, rdx
    jg .no_collision
    
    add qword [score], 100
    mov rax, 1                  ; Collision detected
    jmp .done
    
.no_collision:
    xor rax, rax                ; No collision
    
.done:
    pop rcx
    pop rdx
    ret

check_enemy_ball_collision:
    ; rbx contains pointer to current enemy
    push rdx
    push rcx
    
    ; Check main ball
    mov rax, [rbx + 8]          ; Enemy y_pos
    cmp rax, [ball_y_pos]
    jne .check_ball2
    
    mov rcx, [rbx]              ; Enemy x_pos
    cmp rcx, [ball_x_pos]
    jne .check_ball2
    add qword [score], 100
    mov rax, 1
    jmp .done
    
.check_ball2:
    cmp qword [ball2_active], 0
    je .check_ball3
    
    mov rax, [rbx + 8]
    cmp rax, [ball2_y_pos]
    jne .check_ball3
    
    mov rcx, [rbx]
    cmp rcx, [ball2_x_pos]
    jne .check_ball3
    
    mov rax, 1
    jmp .done
    
.check_ball3:
    cmp qword [ball3_active], 0
    je .no_collision
    
    mov rax, [rbx + 8]
    cmp rax, [ball3_y_pos]
    jne .no_collision
    
    mov rcx, [rbx]
    cmp rcx, [ball3_x_pos]
    jne .no_collision
    
    mov rax, 1
    jmp .done
    
.no_collision:
    xor rax, rax
    
.done:
    pop rcx
    pop rdx
    ret

check_enemy_bullet_collision:
    ; rbx contains pointer to current enemy
    push rdx
    push rcx
    
    cmp qword [bullet_active_left], 0
    je .check_right_bullet
    
    mov rax, [rbx + 8]          ; Enemy y_pos
    cmp rax, [bullet_y_left]
    jne .check_right_bullet
    
    mov rcx, [rbx]              ; Enemy x_pos
    cmp rcx, [bullet_x_left]
    jne .check_right_bullet
    
    mov qword [bullet_active_left], 0
    add qword [score], 100
    mov rax, 1
    jmp .done
    
.check_right_bullet:
    cmp qword [bullet_active_right], 0
    je .no_collision
    
    mov rax, [rbx + 8]
    cmp rax, [bullet_y_right]
    jne .no_collision
    
    mov rcx, [rbx]
    cmp rcx, [bullet_x_right]
    jne .no_collision
    
    mov qword [bullet_active_right], 0
    mov rax, 1
    jmp .done
    
.no_collision:
    xor rax, rax
    
.done:
    pop rcx
    pop rdx
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
    mov qword [total_blocks], 78     ; Inicializar bloques totales
    mov qword [blocks_left], 78      ; Inicializar bloques restantes

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
        call check_level_complete

    .skip_ball_move:
        ; Limpiar y actualizar pantalla
        print clear, clear_length
        call clear_board
        call draw_blocks_m
        call print_pallet
        call print_ball
        call print_bullet
        call print_powerup
        call update_enemies
        call print_enemies
        call update_powerup
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
        je .handle_space
        jmp .done

    .handle_space:
        cmp qword [ball_stuck], 1
        je .release_ball
        ; Si tenemos el power-up de disparo, disparar
        cmp qword [has_shooting], 1
        je .shoot_bullets
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

    .shoot_bullets:
        call shoot_bullet
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
