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
column_cells2: 	equ 20 ; Para el marcador de vidas, puntaje y nivel
array_length:	equ row_cells * column_cells + row_cells ; cells are mapped to bytes in the array and a new line char ends each row

;This is regarding the sleep time
timespec:
    tv_sec  dq 0
    tv_nsec dq 20000


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
	db " "                    ; Espacio entre el cuadro de juego y de puntaje
	times column_cells2 db "X"
    db 0x0a, 0xD
%endmacro

%macro hollow_line 0
    db "X"
    times column_cells-2 db " "
    db "X"
	db " "
	db "X"
	times column_cells2-2 db " "
	db "X", 0x0a, 0xD
%endmacro

%macro print 2
	mov rax, sys_write
	mov rdi, 1 	; stdout
	mov rsi, %1
	mov rdx, %2
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
	mov rax, sys_nanosleep
	mov rdi, timespec
	xor rsi, rsi		; ignore remaining time in case of call interruption
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
        mov rax, ICANON
        not rax
        and [termios+12], rax
		mov byte[termios+CC_C+VTIME], 0
		mov byte[termios+CC_C+VMIN], 0
        pop rax

        call write_stdin_termios
        ret

echo_off:
        call read_stdin_termios

        ; clear echo bit in local mode flags
        push rax
        mov rax, ECHO
        not rax
        and [termios+12], rax
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

        mov rax, 36h
        mov rbx, stdin
        mov rcx, 5401h
        mov rdx, termios
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

        mov rax, 36h
        mov rbx, stdin
        mov rcx, 5402h
        mov rdx, termios
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
	pallet_position dq board -23 + 28 * (column_cells+column_cells2 +2)
	pallet_size dq 3

    ball_x_pos: dq 52
	ball_y_pos: dq 26
    ball_x_direction: db 1  ; + derecha, - izquierda
    ball_y_direction: db 1  ; + abajo, - arriba
    ball_counter dq 0
    ball_move dq 800          ; Para que la bola se mueva cada 3 ciclos

	; Bloques
	block1: db 'OOOO', 0
	block2: db 'UUUU', 0

	; Textos para el marcador
    score_text db "PUNTAJE: "
    score_length equ $ - score_text
    level_text db "NIVEL: "
    level_length equ $ - level_text
    lives_text db "VIDAS: "
    lives_length equ $ - lives_text

    current_score dq 0
    current_level dq 1
    current_lives dq 5


section .text

;	Function: print_ball
; This function displays the position of the ball
; Arguments: none
;
; Return:
;	Void

print_ball:
    mov r8, board           ; Carga la direccion del tablero
	mov r9, [ball_y_pos]    ; Carga la posicion y de la bola
    mov rax, column_cells + column_cells2 + 2 ; Ancho total de la consola
	mul r9                  ; Multiplica la posicion y por el ancho para obtener el offset de la fila
    add rax, [ball_x_pos]   ; Se suma la posicion x para tener la posicion de la bola
    add r8, rax             ; Posicion de memoria donde se va a dibujar la bola

    mov r10, board
    add r10, board_size     ; Direccion final del tablero
    ; Compara con los bordes del tablero para que la bola se mantenga dentro de este
    cmp r8, board           ; Se compara la posicion de la bola con la posicion inicial del tablero
    jl .exit_ball           ; Si es menor no se dibuja la bola
    cmp r8, r10             ; Se compara la posicion de la bola con la posicion final del tablero
    jg .exit_ball           ; Si es mayor no se dibuja la bola

    cmp byte [r8], 'X'      ; Comparar para saber si se llego a un limite del area de juego
    je .exit_ball           ; Si se llega al borde no se dibuja la bola

    mov byte [r8], '0'      ; Si no esta en el borde dibuja la bola

.exit_ball:
	ret

