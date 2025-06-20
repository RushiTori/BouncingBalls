bits    64
default rel

%include "setup.inc"

extern  strtoul
extern  printf

SCREEN_RATIO  equ 2
SCREEN_WIDTH  equ 1920 / SCREEN_RATIO
SCREEN_HEIGHT equ 1080 / SCREEN_RATIO

section      .rodata

string(static, title_str, "ASM Raylib - Bouncing Balls !", 0)

string(static, no_request_str, "Computing the default %lu balls, you can request more (or less) by passing some CLI args (max: %lu)", 0x0A, 0)
string(static, request_input_err_fmt, "Invalid argument, defaulting to %lu balls.", 0x0A, 0)
string(static, request_too_many_fmt, "Requested for %lu balls, but the max is %lu, defaulting to %lu.", 0x0A, 0)
string(static, request_success_fmt, "Successfully requested for %lu balls to be computed !", 0x0A, 0)

section      .text

; void handle_args(uint64_t argc, char** argv);
func(static, handle_args)
	sub rsp, 8

	cmp rdi, 1
	jle .print_no_request
		add rsi, sizeof(pointer_s)
		mov rdi, pointer_p [rsi]

		mov  rsi, rsp
		mov  rdx, 10
		call strtoul

		cmp pointer_p [rsp], NULL
		jne .skip_input_error

			lea  rdi, request_input_err_fmt
			mov  rsi, DEFAULT_COMPUTED_BALLS
			call printf
			jmp  .end
		.skip_input_error:

		cmp rax, BALLS_COUNT
		jle .skip_too_many

			lea  rdi, request_too_many_fmt
			mov  rsi, rax
			mov  rdx, BALLS_COUNT
			mov  rcx, DEFAULT_COMPUTED_BALLS
			call printf
			jmp  .end
		.skip_too_many:

		mov  uint64_p [computed_balls], rax
		lea  rdi,                       [request_success_fmt]
		mov  rsi,                       rax
		call printf
		jmp  .end
	
	.print_no_request:
	lea  rdi, [no_request_str]
	mov  rsi, DEFAULT_COMPUTED_BALLS
	mov  rdx, BALLS_COUNT
	call printf

	.end:

	add rsp, 8
	ret

; void setup_raylib(void);
func(static, setup_raylib)
	sub rsp, 8

	mov  rdi, LOG_WARNING
	call SetTraceLogLevel

	mov  rdi, FLAG_WINDOW_RESIZABLE
	call SetConfigFlags

	mov  rdi, 60
	call SetTargetFPS

	mov  rdi, SCREEN_WIDTH
	mov  rsi, SCREEN_HEIGHT
	lea  rdx, [title_str]
	call InitWindow

	add rsp, 8
	ret

; void setup_program(uint64_t argc, char** argv);
func(global, setup_program)
	sub rsp, 8

	call handle_args

	call setup_raylib

	call init_balls
	cmp  al, false
	jne  .skip_init_fail
		call CloseWindow
		sys_exit(EXIT_SUCCESS)
	.skip_init_fail:

	add rsp, 8
	ret
