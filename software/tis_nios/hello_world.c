/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <stdio.h>

#include "tis_node.h"

//struct tis_node a = {
//    .config = 0x1,
//    .instructions = {0},
//};
//
//struct tis_node b = {
//    .config = 0x3,
//    .instructions = {
//        0x0,
//        0x0806,
//        0x0806
//    },
//};

int main()
{
  puts("Hello from Nios II!\n");
  // char buffer[512];

//  // Test node a
//  node_info(&a,buffer);
//  puts(buffer);
//
//  // Test node b
//  node_info(&b,buffer);
//  puts(buffer);
//
  // Test assembly decoding
  tis_disassembler_test();

   // Test assembly encoding
   tis_assembler_test();

  return 0;
}
