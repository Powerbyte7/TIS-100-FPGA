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
    [NOP] = " NOP",
    [MOV] = " MOV %s %s",
    [ADD] = " ADD %s",
    [SUB] = " SUB %s",
    [SWP] = " SWP",
    [SAV] = " SAV",
    [NEG] = " NEG",
    [JMP] = " JMP %s",
    [JEZ] = " JEZ %s",
    [JNZ] = " JNZ %s",
    [JGZ] = " JGZ %s",
    [JLZ] = " JLZ %s",
    [JRO] = " JRO %s",
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

// Tokens which are expected by the parser
typedef enum {
	LABEL,
	SRC,
	SRC_DST,
    LABEL_OPERAND
} token_t;

// 1 Opcode
// 2 Operand

// Encodes an imm11 operand from int
int tis_imm11_encode(int integer) {
    if (integer < -999) {
        return 999 | imm11_sign_bit;
    } else if (integer < 0) {
        return (integer & imm11_mask) | imm11_sign_bit;
    } else if (integer < 999) {
        return integer;
    }
    return 999;
}

static inline int check_empty(const char* str) {
    while (*str) {
        if (!isspace(*str)) {
            return 0; // Has characters
        }
        str++;
    }

    return 1; // Only whitespace
}

// Returns number of instructions written, or -1 on error
int tis_encode(const char *program, uint16_t *instructions) {
    // Copy program to buffer to use strtok
    static char buffer[512];
    strcpy(buffer, program);

    // Replace commas with spaces for sscanf
    char* ptr = buffer;
    while(1) {
        if (*ptr == '\0') {
            break;
        } else if (*ptr == ',') {
            *ptr = ' ';
        }
    }

    // Split on newlines
    const char delimeter[] = "\n";
    // strtok_r pointer
    char *rest = buffer;

    // PC to increase after every parsed instruction
    int pc = 0;
    // Store label pointers for later linking
    char *labels_pos[16] = {0};
    char *labels_ref[16] = {0};

    while (1) {
        char *line = strtok_r(rest, delimeter, &rest);
        int len = strlen(line);

        // End after reaching end of string
        if (line == NULL) {
            return pc+1;
        }

        // Skip empty lines
        if (check_empty(line)) {
            continue;
        }

        // Check for reasonable line length
        if (len > 20) {
            return -1; 
        }

        // Check for label
        int count = sscanf(line, " %s:", &labels_pos[pc]);
        if (count == 1) {
            // Exclude label from instruction parsing
            line = strtok_r(rest, ":", &rest);
        }

        // Check every instruction for a match
        for (tis_opcode_t opc = 0; opc < (sizeof(asm_formats) / sizeof(asm_formats[0])); opc++) {
            char src[16];
            char dst[16];

            // sscanf returns opcount, or EOF on failure
            int opcount = sscanf(line, asm_formats[opc], &src, &dst);
            if (opcount != asm_operands[opc]) { 
                continue; 
            } 

            // Set instruction identifying bits
            instructions[pc] = 0x0; // TODO asm_codes[opc]; 

            // End if no further operands
            if (opcount == 0) {
                break;
            }

            // Check if <SRC> is register
            tis_reg_t src_reg = tis_register_encode(src);
            if (opc == JMP || opc == JEZ || opc == JGZ || opc == JLZ || opc == JNZ) {
                // Store label string for later linking
                labels_ref[pc] = strstr(line, src);
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
                if (opc == MOV || opc == SUB || opc == ADD ) {
                    // integer goes in first 11 bits.
                    instructions[pc] |= tis_imm11_encode(integer);
                }
            }

            // End if no further operands
            if (opcount == 1) {
                break;
            }

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
            
        }

        // Increase after every line
        pc++;
    }
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
