bits         64
default      rel

%include "main.inc"

section      .rodata

var(static, float_t, main_dt, 0.016666)
string(static, no_balls_easter_egg, "What were you expecting :)", 0)
var(static, float_t, eight_f, 8.0)

section      .data

var(static, uint8_t, bg_brightness, 0x7F)

section      .text

func(static, change_bg_brightness)
	push r12

	xor r12,  r12
	mov r12b, uint8_p [bg_brightness]

	; Try brightness UP
		mov  edi,  KEY_UP
		call IsKeyDown
		cmp  al,   false
		je   .skip_bright_up
		cmp  r12b, 0xFF
		je   .skip_bright_up
		inc  r12b
		.skip_bright_up:

	; Try brightness DOWN
		mov  edi,  KEY_DOWN
		call IsKeyDown
		cmp  al,   false
		je   .skip_bright_down
		cmp  r12b, 0x00
		je   .skip_bright_down
		dec  r12b
		.skip_bright_down:

	; Store the (maybe) new brightness
	mov uint8_p [bg_brightness], r12b

	pop r12
	ret

func(static, change_ball_radius)
	cmp uint64_p [computed_balls], 0
	je  .skip_change

	sub rsp, 8

	mov  rdi, KEY_SPACE
	call IsKeyPressed
	cmp  al,  false
	je   .end

	mov  rcx,  uint64_p [computed_balls]
	lea  rdi,  [balls]
	movd xmm0, float_p [eight_f]

	.loop_:
		movd float_p [rdi + Ball.radius], xmm0
		add  rdi,                         sizeof(Ball)
		dec  rcx
		jnz  .loop_
	.end:

	add rsp, 8

	.skip_change:
	ret

; void change_ball_color(Color(*gen_color)(void));
func(static, change_ball_color)
	cmp uint64_p [computed_balls], 0
	je  .skip_change

	push r12
	push r13
	push r14

	mov r12, rdi
	lea r13, [balls]
	mov r14, uint64_p [computed_balls]

	.loop_:
		call r12
		mov  color_p [r13 + Ball.col], eax
		add  r13,                      sizeof(Ball)
		dec  r14
		jnz  .loop_

	pop r14
	pop r13
	pop r12

	.skip_change:
	ret

func(static, update_game)
	sub rsp, 8

	call change_bg_brightness
	call change_ball_radius

	mov  rdi, KEY_R
	call IsKeyPressed
	cmp  al,  false
	je   .skip_rgb_random
		mov  rdi, rand_col
		call change_ball_color
	.skip_rgb_random:

	mov  rdi, KEY_H
	call IsKeyPressed
	cmp  al,  false
	je   .skip_hue_random
		mov  rdi, rand_hsv
		call change_ball_color
	.skip_hue_random:

	mov  rdi, KEY_K
	call IsKeyPressed
	cmp  al,  false
	je   .skip_toggle_kinetic_view
		xor bool_p [use_kinetic_view], true
	.skip_toggle_kinetic_view:

	movd xmm0, float_p [main_dt]
	mov  dil,  true
	call update_balls

	add rsp, 8
	ret

func(static, render_easter_egg)
	sub rsp, 8

	push r12
	push r13

	call GetScreenWidth
	shr  rax, 1
	mov  r12, rax
	sub  r12, 342

	call GetScreenHeight
	shr  rax, 1
	mov  r13, rax
	sub  r13, 25

	call rand_col

	lea  rdi, [no_balls_easter_egg]
	mov  rsi, r12
	mov  rdx, r13
	mov  rcx, 50
	mov  r8,  rax
	call DrawText
	
	pop r13
	pop r12

	add rsp, 8
	ret

func(static, render_game)
	sub rsp, 8

	call BeginDrawing

	xor rdi, rdi
	mov dil, uint8_p [bg_brightness]
	mov eax, 0x01010101
	mul edi
	mov edi, eax

	call ClearBackground

	call render_balls

	cmp  uint64_p [computed_balls], 0
	jne  .skip_easter_egg
	call render_easter_egg
	.skip_easter_egg:

	xor  rdi, rdi
	xor  rsi, rsi
	call DrawFPS

	call EndDrawing

	add rsp, 8
	ret

func(global, _start)
	mov  rdi, uint64_p [rsp]           ; argc
	lea  rsi, [rsp + sizeof(uint64_s)] ; argv
	call setup_program

	.game_loop:
		call WindowShouldClose
		cmp  al, true
		je   .end_game_loop

		call update_game
		call render_game

		jmp .game_loop
	.end_game_loop:

	call free_balls
	call CloseWindow
	sys_exit(EXIT_SUCCESS)
