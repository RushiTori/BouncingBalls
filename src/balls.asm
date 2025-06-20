bits    64
default rel

%include "balls.inc"
%include "rand.inc"

section .rodata

var(static, float_t, percent_50_f, 0.50)
var(static, float_t, one_f, 1.0)

var(static, uint64_t, neg_flag128, 0x8000_0000_8000_0000)
var(static, uint32_t, neg_flag64, 0x80_00_00_00)
var(static, uint32_t, neg_flag32, 0x80_00_00_00)

var(static, float_t, min_ball_speed, -240.0)
var(static, float_t, max_ball_speed, 240.0)

var(static, float_t, min_ball_radius, 4.0)
var(static, float_t, max_ball_radius, 12.0)

string(static, ball_texture_ext, ".png", 0)

ball_texture_file:
static  ball_texture_png: data
	incbin "res/ball_texture.png"
ball_texture_file_size equ $ - ball_texture_file

section     .data

var(global, uint64_t, computed_balls, DEFAULT_COMPUTED_BALLS)

section     .bss

res(static, float_t, screen_width_f)
res(static, float_t, screen_height_f)

ball_texture_img:
global      ball_texture_img: data
	resb sizeof(Image)
ball_texture_img_size equ $ - ball_texture_img

ball_texture_tex:
global ball_texture_tex: data
	resb sizeof(Texture)
ball_texture_tex_size equ $ - ball_texture_tex

; Static array of all the balls in the program
; Ball balls[BALLS_COUNT];
balls:
global balls: data
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

	lea  rdi, [ball_texture_img]
	lea  rsi, [ball_texture_ext]
	lea  rdx, [ball_texture_file]
	mov  rcx, ball_texture_file_size
	call LoadImageFromMemory

	sub rsp, 32

		lea rdi, [ball_texture_tex]

		mov    rax,                       pointer_p [ball_texture_img]
		mov    pointer_p [rsp],           rax
		movups xmm0,                      [ball_texture_img + sizeof(pointer_s)]
		movups [rsp + sizeof(pointer_s)], xmm0
		call   LoadTextureFromImage

		mov    rax,                       pointer_p [ball_texture_img]
		mov    pointer_p [rsp],           rax
		movups xmm0,                      [ball_texture_img + sizeof(pointer_s)]
		movups [rsp + sizeof(pointer_s)], xmm0
		call   UnloadImage

		mov    eax,                      uint32_p [ball_texture_tex]
		mov    uint32_p [rsp],           eax
		movups xmm0,                     [ball_texture_tex + sizeof(uint32_s)]
		movups [rsp + sizeof(uint32_s)], xmm0
		call   IsTextureValid

	add rsp, 32

	cmp al, false
	je  .end
	
	fetch_screen_sizes

	mov rcx, uint64_p [computed_balls]
	lea rdi, [balls]

	movd xmm3, float_p [min_ball_radius]
	movd xmm4, float_p [max_ball_radius]

	movd xmm5, float_p [min_ball_speed]
	movd xmm6, float_p [max_ball_speed]

	movd xmm7, float_p [screen_width_f]
	movd xmm8, float_p [screen_height_f]

	cmp uint64_p [computed_balls], 0
	je  .skip_init
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

	.skip_init:
	mov al, true
	.end:
	pop rbp
	ret

; Free and/or clean the data needed for the program
; void free_balls(void);
func(global, free_balls)
	sub rsp, 24

	mov    eax,                      uint32_p [ball_texture_tex]
	mov    uint32_p [rsp],           eax
	movups xmm0,                     [ball_texture_tex + sizeof(uint32_s)]
	movups [rsp + sizeof(uint32_s)], xmm0
	call   UnloadTexture

	add rsp, 24
	ret

; Returns the total amount of kinetic energy in the program
; float get_total_kinetic_energy(void)
func(global, get_total_kinetic_energy)
	xorps xmm0, xmm0
	mov   rcx,  uint64_p [computed_balls]
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

; void handle_screen_edges(void);
func(static, handle_screen_edges)
	mov  eax,  uint32_p [neg_flag32]
	movd xmm2, float_p [screen_width_f]
	movd xmm3, float_p [screen_height_f]

	mov rcx, uint64_p [computed_balls]
	lea rdi, [balls]
	.loop_:
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
		jnz .loop_
	ret

; void add_velocities(float dt);
func(static, add_velocities)
	shufps  xmm0, xmm0, 0
	mov rcx, uint64_p [computed_balls]
	lea rdi, [balls]
	.loop_:
		movq  xmm1,                       vector2_p [rdi + Ball.vel]
		mulps xmm1,                       xmm0
		movq  xmm2,                       vector2_p [rdi + Ball.pos]
		addps xmm1,                       xmm2
		movq  vector2_p [rdi + Ball.pos], xmm1

		add rdi, sizeof(Ball)
		dec rcx
		jnz .loop_
	ret

