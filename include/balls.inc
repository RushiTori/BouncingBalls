%ifndef BALLS_INC
%define BALLS_INC

%include "raylib.inc"

struc Ball
	.mass:
	struc_member(float_t, radius, 1)

	.pos:
	struc_member(float_t, pos_x, 1)
	struc_member(float_t, pos_y, 1)

	.vel:
	struc_member(float_t, vel_x, 1)
	struc_member(float_t, vel_y, 1)

	struc_member(color_t, col, 1)
endstruc

; Number of balls in the program
BALLS_COUNT            equ 8192

; Default value of computed_balls
DEFAULT_COMPUTED_BALLS equ 256

; Number of balls actively used by the program (can't exceed BALLS_COUNT)
; uint64_t computed_balls;
extern computed_balls

; In kinetic view, the balls' color are determined by their kinetic energy over th eaverage kinetic energy
; bool use_kinetic_view;
extern use_kinetic_view

; Static array of all the balls in the program
; Ball balls[BALLS_COUNT];
extern balls

; Initializes all the balls in the program, returns false in case of failure
; bool init_balls(void);
extern init_balls

; Free and/or clean the data needed for the program
; void free_balls(void);
extern free_balls

; Returns the total amount of kinetic energy in the program
; float get_total_kinetic_energy(void)
extern get_total_kinetic_energy

; Updates all the balls according to a Delta Time, and whether or not to compute inter-collisions
; void update_balls(float dt, bool doBallsCollide);
extern update_balls

; Renders all the balls at once
; void render_balls(void);
extern render_balls

%endif ; BALLS_INC
