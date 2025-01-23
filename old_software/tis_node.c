/*
 * tis_node.c
 *
 *  Created on: Dec 10, 2024
 *      Author: jorlap
 */

#include "tis_node.h"

struct tis_node* configure_node(void* base, const uint16_t instructions[], char instruction_count) {
    struct tis_node *node = (struct tis_node*) base;

    node->config = instruction_count & 0xF;

    if (instruction_count > 15) {
        return (struct tis_node*)0;
    }

    for (int i = 0; i < instruction_count; i++) {
        node->instructions[i] = instructions[i];
    }

    return node;
}

int node_info(struct tis_node* node, char buffer[]) {
    char instruction_count = node->config & 0xF;

    if (!instruction_count) {
        return sprintf(buffer, "Node unconfigured\n");
    }

    int ptr_offset = 0;

    ptr_offset += sprintf(buffer, "%d instructions:\n", instruction_count);

    for (int i = 0; i < instruction_count; i++) {
        uint16_t instruction = node->instructions[i];
        ptr_offset += decode(instruction, &buffer[ptr_offset]);
        buffer[ptr_offset] = '\n';
        ptr_offset += 1;
    }
}