; Handles elastic collisions between the balls
; void handle_collisions(void);
func(static, handle_collisions)
	mov rcx, uint64_p [computed_balls]
	lea rdi, [balls]
	.loop_:
		mov rax, rcx
		dec rax
		jz  .skip_inner_loop
		lea rsi, [rdi + sizeof(Ball)]
		.inner_loop:

			movd  xmm0, float_p [rdi + Ball.mass] ; m1
			addss xmm0, float_p [rsi + Ball.mass] ; m12
			mulss xmm0, xmm0                      ; m12^2

			movq  xmm1, vector2_p [rdi + Ball.pos] ; p1
			movq  xmm2, vector2_p [rsi + Ball.pos] ; p2
			subps xmm1, xmm2                       ; p1_p2
			mulps xmm1, xmm1                       ; p1_p2^2
			vshufps xmm2, xmm1, xmm1, 85           ; p1_p2y^2
			addss xmm1, xmm2                       ; dist2

			comiss xmm1, xmm0
			jae    .skip_elastic_collision
				; Fixing the balls' positions
				sqrtss xmm0, xmm0                   ; m12
				sqrtss xmm1, xmm1                   ; dist
				subss  xmm0, xmm1                   ; excess
				movd   xmm2, float_p [percent_50_f] ; 1.0 / 2.0
				mulss  xmm0, xmm2                   ; excess / 2
				
				movd  xmm2, float_p [one_f]
				divss xmm2, xmm1            ; one_over_dist
				mulss xmm0, xmm2            ; one_over_dist * (excess/2)
				shufps xmm0, xmm0, 0


				movq  xmm1, vector2_p [rdi + Ball.pos] ; p1
				movq  xmm2, vector2_p [rsi + Ball.pos] ; p2
				subps xmm2, xmm1                       ; p2_p1
				mulps xmm2, xmm0                       ; p2_p1.setMag(excess / 2)

				movq  xmm0,                       vector2_p [rdi + Ball.pos] ; p1
				movq  xmm1,                       vector2_p [rsi + Ball.pos] ; p2
				subps xmm0,                       xmm2
				addps xmm1,                       xmm2
				movq  vector2_p [rdi + Ball.pos], xmm0                       ; p1
				movq  vector2_p [rsi + Ball.pos], xmm1                       ; p2

				; https://wikipedia.org/wiki/Elastic_collision
				;
					; base:
					; v1 = v1+(2m2/(m1+m2))*(((v2-v1).(p2-p1))/(|p2-p1|^2))*(p2-p1)
					; v2 = v2+(2m1/(m1+m2))*(((v1-v2).(p1-p2))/(|p1-p2|^2))*(p1-p2)
					;
					; common term (can cache):
					; m12 = m1+m2
					; v1  = v1+(2m2/m12)*(((v2-v1).(p2-p1))/(|p2-p1|^2))*(p2-p1)
					; v2  = v2+(2m1/m12)*(((v1-v2).(p1-p2))/(|p1-p2|^2))*(p1-p2)
					;
					; after simpliying the division:
					; numer1 = 2m2*((v2-v1).(p2-p1))*(p2-p1)
					; denom1 = m12*(|p2-p1|^2)
					; numer2 = 2m1*((v1-v2).(p1-p2))*(p1-p2)
					; denom2 = m12*(|p1-p2|^2)
					; v1     = v1+numer1/denom1
					; v2     = v2+numer2/denom2
					;
					; after expanding the dot products and magnitudes:
					;
					; dist2   = ((p2x-p1x)^2)+((p2y-p1y)^2)
					; dot     = (v2x-v1x)*(p2x-p1x)+(v2y-v1y)*(p2y-p1y)
					; numer1  = 2m2*dot*(p2-p1)
					; denom1  = m12*dist2
					; numer2  = 2m1*dot*(p1-p2)
					; denom2  = m12*dist2
					;
					; after expanding the position difference and simplyfing denom1 and denom2
					;
					; p2_p1   = ((p2x-p1x);(p2y-p1y))
					; dist2   = ((p2x-p1x)^2)+((p2y-p1y)^2)
					; dot     = (v2x-v1x)*(p2x-p1x)+(v2y-v1y)*(p2y-p1y)
					; numer1  = 2m2*dot*p2_p1
					; numer2  = 2m1*dot*-p2_p1
					; denom   = m12*dist2
					; v1      = v1+numer1/denom
					; v2      = v2+numer2/denom
					;
					; after separating everything into more variables))
					;

				; The elastic collision algorithm

					movd xmm0, float_p [rdi + Ball.mass]  ; m1
					movq xmm1, vector2_p [rdi + Ball.pos] ; p1
					movq xmm2, vector2_p [rdi + Ball.vel] ; v1

					movd xmm3, float_p [rsi + Ball.mass]  ; m2
					movq xmm4, vector2_p [rsi + Ball.pos] ; p2
					movq xmm5, vector2_p [rsi + Ball.vel] ; v2

					vaddss xmm6, xmm0, xmm3 ; m12
					addss xmm0, xmm0 ; 2m1
					addss xmm3, xmm3 ; 2m2

					subps xmm4, xmm1 ; p2_p1

					vsubps xmm1, xmm5, xmm2 ; v2_v1

					mulps xmm1, xmm4 ; p2_p1 * v2_v1
					vshufps xmm7, xmm1, xmm1, 85 ; (vy_diff)*(py_diff)
					addss xmm7, xmm1 ; dot

					mulss xmm0, xmm7
					vshufps xmm0, xmm0, xmm0, 0 ; (2m1*dot;2m1*dot)

					mulss xmm3, xmm7
					vshufps xmm3, xmm3, xmm3, 0 ; (2m2*dot;2m2*dot)

					mulps xmm3, xmm4 ; numer1

					movd  xmm7, float_p [neg_flag32]
					vshufps xmm7, xmm7, xmm7, 0
					xorps xmm4, xmm7                 ; -p2_p1

					mulps xmm0, xmm4 ; numer2

					mulps xmm4, xmm4 ; p2_p1^2

					vshufps xmm1, xmm4, xmm4, 85 ; py_diff^2

					addss xmm4, xmm1 ; dist2
					mulss xmm4, xmm6 ; denom

					movd  xmm6, float_p [one_f] ; 1.0f
					divss xmm6, xmm4            ; 1.0f/denom
					vshufps xmm6, xmm6, xmm6, 0 ; (1.0f/denom;1.0f/denom)

					mulps xmm3, xmm6 ; numer1/denom
					mulps xmm0, xmm6 ; numer2/denom

					addps xmm2, xmm3 ; v1+numer1/denom
					addps xmm5, xmm0 ; v2+numer2/denom

				movq vector2_p [rdi + Ball.vel], xmm2
				movq vector2_p [rsi + Ball.vel], xmm5

			.skip_elastic_collision:
			add rsi, sizeof(Ball)
			dec rax
			jnz .inner_loop
		.skip_inner_loop:

		add rdi, sizeof(Ball)
		dec rcx
		jnz .loop_
	ret

