#include <stdint.h>

static volatile int16_t* node_config = (volatile int16_t*) 0x20;
static volatile int16_t* node_instruction = (volatile int16_t*) 0x22;

static volatile int16_t* input_stack_config = (volatile int16_t*) 0x50;
static volatile int16_t* input_stack_value = (volatile int16_t*) 0x52;

static volatile int16_t* output_stack_config = (volatile int16_t*) 0x54;
static volatile int16_t* output_stack_value = (volatile int16_t*) 0x56;


int main(void) {
    node_instruction[0] = 0xD802; // MOV UP, DOWN
    *node_config = 0; // 1 instruction

    // Provide inputs
    *input_stack_value = 1;
    *input_stack_value = 2;
    *input_stack_value = 3;
    *input_stack_value = 4;

    // Wait
    for (volatile int i = 0; i < 100; i++) {}

    // Store output
    node_instruction[4] = *output_stack_value;  // 1
    node_instruction[5] = *output_stack_value;  // 2
    node_instruction[6] = *output_stack_value;  // 3
    node_instruction[7] = *output_stack_value;  // 4
    node_instruction[8] = *output_stack_value;  // 0xFFFF (Empty)
}


// node_instruction[1] = 0xB001; // MOV 1, ANY
