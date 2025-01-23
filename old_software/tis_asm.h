#ifndef TIS_ASM
#define TIS_ASM

#include <stdint.h>

typedef enum {
    NIL = 0b000,
    ACC = 0b001,
    UP = 0b010,
    DOWN = 0b011,
    LEFT = 0b100,
    RIGHT = 0b101,
    ANY = 0b110,
    LAST = 0b111
} tis_reg_t;

const char* regs[8] = {
    [NIL] = "NIL",
    [ACC] = "ACC",
    [UP] = "UP",
    [DOWN] = "DOWN",
    [LEFT] = "LEFT",
    [RIGHT] = "RIGHT",
    [ANY] = "ANY",
    [LAST] = "LAST"
};

const uint16_t instructions_bin[] = {
    0x0000,
    0x01A5,
    0x05A5,
    0x0806,
    0x0C00,
    0x8AE8,
    0xA358,
    0xE804,
    0xD802,
    0x4800,
    0x5000,
    0x4000,
};

const char* instructions_str[] = {
    "NOP",
    "ADD 421",
    "SUB 421",
    "ADD ANY",
    "SUB NIL",
    "MOV 744, ACC",
    "MOV 856, LEFT",
    "MOV LEFT, RIGHT",
    "MOV UP, DOWN",
    "NEG",
    "SWP",
    "SAV"
};

const uint16_t imm6_mask = 0x003F;
const uint16_t imm10_mask = 0x3FF;
const uint16_t imm11_mask = 0x7FF;
const uint16_t register_mask = 0b111;

// Returns number of written characters, excluding \0
int decode(uint16_t instruction, char* buffer);
int test_asm();

#endif
