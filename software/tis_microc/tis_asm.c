/*
 * tis_asm.c
 *
 *  Created on: Dec 10, 2024
 *      Author: Powerbyte7
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "tis_asm.h"

static const char *regs[8] = {
    [NIL] = "NIL",   [ACC] = "ACC",     [UP] = "UP",   [DOWN] = "DOWN",
    [LEFT] = "LEFT", [RIGHT] = "RIGHT", [ANY] = "ANY", [LAST] = "LAST"};

static const char *opcodes_str[13] = {
    [NOP] = "NOP", [MOV] = "MOV", [ADD] = "ADD", [SUB] = "SUB", [SWP] = "SWP",
    [SAV] = "SAV", [NEG] = "NEG", [JMP] = "JMP", [JEZ] = "JEZ", [JNZ] = "JNZ",
    [JGZ] = "JGZ", [JLZ] = "JLZ", [JRO] = "JRO",
};

int tis_dissassemble(uint16_t instruction, char *buffer) {
    if (instruction == 0) {
        return sprintf(buffer, "NOP");
    } 
    
    // MOV instructions
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
    } 
    
    // Jump instructions
    if (instruction & 0x4000 && instruction & 0x2000) {
        if (instruction & 0x1000) {
            // JMP, JEZ, JNZ, JLZ, JGZ
            tis_opcode_t opcode;
            switch (instruction & (~imm6_mask)) {
                case 0x7000:
                    opcode = JMP;
                    break;
                case 0x7040:
                    opcode = JEZ;
                    break;
                case 0x7110:
                    opcode = JNZ;
                    break;
                case 0x7100:
                    opcode = JLZ;
                    break;
                case 0x7080:
                    opcode = JLZ;
                    break;
                default:
                    return -1;
            }
            // Shows instruction address, not label
            return sprintf(buffer, "%s 0x%x", opcodes_str[opcode], instruction & imm6_mask);
        } else {
            // JRO
            tis_reg_t src = instruction & register_mask;
            return sprintf(buffer, "JRO %s", regs[src]);
        }
    }

    // NEG, SWP, SAV
    if (instruction & 0x4000) {
        tis_opcode_t opcode;
        switch (instruction) {
            case 0x4800:
                opcode = NEG;
                break;
            case 0x5000:
                opcode = SWP;
                break;
            case 0x4000:
                opcode = SAV;
                break;
            default:
                return -1;
        }
        return sprintf(buffer, "%s", opcodes_str[opcode]);
    } 

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

tis_reg_t tis_register_encode(const char *str) {
    for (unsigned char i = 0; i < (sizeof(regs) / sizeof(regs[0])); i++) {
        if (strcmp(str, regs[i]) == 0) {
            return (tis_reg_t)i;
        }
    }
    return INVALID;
}

// Number of operands per instruction
static char asm_operands[] = {
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

// Instruction identifiers
// Note: these are partial identifiers that exclude operands
static const uint16_t asm_codes[] = {
    [NOP] = 0x0,
    [MOV] = 0x8000,
    [ADD] = 0x0,
    [SUB] = 0x400,
    [SWP] = 0x5000,
    [SAV] = 0x4000,
    [NEG] = 0x4800,
    [JMP] = 0x7000,
    [JEZ] = 0x7040,
    [JNZ] = 0x7110,
    [JGZ] = 0x7100,
    [JLZ] = 0x7080,
    [JRO] = 0x6000,
};

// Decode
tis_opcode_t tis_opcode_encode(const char *str) {
    // All opcodes are 3 characters
    if (strlen(str) != 3) {
        return INVALID;
    }

    for (unsigned char i = 0; i < (sizeof(opcodes_str) / sizeof(opcodes_str[0])); i++) {
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
int tis_assemble_program(char *program, uint16_t *instructions) {

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

        // Check for maximum line length
        int line_len = strlen(line);
        if (line_len > 18) {
            puts("Line exceeded maximum length of 18 characters:");
            puts(line);
            return -1; 
        }

        // Divide line in code and comment
        char* comment;
        strtok_r(line, "#", &comment);

        // First token is either label, opcode, or empty
        char *strtok_ptr = NULL;
        char *token = strtok_r(line, token_delimiter, &strtok_ptr);

        // Check for empty line
        if (token == NULL) {
            continue;
        }

        // Check for label which ends with ':'
        int token_len = strlen(token);
        if (token[token_len-1] == ':') {
            // Avoid replacing existing label
            if (labels_pos[pc]) {
                printf("Multiple labels to instruction (%s, %s) \n", token, labels_pos[pc]);
                return -1;
            }

            // Save label without ':'
            token[token_len-1] = '\0';
            labels_pos[pc] = token;

            // Get next token
            token = strtok_r(NULL, token_delimiter, &strtok_ptr);
            if (token == NULL) {
                continue;
            }
        }

        // Check for valid opcode
        tis_opcode_t opcode = tis_opcode_encode(token);
        if (opcode == -1) {
            printf("Invalid opcode (%s) \n", token);
            return -1;
        }

        // Set instruction identifying bits
        instructions[pc] = asm_codes[opcode]; 

        // End if no further operands
        int opcount = asm_operands[opcode];
        if (opcount == 0) {
            pc++;
            continue;
        }

        // Get <SRC>
        char *src = strtok_r(NULL, token_delimiter, &strtok_ptr);
        if (src == NULL) {
            puts("Missing <SRC> operand");
            return -1;
        }

        // Check if <SRC> is register
        tis_reg_t src_reg = tis_register_encode(src);
        if (opcode == JMP || opcode == JEZ || opcode == JGZ || opcode == JLZ || opcode == JNZ) {
            // Store label string for later linking
            labels_ref[pc] = src;
        } else if (src_reg != INVALID) {
            // Place <SRC> in first 3 bits
            instructions[pc] &= ~register_mask;
            instructions[pc] |= src_reg; 

            if (opcode == MOV) {
            	instructions[pc] |= 0xC000;
            }

            if (opcode == SUB || opcode == ADD) {
                instructions[pc] |= 0x800;
            }
        } else {
            // Check if <SRC> is integer
            int integer;
            int result = sscanf(src, "%d", &integer);
            if (result != 1) {
                // Couldn't parse register nor number
                printf("Unable to parse <SRC> (%s)", src);
                return -1;
            }
            if (opcode == MOV || opcode == SUB || opcode == ADD ) {
                // Integer goes in first 11 bits.
                // Uses XOR to flip sign bit in case of SUB.
                instructions[pc] ^= tis_imm11_encode(integer);
            }
        }

        // End if no further operands
        if (opcount == 1) {
            pc++;
            continue;
        }

        // Get <DST>
        char *dst = strtok_r(NULL, token_delimiter, &strtok_ptr);
        if (dst == NULL) {
            puts("Missing <DST> operand");
            return -1;
        }

        // Check if <DST> is register
        tis_reg_t dst_reg = tis_register_encode(dst);
        if (dst_reg != INVALID) {
            // Place <DST> in bytes 13-11 
            instructions[pc] &= ~(register_mask<<11);
            instructions[pc] |= dst_reg << 11; 
        } else {
            printf("Unable to parse <DST> (%s)", dst);
            return -1;
        }

        // Increase after every line
        pc++;
    }

    // Link jump labels
    for (int ref_pc = 0; ref_pc < (sizeof(labels_ref) / sizeof(labels_ref[0])); ref_pc++) {
        // Skip empty
        if (labels_ref[ref_pc] == NULL) {
            continue;
        }

        for (int pos_pc = 0; pos_pc < (sizeof(labels_pos) / sizeof(labels_pos[0])); pos_pc++) {
            // Skip empty
            if (labels_pos[pos_pc] == NULL) {
                continue;
            }

            // Check if labels match
            if (strcmp(labels_pos[pos_pc], labels_ref[ref_pc]) == 0) {
                // Edit instruction referencing label
                instructions[ref_pc] |= pos_pc & imm6_mask;
            } 
        }
    }
    
    // Number of instructions written
    return pc;
}

void tis_disassembler_test() {
    const uint16_t instructions_bin[] = {
        0x0000, 0x01A5, 0x05A5, 0x0806, 
        0x0C00, 0x8AE8, 0xA358, 0xE804, 
        0xD802, 0x4800, 0x5000, 0x4000, 
        0x6001, 
    };

    const char *instructions_str[] = {
        "NOP",          "ADD 421",      "SUB 421",       "ADD ANY",
        "SUB NIL",      "MOV 744, ACC", "MOV 856, LEFT", "MOV LEFT, RIGHT",
        "MOV UP, DOWN", "NEG",          "SWP",           "SAV",
        "JRO ACC",      "JEZ 0x0"
    };

    for (int i = 0; i < (sizeof(instructions_bin) / sizeof(instructions_bin[0])); i++) {
        char result[32] = {0};
        tis_dissassemble(instructions_bin[i], result);

        if (strcmp(result, instructions_str[i])) {
            printf("Failed at %d\nExpected: %s\nResult: %s\n", i, instructions_str[i], result);
        }
    }
}

void tis_assembler_test() {
	puts("Starting assembler test");

    char* assembly =
        "START: NOP\n"
        "ADD 421 # TEST\n"
        "TWO: SUB 421\n"
        "ADD ANY\n"
        "SUB NIL\n"
        "MOV 744, ACC\n"
        "JEZ TWO\n"
        "JRO ACC";

    uint16_t expected[] = {
        0x0000, 0x01A5, 0x05A5, 0x0806, 0x0C00, 0x8AE8, 0x7042, 0x6001
    };

    uint16_t result[8];
    int count = tis_assemble_program(assembly, result);

    printf("Encoded %d instructions\n", count);

    int failures = 0;
    for (int i = 0; i < (sizeof(expected)/sizeof(expected[0])); i++) {
        if (expected[i] != result[i]) {
            printf("Failed at %d\nExpected: %X\nResult: %X\n", i, expected[i], result[i]);
            failures++;
        }
    }
    if (failures) {
        printf("Found %d failures", failures);
    } else {
        puts("Assembler success! :)");
    }
}
