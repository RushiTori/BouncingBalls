bits        64
default     rel

%include "balls.inc"
%include "rand.inc"

section     .rodata

var(static, float_t, percent_50_f, 0.50)

var(static, uint32_t, neg_flag32, 0x80_00_00_00)

var(static, float_t, min_ball_speed, -240.0)
var(static, float_t, max_ball_speed, 240.0)

var(static, float_t, min_ball_radius, 4.0)
var(static, float_t, max_ball_radius, 8.0)

section     .bss

res(static, float_t, screen_width_f)
res(static, float_t, screen_height_f)

; Static array of all the balls in the program
; Ball balls[BALLS_COUNT];
balls:
global      balls: data
	resb sizeof(Ball) * BALLS_COUNT
balls_size equ $ - balls

section .text

%macro fetch_screen_sizes 0
	call     GetScreenWidth
	cvtsi2ss xmm0,                     rax
	movd     float_p [screen_width_f], xmm0

	call     GetScreenHeight
	cvtsi2ss xmm0,                      rax
	movd     float_p [screen_height_f], xmm0
%endmacro

; Initializes all the balls in the program
; bool init_balls(void);
func(global, init_balls)
	push rbp
	mov  rbp, rsp

	fetch_screen_sizes

	mov rcx, BALLS_COUNT
	lea rdi, [balls]

	movd xmm3, float_p [min_ball_radius]
	movd xmm4, float_p [max_ball_radius]

	movd xmm5, float_p [min_ball_speed]
	movd xmm6, float_p [max_ball_speed]

	movd xmm7, float_p [screen_width_f]
	movd xmm8, float_p [screen_height_f]

	; Initializing the balls
	.init_loop:
		movss xmm0,                        xmm3
		movss xmm1,                        xmm4
		call  randf
		movd  float_p [rdi + Ball.radius], xmm0

		movss xmm1,                       xmm7
		subss xmm1,                       xmm0
		call  randf
		movd  float_p [rdi + Ball.pos_x], xmm0

		movd  xmm0,                       float_p [rdi + Ball.radius]
		movss xmm1,                       xmm8
		subss xmm1,                       xmm0
		call  randf
		movd  float_p [rdi + Ball.pos_y], xmm0

		movss xmm0,                       xmm5
		movss xmm1,                       xmm6
		call  randf
		movd  float_p [rdi + Ball.vel_x], xmm0

		movss xmm0,                       xmm5
		movss xmm1,                       xmm6
		call  randf
		movd  float_p [rdi + Ball.vel_y], xmm0

		call rand_col
		mov  color_p [rdi + Ball.col], eax

		add rdi, sizeof(Ball)
		dec rcx
		jnz .init_loop

	pop rbp
	mov al, true
	ret

; Free and/or clean the data needed for the program
; void free_balls(void);
func(global, free_balls)
	; push rbp
	; mov  rbp, rsp

	; WIP

	; pop rbp
	ret

; Returns the total amount of kinetic energy in the program
; float get_total_kinetic_energy(void)
func(global, get_total_kinetic_energy)
	xorps xmm0, xmm0
	mov   rcx,  BALLS_COUNT
	lea   rdi,  [balls]

	; Kinetic energy of a ball: |Ball.vel|^2 * Ball.mass * 0.5
	; Simplifying for the entire program we can just add the non-constant part together
	; and then multiply the total by the contant part to save on computation
	.compute_loop:
		movd  xmm1, float_p [rdi + Ball.vel_x]
		mulss xmm1, xmm1

		movd  xmm2, float_p [rdi + Ball.vel_y]
		mulss xmm2, xmm2

		addss xmm1, xmm2

		mulss xmm1, float_p [rdi + Ball.mass]
		addss xmm0, xmm1

		add rdi, sizeof(Ball)
		dec rcx
		jnz .compute_loop

	mulss xmm0, float_p[percent_50_f]
	ret

; Updates all the balls according to a Delta Time, and whether or not to compute inter-collisions
; void update_balls(float dt, bool doBallsCollide);
func(global, update_balls)
	shufps  xmm0, xmm0, 0
	mov rcx, BALLS_COUNT
	lea rdi, [balls]
	.add_velocities:
		movq  xmm1,                       vector2_p [rdi + Ball.vel]
		mulps xmm1,                       xmm0
		movq  xmm2,                       vector2_p [rdi + Ball.pos]
		addps xmm1,                       xmm2
		movq  vector2_p [rdi + Ball.pos], xmm1

		add rdi, sizeof(Ball)
		dec rcx
		jnz .add_velocities

	;cmp dil, false
	;je  .skip_collisions
	;mov rcx, BALLS_COUNT
	;lea rdi, [balls]
	;.handle_collisions:
	;	; WIP
	;	add rdi, sizeof(Ball)
	;	dec rcx
	;	jnz .handle_collisions
	;.skip_collisions:

	push rbp
	mov  rbp, rsp

	fetch_screen_sizes

	mov  eax,  uint32_p [neg_flag32]
	movd xmm2, float_p [screen_width_f]
	movd xmm3, float_p [screen_height_f]

	mov rcx, BALLS_COUNT
	lea rdi, [balls]
	.handle_screen_edges:
		; Handling left/right
			movd    xmm0, float_p [rdi + Ball.pos_x]
			movd    xmm1, float_p [rdi + Ball.radius]
			ucomiss xmm1, xmm0
			jbe     .skip_fix_left
				movd float_p [rdi + Ball.pos_x], xmm1
				xor  float_p [rdi + Ball.vel_x], eax
				jmp  .end_fix_X
			.skip_fix_left:
			vsubss xmm1, xmm2, xmm1
			ucomiss xmm0, xmm1
			jbe     .end_fix_X
				movd float_p [rdi + Ball.pos_x], xmm1
				xor  float_p [rdi + Ball.vel_x], eax
			.end_fix_X:

		; Handling up/down
			movd    xmm0, float_p [rdi + Ball.pos_y]
			movd    xmm1, float_p [rdi + Ball.radius]
			ucomiss xmm1, xmm0
			jbe     .skip_fix_up
				movd float_p [rdi + Ball.pos_y], xmm1
				xor  float_p [rdi + Ball.vel_y], eax
				jmp  .end_fix_Y
			.skip_fix_up:
			vsubss xmm1, xmm3, xmm1
			ucomiss xmm0, xmm1
			jbe     .end_fix_Y
				movd float_p [rdi + Ball.pos_y], xmm1
				xor  float_p [rdi + Ball.vel_y], eax
			.end_fix_Y:

		add rdi, sizeof(Ball)
		dec rcx
		jnz .handle_screen_edges

	pop rbp
	ret

; Renders all the balls at once
; void render_balls(void);
func(global, render_balls)
	push rbp
	mov  rbp, rsp

	push r12
	push r13

	mov r12, BALLS_COUNT
	lea r13, [balls]
	
	.render_loop:
		movd xmm1, float_p [r13 + Ball.radius]
		movq xmm0, vector2_p [r13 + Ball.pos]
		mov  edi,  color_p [r13 + Ball.col]
		call DrawCircleV

		add r13, sizeof(Ball)
		dec r12
		jnz .render_loop

	pop r13
	pop r12

	pop rbp
	ret