; Updates all the balls according to a Delta Time, and whether or not to compute inter-collisions
; void update_balls(float dt, bool doBallsCollide);
func(global, update_balls)
	cmp uint64_p [computed_balls], 0
	je  .skip_update

	sub rsp, 8

	mov  sil, dil
	call add_velocities

	cmp  sil, false
	je   .skip_collisions
	call handle_collisions
	.skip_collisions:

	fetch_screen_sizes
	call handle_screen_edges

	add rsp, 8

	.skip_update:
	ret

; Renders all the balls at once
; void render_balls(void);
func(global, render_balls)
	cmp  uint64_p [computed_balls], 0
	je   .skip_render
	push r12
	push r13

	mov r12, uint64_p [computed_balls]
	lea r13, [balls]
	
	sub rsp, 24
	.render_loop:
		; setting up call args
			; texture
				mov    eax,                      uint32_p [ball_texture_tex]
				mov    uint32_p [rsp],           eax
				movups xmm0,                     [ball_texture_tex + sizeof(uint32_s)]
				movups [rsp + sizeof(uint32_s)], xmm0

			; source
				movd     xmm0, int_p [ball_texture_tex + Texture.width]
				movd     xmm1, int_p [ball_texture_tex + Texture.height]
				unpcklps xmm1, xmm0
				xorps    xmm0, xmm0
				cvtdq2ps xmm1, xmm1
		
			; dest
				movd  xmm3, float_p [r13 + Ball.radius]
				shufps xmm3, xmm3, 0
				movq  xmm2, vector2_p [r13 + Ball.pos]
				subps xmm2, xmm3
				addps xmm3, xmm3

			; origin
				xorps xmm4, xmm4

			; rotation
				xorps xmm5, xmm5

			; tint
				mov edi, [r13 + Ball.col]

		call DrawTexturePro

		; movq xmm0, [r13 + Ball.pos]
		; movd xmm1, [r13 + Ball.radius]
		; mov  edi,  COLOR_RED
		; call DrawCircleLinesV

		add r13, sizeof(Ball)
		dec r12
		jnz .render_loop
	add rsp, 24

	pop r13
	pop r12

	.skip_render:
	ret
