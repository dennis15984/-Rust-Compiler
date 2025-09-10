#ifndef COMPILER_COMMON_H
#define COMPILER_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
/* Add what you need */

int addr;
int scope_level;

typedef union {
        int i_val;
        float f_val;
        bool b_val;
        char *s_val;
} Num;

typedef struct number{
    Num val;
    char type;
} Number;

typedef struct {
    int index;
    char *name;
    int mut;
    char *type;
    int addr;
    int lineno;
    char *func_sig;
    float value;
} Symbol;

typedef struct node {
    int cnt;
    Symbol symbol_table[100];
    struct node *next;
} NodeforTable;

NodeforTable *table_head;

#define INT_TYPE 1
#define FLOAT_TYPE 2
#define BOOL_TYPE 3
#define STR_TYPE 4

#endif /* COMPILER_COMMON_H */