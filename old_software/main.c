#include <stdio.h>
#include <tis_asm.h>
#include <tis_node.h>

struct tis_node a = {
    .config = 0x1,
    .instructions = {0},
};

struct tis_node b = {
    .config = 0x3,
    .instructions = {
        0x0, 
        0x0806,
        0x0806
    },
};

int main()
{
    char buffer[512];
    
    // Test node a
    node_info(&a,buffer);
    puts(buffer);

    // Test node b
    node_info(&b,buffer);
    puts(buffer);
    
    // Test assembly decoding
    test_asm();
    
    return 0;
}