; Funcion: Mover la bola incluyendo los rebotes en los bordes
; Function to erase a block when hit
erase_block:
    ; rdi should contain the position where collision occurred
    push r8
    push r9
    push rax
    push rbx
    push rcx

    mov r8, rdi        ; Position of collision
    mov r9, 4          ; Block width is 4 characters

    ; First check if we hit 'O' or 'U'
    mov al, byte [r8]
    cmp al, 'O'
    je .find_block_start
    cmp al, 'U'
    je .find_block_start
    jmp .end

.find_block_start:
    ; Save the type of block we hit
    mov bl, al         ; Save 'O' or 'U' in bl

    ; Find start of block by checking up to 3 positions to the left
    mov rcx, 3         ; Maximum positions to check left
.check_left:
    mov al, byte [r8 - 1]  ; Check character to the left
    cmp al, bl            ; Compare with our block type ('O' or 'U')
    jne .start_erasing    ; If different, we found the start
    dec r8               ; Move left
    dec rcx
    jnz .check_left

.start_erasing:
    ; Now r8 points to the first character of the block or close to it
    ; Ensure we erase exactly 4 characters
    mov rcx, 4          ; Block width
.erase_loop:
    mov byte [r8], ' '  ; Replace with space
    inc r8
    dec rcx
    jnz .erase_loop

    ; Increase score
    add qword [current_score], 1

.end:
    pop rcx
    pop rbx
    pop rax
    pop r9
    pop r8
    ret

; Modified move_ball function with collision detection
move_ball:
    mov r8, board
    mov r9, [ball_y_pos]
    mov rax, column_cells + column_cells2 + 2
    mul r9
    add rax, [ball_x_pos]
    add r8, rax

    mov byte [r8], ' '    ; Borrar posicion actual de la bola

    mov rax, [ball_x_pos] ; Posicion x actual
    movsx rbx, byte [ball_x_direction] ; Carga la direccion con signo (der o izq)
    add rax, rbx          ; Calcula nueva posicion (sumando la direccion y la posicion)
    mov rcx, [ball_y_pos] ; Posicion y actual

    mov r10, rax          ; Guarda nueva posicion en x
    mov rax, column_cells + column_cells2 + 2
    mul rcx               ; Multiplica y actual por el ancho de la consola
    add rax, r10          ; Se suman la posicion x y la multiplicacion anterior
    lea r8, [board + rax] ; Obtiene la direccion con el desplazamiento (posicion actual)

    ; Check for block collisions first
    mov al, byte [r8]
    cmp al, 'O'
    je .block_collision
    cmp al, 'U'
    je .block_collision

    ; Continue with original collision checks
    cmp byte [r8], char_equal
    jne .check_wall
    neg byte [ball_y_direction]
    jmp .check_wall

.block_collision:
    ; Call block erasing function
    mov rdi, r8         ; Pass collision position to erase_block
    call erase_block

    ; Bounce the ball (change direction)
    neg byte [ball_y_direction]
    jmp .check_wall

.check_wall:
    cmp byte [r8], 'X'
    jne .move_x
    neg byte [ball_x_direction]
    jmp .check_y

.move_x:
    mov [ball_x_pos], r10

.check_y:
    mov rax, [ball_y_pos]
    movsx rbx, byte [ball_y_direction]
    add rax, rbx
    mov r10, rax
    mov rax, column_cells + column_cells2 + 2
    mul r10
    add rax, [ball_x_pos]
    lea r8, [board + rax]

    cmp byte [r8], 'X'
    jne .move_y
    neg byte [ball_y_direction]
    ret

