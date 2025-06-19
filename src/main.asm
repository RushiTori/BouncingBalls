bits    64
default rel

%include "main.inc"

SCREEN_RATIO  equ 2
SCREEN_WIDTH  equ 1920 / SCREEN_RATIO
SCREEN_HEIGHT equ 1080 / SCREEN_RATIO

section      .rodata

string(static, title_str, "ASM Raylib - Bouncing Balls !", 0)
var(static, float_t, main_dt, 0.016666)

section      .text

func(static, update_game)
	push rbp
	mov  rbp, rsp

	movd xmm0, float_p [main_dt]
	xor  rdi,  rdi
	call update_balls

	pop rbp
	ret

func(static, render_game)
	push rbp
	mov  rbp, rsp

	call BeginDrawing

	mov  rdi, COLOR_RAYWHITE
	call ClearBackground

	call render_balls
	
	xor  rdi, rdi
	xor  rsi, rsi
	call DrawFPS

	call EndDrawing

	pop rbp
	ret

func(global, _start)
	mov  rdi, SCREEN_WIDTH
	mov  rsi, SCREEN_HEIGHT
	lea  rdx, [title_str]
	call InitWindow

	mov  rdi, 60
	call SetTargetFPS

	call init_balls
	cmp  al, false
	jne  .skip_init_fail
		call CloseWindow
		mov  rax, SYSCALL_EXIT
		mov  rdi, EXIT_FAILURE
		syscall
	.skip_init_fail:

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

	mov rax, SYSCALL_EXIT
	mov rdi, EXIT_SUCCESS
	syscall
