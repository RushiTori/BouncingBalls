bits    64
default rel

%include "raylib.inc"
%include "stdtypes.inc"

section .rodata

var(static, float_t, one_over_uint32_max, 796917760)
var(static, float_t, _360_f, 360.0)
var(static, float_t, one_f, 1.0)

section .text

%macro rand32_base 0
	.gen_rand:
		rdrand eax
		jae    .gen_rand
%endmacro

; uint32_t rand32(void);
func(global, rand32)
	rand32_base
	ret

; Color rand_col(void);
func(global, rand_col)
	rand32_base
	or eax, A_MASK
	ret

; Color rand_hsv(void);
func(global, rand_hsv)
	sub rsp, 8
	
	xorps xmm0, xmm0
	movd  xmm1, float_p [_360_f]
	call  randf

	movd  xmm1, float_p [one_f]
	movss xmm2, xmm1
	call  ColorFromHSV

	add rsp, 8
	ret

; float randf(float min, float max);
func(global, randf)
	rand32_base

	; return ((float)(rand()) / RAND_MAX) * (max - min) + min
	cvtsi2ss xmm2, rax
	mulss    xmm2, float_p [one_over_uint32_max]
	subss    xmm1, xmm0
	mulss    xmm1, xmm2
	addss    xmm0, xmm1

	ret
