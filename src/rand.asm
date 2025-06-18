bits    64
default rel

%include "ray_color.inc"
%include "stdtypes.inc"

section .rodata

var(static, float_t, uint32_max_over_one, 796917760)

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

; float randf(float min, float max);
func(global, randf)
	rand32_base

	; ret float_t(rax) * float_t[uint32_max_over_one] * (xmm1 - xmm0) + xmm0
	cvtsi2ss xmm2, rax
	mulss    xmm2, float_p [uint32_max_over_one]
	subss    xmm1, xmm0
	mulss    xmm1, xmm2
	addss    xmm0, xmm1

	ret
