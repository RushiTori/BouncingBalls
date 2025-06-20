bits    64
default rel

%include "main.inc"

SCREEN_RATIO  equ 2
SCREEN_WIDTH  equ 1920 / SCREEN_RATIO
SCREEN_HEIGHT equ 1080 / SCREEN_RATIO

section      .rodata

string(static, title_str, "ASM Raylib - Bouncing Balls !", 0)
var(static, float_t, main_dt, 0.016666)

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

func(static, update_game)
	sub rsp, 8

	call change_bg_brightness

	movd xmm0, float_p [main_dt]
	mov  dil,  true
	call update_balls

	add rsp, 8
	ret

func(static, render_game)
	sub rsp, 8

	call BeginDrawing

	; mov  rdi, COLOR_RAYWHITE
	xor rdi, rdi
	mov dil, uint8_p [bg_brightness]
	mov eax, 0x01010101
	mul edi
	mov edi, eax

	call ClearBackground

	call render_balls
	
	xor  rdi, rdi
	xor  rsi, rsi
	call DrawFPS

	call EndDrawing

	add rsp, 8
	ret

extern       puts

; void setup_program(uint64_t argc, char** argv);
func(static, setup_program)
	sub rsp, 8

	mov  rdi, LOG_WARNING
	call SetTraceLogLevel

	mov  rdi, FLAG_WINDOW_RESIZABLE
	call SetConfigFlags

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
		sys_exit(EXIT_SUCCESS)
	.skip_init_fail:

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
