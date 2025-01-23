/*
 * tis_asm.c
 *
 *  Created on: Dec 10, 2024
 *      Author: Powerbyte7
 */

#include "tis_asm.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const char *regs[8] = {
    [NIL] = "NIL",   [ACC] = "ACC",     [UP] = "UP",   [DOWN] = "DOWN",
    [LEFT] = "LEFT", [RIGHT] = "RIGHT", [ANY] = "ANY", [LAST] = "LAST"};

static const uint16_t instructions_bin[] = {
    0x0000, 0x01A5, 0x05A5, 0x0806, 0x0C00, 0x8AE8,
    0xA358, 0xE804, 0xD802, 0x4800, 0x5000, 0x4000,
};

static const char *instructions_str[] = {
    "NOP",          "ADD 421",      "SUB 421",       "ADD ANY",
    "SUB NIL",      "MOV 744, ACC", "MOV 856, LEFT", "MOV LEFT, RIGHT",
    "MOV UP, DOWN", "NEG",          "SWP",           "SAV"};

int tis_decode(uint16_t instruction, char *buffer) {
    if (instruction & 0x8000 && instruction & 0x4000) {
        // MOV <SRC>, <DST>
        tis_reg_t src = instruction & register_mask;
        tis_reg_t dst = (instruction >> 11) & register_mask;
        return sprintf(buffer, "MOV %s, %s", regs[src], regs[dst]);
    } else if (instruction & 0x8000) {
        // MOV #<imm11>, <DST>
        tis_reg_t dst = (instruction >> 11) & register_mask;
        return sprintf(buffer, "MOV %d, %s", instruction & imm11_mask,
                       regs[dst]);
    } else if (instruction & 0x4000) {
        // NEG, SWP, SAV, JRO
        if (instruction == 0x4800) {
            return sprintf(buffer, "NEG");
        } else if (instruction == 0x5000) {
            return sprintf(buffer, "SWP");
        } else if (instruction == 0x4000) {
            return sprintf(buffer, "SAV");
        }
    } else if (instruction == 0) {
        return sprintf(buffer, "NOP");
    } else {
        // ADD, SUB
        uint16_t negative = instruction & 0x400;
        uint16_t use_register = instruction & 0x800;
        if (negative) {
            if (use_register) {
                // SUB <SRC>
                tis_reg_t src = instruction & register_mask;
                return sprintf(buffer, "SUB %s", regs[src]);
            } else {
                // SUB #<imm10>
                return sprintf(buffer, "SUB %d", instruction & imm10_mask);
            }
        } else {
            if (use_register) {
                // SUB <SRC>
                tis_reg_t src = instruction & register_mask;
                return sprintf(buffer, "ADD %s", regs[src]);
            } else {
                // SUB #<imm10>
                return sprintf(buffer, "ADD %d", instruction & imm10_mask);
            }
        }
    }
}

tis_reg_t tis_register_encode(const char *str) {
    for (char i = 0; i < (sizeof(regs) / sizeof(regs[0])); i++) {
        if (strncmp(str, regs[i], strlen(regs[i])) == 0) {
            return (tis_reg_t)i;
        }
    }
    return INVALID;
}

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

static const char *opcodes_str[13] = {
    [NOP] = "NOP", [MOV] = "MOV", [ADD] = "ADD", [SUB] = "SUB", [SWP] = "SWP",
    [SAV] = "SAV", [NEG] = "NEG", [JMP] = "JMP", [JEZ] = "JEZ", [JNZ] = "JNZ",
    [JGZ] = "JGZ", [JLZ] = "JLZ", [JRO] = "JRO",
};

static const char *asm_formats[] = {
    [NOP] = "NOP",
    [MOV] = "MOV",
    [ADD] = "ADD",
    [SUB] = "SUB",
    [SWP] = "SWP",
    [SAV] = "SAV",
    [NEG] = "NEG",
    [JMP] = "JMP",
    [JEZ] = "JEZ",
    [JNZ] = "JNZ",
    [JGZ] = "JGZ",
    [JLZ] = "JLZ",
    [JRO] = "JRO",
};

static char *asm_operands[] = {
    [NOP] = 0,
    [MOV] = 2,
    [ADD] = 1,
    [SUB] = 1,
    [SWP] = 0,
    [SAV] = 0,
    [NEG] = 0,
    [JMP] = 1,
    [JEZ] = 1,
    [JNZ] = 1,
    [JGZ] = 1,
    [JLZ] = 1,
    [JRO] = 1,
};


tis_opcode_t tis_parse_opcode(const char *str) {
    // All opcodes are 3 characters
    if (strlen(str) != 3) {
        return INVALID;
    }

    for (char i = 0; i < (sizeof(regs) / sizeof(regs[0])); i++) {
        if (strcmp(str, opcodes_str[i]) == 0) {
            return i;
        }
    }
    return INVALID;
}

// Encodes an imm11 operand from int
int tis_imm11_encode(int integer) {
    if (integer < -999) {
        return 999 | imm11_sign_bit;
    } else if (integer < 0) {
        return (integer*-1) | imm11_sign_bit;
    } else if (integer < 999) {
        return integer;
    }
    return 999;
}

