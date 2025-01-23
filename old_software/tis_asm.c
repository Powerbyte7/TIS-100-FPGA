#include <stdint.h>
#include <string.h>

#include "tis_asm.h"

int decode(uint16_t instruction, char* buffer) {
    
    if (instruction & 0x8000 && instruction & 0x4000) {
        // MOV <SRC>, <DST>
        tis_reg_t src = instruction & register_mask;
        tis_reg_t dst = (instruction >> 11) & register_mask;
        return sprintf(buffer, "MOV %s, %s", regs[src], regs[dst]);
    } else if (instruction & 0x8000) {
        // MOV #<imm11>, <DST>
        tis_reg_t dst = (instruction >> 11) & register_mask;
        return sprintf(buffer, "MOV %d, %s", instruction & imm11_mask, regs[dst]);
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

int test_asm() {
    for (int i = 0; i < (sizeof(instructions_bin) / sizeof(instructions_bin[0])); i++) {
        char buffer[32] = {0};
        decode(instructions_bin[i], buffer);
        printf("%s\n", buffer);
        if (strcmp(buffer, instructions_str[i])) {
            printf("^ Expected %s\n", instructions_str[i]);
        }
    }
}