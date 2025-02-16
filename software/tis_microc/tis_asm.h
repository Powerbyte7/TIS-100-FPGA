/*
 * tis_asm.h
 *
 *  Created on: Dec 10, 2024
 *      Author: Powerbyte7
 */

#ifndef TIS_ASM_H_
#define TIS_ASM_H_

#include <stdint.h>

typedef enum {
	INVALID = -1,
    NIL = 0b000,
    ACC = 0b001,
    UP = 0b010,
    DOWN = 0b011,
    LEFT = 0b100,
    RIGHT = 0b101,
    ANY = 0b110,
    LAST = 0b111,
} tis_reg_t;

typedef enum {
    NOP,
    MOV,
    ADD,
    SUB,
    SWP,
    SAV,
    NEG,
    JMP,
    JEZ,
    JNZ,
    JGZ,
    JLZ,
    JRO,
} tis_opcode_t;

#define imm6_mask (0x003F)
#define imm10_mask (0x3FF)
#define imm11_mask (0x7FF)
#define imm11_sign_bit (0x400)
#define register_mask (0b111)

// Returns number of written characters, excluding \0
int tis_dissassemble(uint16_t instruction, char* buffer);

int tis_assemble_program(char *program, uint16_t *instructions);

// Tests assembly decoding
void tis_disassembler_test();
void tis_assembler_test();

#endif /* TIS_ASM_H_ */