.move_y:
    mov [ball_y_pos], r10
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
		mov r8, [pallet_position]  ; Posicion de la paleta
		cmp byte[r8-1], 'X'        ; Comprobar si hay una X que indique el limite del area de juego
		je .end                    ; Si hay una X no permite moverse mas
		mov r9, [pallet_size]	   ; Tamano de la paleta
		mov byte [r8 + r9 - 1], char_space ; Coloca un espacio en la ultima posicion
		dec r8  				   ; Mueve la paleta un espacio hacia la izquierda
		mov [pallet_position], r8  ; Guarda la nueva posicion
		jmp .end
	.move_right:
		mov r8, [pallet_position]
		mov r9, [pallet_size]
		cmp byte [r8+r9], 'X'      ; Comprobar si hay una X que indique el limite del area de juego
		je .end					   ; Si hay una X no permite moverse mas
		mov byte [r8], char_space
		inc r8					   ; Mueve la paleta un espacio hacia la derecha
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
	add r8, ((column_cells+3)+(column_cells2 + 3))*6
	sub r8, 17                        ; Iniciar 6 filas debajo del limite superior
	mov r10, 6                        ; Filas
	lea r12, [block1]      			  ; Guarda la direccion de memoria del bloque 1
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
    add r8, column_cells+column_cells2 + 3   ; Avanza a la siguiente fila
    dec r10
    jmp .loop_rows

.blocks_done:
    pop r13
    pop r12
    pop rdx
    pop rbx
    ret

; Funcion: Mostrar la puntuacion
score_info:
	push rbx
	push rdx
	push r12
	push r13

	mov r8, board
	add r8, (column_cells+5)*5
	sub r8, 5						; Se ubica la posicion donde se quiere colocar el puntaje
	mov rsi, score_text			    ; Texto 'PUNTAJE'
	mov rcx, score_length			; Longitud del texto
	call write_score				; Se llama a la funcion para escribir el texto correspondiente

	mov rdi, [current_score]		; Valor actual del puntaje
    call num_to_str					; Se llama a la funcion para convertir numeros a texto

	add r8, (column_cells+5)*10
	add r8, 16						; Se ubica la posicion donde se quiere colocar el nivel

	mov rsi, level_text				; Texto 'NIVEL'
	mov rcx, level_length			; Longitud del texto
	call write_score

	mov rdi, [current_level]		; Valor del nivel actual
    call num_to_str

	add r8, (column_cells+5)*15
	sub r8, 46						; Se ubica la posicion donde se quieren colocar las vidas

	mov rsi, lives_text				; Texto 'VIDAS'
	mov rcx, lives_length			; Longitud del texto
	call write_score

	mov rdi, [current_lives]		; Valor de vidas actuales
    call num_to_str

	pop r13
	pop r12
	pop rdx
	pop rbx
	ret

; Funcion para convertir numero a string
num_to_str:
	push rbx
	push rdx
	mov rbx, 10			; Divisor para obtener los digitos
	mov rax, rdi        ; Numero a convertir (niveles, vidas o puntos)
    xor rcx, rcx        ; Contador

.divide_loop:
    xor rdx, rdx        ; Limpiar rdx para la division
    div rbx             ; Dividir por 10
    push rdx            ; Guardar el residuo en el stack
    inc rcx             ; Incrementar contador
    test rax, rax       ; Verificar si quedan digitos
    jnz .divide_loop

.write_loop:
    pop rdx             ; Obtener digitos del stack
    add dl, '0'         ; Convertir a ASCII
    mov [r8], dl        ; Escribir digito
    inc r8              ; Siguiente espacio en memoria
    dec rcx             ; Decrementar contador
    jnz .write_loop

    pop rdx
    pop rbx
    ret

; Funcion para escribir texto
write_score:
    push rcx
    push rsi

.write_loop:
    mov al, byte [rsi]
    mov [r8], al
    inc rsi
    inc r8
    dec rcx
    jnz .write_loop

    pop rsi
    pop rcx
    ret

_start:
	call canonical_off
	print clear, clear_length
	call start_screen


	.main_loop:
        ; Se usa un contador para la bola para no afectar la velocidad de respuesta de la paleta
        inc qword [ball_counter]
        mov rax, [ball_counter]
        cmp rax, [ball_move]
        jl .skip_ball_move        ; Si el contador es menor que el limite establecido no se
        mov qword [ball_counter], 0
        call move_ball

    .skip_ball_move:
		call print_pallet
		call draw_blocks_m
		call score_info
        call print_ball
		print board, board_size

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
