bits    64
default rel

%include "main.inc"

SCREEN_RATIO  equ 2
SCREEN_WIDTH  equ 1920 / SCREEN_RATIO
SCREEN_HEIGHT equ 1080 / SCREEN_RATIO
BALLS_COUNT   equ 256

section      .rodata

string(static, title_str, "ASM Raylib - Bouncing Balls !", 0)
var(static, float_t, screen_width_f, 960.0)
var(static, float_t, screen_height_f, 540.0)

var(static, float_t, percent_75_f, 0.75)

var(static, float_t, neg_flag_f, 0x80_00_00_00)

var(static, float_t, min_ball_speed, 1.0)
var(static, float_t, max_ball_speed, 8.0)

var(static, float_t, min_ball_radius, 5.0)
var(static, float_t, max_ball_radius, 20.0)

section      .bss

res_array(static, vector2_t, balls_pos, BALLS_COUNT)
res_array(static, vector2_t, balls_vel, BALLS_COUNT)
res_array(static, float_t, balls_radius, BALLS_COUNT)
res_array(static, color_t, balls_col, BALLS_COUNT)

section      .text

func(static, update_game)
	push rbp
	mov  rbp, rsp

	push r12
	push r13
	push r14
	push r15

	mov r12, BALLS_COUNT
	lea r13, [balls_pos]
	lea r14, [balls_vel]
	lea r15, [balls_radius]

	movd xmm2, float_p [neg_flag_f]
	movd xmm3, float_p [screen_width_f]
	movd xmm4, float_p [screen_height_f]

	; Update code goes here
	.update_loop:
		movd xmm5, float_p [r15]

		.fix_X:
			movd  xmm0, float_p [r13]
			movd  xmm1, float_p [r14]
			addss xmm0, xmm1

			ucomiss xmm5, xmm0
			jbe     .skip_fix_left
				xorps xmm1,          xmm2
				movd  float_p [r14], xmm1
				movss xmm0,          xmm5
				jmp   .end_fix_X
			.skip_fix_left:

			movss xmm6, xmm3
			subss xmm6, xmm5

			ucomiss xmm0, xmm6
			jbe     .skip_fix_right
				xorps xmm1,          xmm2
				movd  float_p [r14], xmm1
				movss xmm0,          xmm6
			.skip_fix_right:

		.end_fix_X:
			movd float_p [r13], xmm0

		.fix_Y:
			movd  xmm0, float_p [r13 + sizeof(float_s)]
			movd  xmm1, float_p [r14 + sizeof(float_s)]
			addss xmm0, xmm1

			ucomiss xmm5, xmm0
			jbe     .skip_fix_up
				xorps xmm1,                            xmm2
				movd  float_p [r14 + sizeof(float_s)], xmm1
				movss xmm0,                            xmm5
				jmp   .end_fix_Y
			.skip_fix_up:

			movss xmm6, xmm4
			subss xmm6, xmm5

			ucomiss xmm0, xmm6
			jbe     .skip_fix_down
				xorps xmm1,                            xmm2
				movd  float_p [r14 + sizeof(float_s)], xmm1
				movss xmm0,                            xmm6
			.skip_fix_down:

		.end_fix_Y:
			movd float_p [r13 + sizeof(float_s)], xmm0

		add r13, sizeof(vector2_s)
		add r14, sizeof(vector2_s)
		add r15, sizeof(float_s)
		dec r12
		jnz .update_loop

	.end:

	pop r15
	pop r14
	pop r13
	pop r12

	pop rbp
	ret

func(static, render_game)
	push rbp
	mov  rbp, rsp

	push r12
	push r13
	push r14
	push r15

	call BeginDrawing

	mov  rdi, COLOR_RAYWHITE
	call ClearBackground

	mov r12, BALLS_COUNT
	lea r13, [balls_pos]
	lea r14, [balls_col]
	lea r15, [balls_radius]

	; Render code goes here
	.render_loop:
		movq xmm0, vector2_p [r13]
		movd xmm1, float_p [r15]
		mov  rdi,  COLOR_BLACK
		call DrawCircleV

		movq  xmm0, vector2_p [r13]
		movd  xmm1, float_p [r15]
		mulss xmm1, float_p [percent_75_f]
		mov   edi,  color_p [r14]
		call  DrawCircleV

		add r13, sizeof(vector2_s)
		add r14, sizeof(color_s)
		add r15, sizeof(float_s)
		dec r12
		jnz .render_loop

	call EndDrawing

	pop r15
	pop r14
	pop r13
	pop r12

	pop rbp
	ret

func(static, init_balls)
	push r12
	push r13
	push r14
	push r15

	mov r11, BALLS_COUNT
	lea r12, [balls_pos]
	lea r13, [balls_vel]
	lea r14, [balls_radius]
	lea r15, [balls_col]

	movd xmm3, float_p [neg_flag_f]

	movd xmm4, float_p [min_ball_radius]
	movd xmm5, float_p [max_ball_radius]

	movd xmm6, float_p [screen_width_f]
	movd xmm7, float_p [screen_height_f]

	movd xmm8, float_p [min_ball_speed]
	movd xmm9, float_p [max_ball_speed]

	; Initializing the balls
	.init_loop:
		; init the ball velocity X
			movss xmm0,          xmm8
			movss xmm1,          xmm9
			call  randf
			call  rand32
			and   al,            1
			jz    .skip_neg_vel_x
			xorps xmm0,          xmm3
			.skip_neg_vel_x:
			movd  float_p [r13], xmm0

		; init the ball velocity Y
			movss xmm0,                            xmm8
			movss xmm1,                            xmm9
			call  randf
			call  rand32
			and   al,                              1
			jz    .skip_neg_vel_y
			xorps xmm0,                            xmm3
			.skip_neg_vel_y:
			movd  float_p [r13 + sizeof(float_s)], xmm0

		; init the ball radius
			movss xmm0,          xmm4
			movss xmm1,          xmm5
			call  randf
			movd  float_p [r14], xmm0

		; init the ball position X
			movss xmm1,          xmm6
			subss xmm1,          xmm0
			call  randf
			movd  float_p [r12], xmm0

		; init the ball position Y
			movd  xmm0,                            float_p [r14]
			movss xmm1,                            xmm7
			subss xmm1,                            xmm0
			call  randf
			movd  float_p [r12 + sizeof(float_s)], xmm0

		; init the ball color
			call rand_col
			mov  color_p [r15], eax

		add r12, sizeof(vector2_s)
		add r13, sizeof(vector2_s)
		add r14, sizeof(float_s)
		add r15, sizeof(color_s)
		dec r11
		jnz .init_loop

	pop r15
	pop r14
	pop r13
	pop r12

	ret

func(global, _start)
	mov  rdi, SCREEN_WIDTH
	mov  rsi, SCREEN_HEIGHT
	lea  rdx, [title_str]
	call InitWindow

	mov  rdi, 60
	call SetTargetFPS

	call init_balls

	.game_loop:
		call WindowShouldClose
		cmp  al, true
		je   .end_game_loop

		call update_game
		call render_game

		jmp .game_loop
	.end_game_loop:

	call CloseWindow

	mov rax, SYSCALL_EXIT
	mov rdi, EXIT_SUCCESS
	syscall
