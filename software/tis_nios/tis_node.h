/*
 * tis_node.h
 *
 *  Created on: Dec 10, 2024
 *      Author: Powerbyte7
 */

#ifndef TIS_NODE_H_
#define TIS_NODE_H_

#include <stdint.h>
#include "tis_asm.h"

struct tis_node {
    uint16_t config;
    uint16_t instructions[15];
};

_Static_assert((sizeof(struct tis_node) == sizeof(uint16_t)*16),
               "TIS Node struct incorrectly mapped to memory");

struct tis_node* configure_node(void* base, const uint16_t instructions[], char instruction_count);
int node_info(struct tis_node* node, char buffer[]);

#endif /* TIS_NODE_H_ */