// Returns number of instructions written, or -1 on error
int tis_encode(char *program, uint16_t *instructions) {
    // Copy program to buffer to use strtok
    char buffer[512];
    strcpy(buffer, program);

    // Split on newlines
    const char token_delimiter[] = "\t ,";
    

    // PC to increase after every parsed instruction
    int pc = 0;
    // Store label pointers for later linking
    char *labels_pos[16] = {0};
    char *labels_ref[16] = {0};

    // Pointer to current line
    char *line;
    // strtok_r pointer
    char *nextline = program;
    
    // Parse every line
    while ((line = strtok_r(nextline, "\n", &nextline)) != NULL) {
        printf("PC: %d\n", pc);

        // Check for maximum line length
        int line_len = strlen(line);
        if (line_len > 20) {
            return -1; 
        }

        // Divide line in code and comment
        char* comment;
        strtok_r(line, "#", &comment);

        printf("Line: %s\n", line);

        // First token is either label, opcode, or empty
        char *rest = NULL;
        char *token = strtok_r(line, token_delimiter, &rest);

        printf("Token1: %s\n", token);

        // Check for empty line
        if (token == NULL) {
            continue;
        }

        // Check for label which ends with ':'
        int token_len = strlen(token);
        if (token[token_len-1] == ':') {
            // Avoid replacing existing label
            if (labels_pos[pc]) {
                return -1;
            }

            // Save label without ':'
            token[token_len-1] = '\0';
            labels_pos[pc] = token;

            // Get next token
            token = strtok_r(NULL, token_delimiter, &rest);
            if (token == NULL) {
                continue;
            }
        }

        printf("Instructiontoken: %s\n", token);

        // Check for valid opcode
        tis_opcode_t opcode = tis_parse_opcode(token);
        if (opcode == INVALID) {
            return -1;
        }

        // Set instruction identifying bits
        instructions[pc] = 0x0; // TODO asm_codes[opc]; 

        // End if no further operands
        int opcount = asm_operands[opcode];
        if (opcount == 0) {
            pc++;
            continue;
        }

        // Get <SRC>
        char *src = strtok_r(NULL, token_delimiter, &rest);
        if (src == NULL) {
            return -1; // <SRC> not found
        }

        printf("SRC: %s\n", src);

        // Check if <SRC> is register
        tis_reg_t src_reg = tis_register_encode(src);
        if (opcode == JMP || opcode == JEZ || opcode == JGZ || opcode == JLZ || opcode == JNZ) {
            // Store label string for later linking
            labels_ref[pc] = src;
            break;
        } else if (src_reg != INVALID) {
            // Place <SRC> in first 3 bits
            instructions[pc] &= ~register_mask;
            instructions[pc] |= src_reg; 
        } else {
            // Check if <SRC> is integer
            int integer;
            int result = sscanf(src, "%d", &integer);
            if (result != 1) {
                // Couldn't parse register nor number
                return -1;
            }
            if (opcode == MOV || opcode == SUB || opcode == ADD ) {
                if (opcode == SUB) {
                    integer *= -1;
                }
                // Integer goes in first 11 bits.
                instructions[pc] |= tis_imm11_encode(integer);
            }
        }

        // End if no further operands
        if (opcount == 1) {
            pc++;
            continue;
        }

        // Get <DST>
        char *dst = strtok_r(NULL, token_delimiter, &rest);
        if (dst == NULL) {
            return -1; // <DST> not found
        }

        printf("DST: %s\n", dst);

        // Check if <DST> is register
        tis_reg_t dst_reg = tis_register_encode(dst);
        if (dst_reg != INVALID) {
            // Place <DST> in bytes 13-11 
            instructions[pc] &= ~(register_mask<<11);
            instructions[pc] |= dst_reg << 11; 
        } else {
            // Couldn't parse register
            return -1;
        }

        // Increase after every line
        pc++;
    }

    // TODO link labels

    // Number of instructions written
    return pc;
}

int tis_decode_test() {
    for (int i = 0;
         i < (sizeof(instructions_bin) / sizeof(instructions_bin[0])); i++) {
        char buffer[32] = {0};
        tis_decode(instructions_bin[i], buffer);
        printf("%s\n", buffer);
        if (strcmp(buffer, instructions_str[i])) {
            printf("^ Expected %s\n", instructions_str[i]);
        }
    }
}

int tis_encode_test() {
	puts("Starting encode");

    const char* assembly =
    "START: NOP # COMMENT\n"
    "ADD 421\n"
    "SUB 421\n"
    "ADD ANY\n"
    "SUB NIL\n"
    "MOV 744, ACC";

    uint16_t expected[] = {
        instructions_bin[0],
        instructions_bin[1],
        instructions_bin[2],
        instructions_bin[3],
        instructions_bin[4],
        instructions_bin[5],
    };

    uint16_t result[8];
    int count = tis_encode(assembly, result);

    printf("Managed to encode %d instructions\n", count);

    for (int i = 0; i <= 5; i++) {
        if (expected[i] != result[i]) {
            printf("Failed at %d\nExpected: %x\nResult: %x\n", i, expected[i], result[i]);
        }
    }

    printf("Done!");
}
