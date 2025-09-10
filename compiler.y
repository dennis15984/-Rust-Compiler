/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
    
    //#define YYDEBUG 1
    //int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char *id, int mut, char *type, float val);
    static Symbol * lookup_symbol(char *id);
    static void dump_symbol();

    /* Global variables */
    bool HAS_ERROR = false;

    FILE * fp;
    char func_sig[10];
    int resultcnt=1;
    int printcnt=0;
    int error_flag=0;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */

%union {
    Number *num;
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ID ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <s_val> STRING_LIT
%token <f_val> FLOAT_LIT
/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type TextContent FunctionCallStatement
%type <num> Expression Term Final Bool ArithmeticExpression AndExpression EqlExpression CmpExpression ShiftExpression

/* Yacc will start at this nonterminal */
%start Program

%left '+' '-'
%left '*' '/' '%'


%left '(' ')'

/* Grammar section */
%%

Program
    : GlobalStatementList 
    {
        dump_symbol();
    }
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclare
    | NEWLINE
;

FunctionDeclare
    : Function ExpressionWithBlock 
    {
        fprintf(fp, "return\n");
        fprintf(fp, ".end method\n");
    }
;

Function
    : FUNC ID '(' ListofParameter ')' 
    {
        fprintf(fp, ".method public static main([Ljava/lang/String;)V\n");
        fprintf(fp, ".limit stack 100\n");
        fprintf(fp, ".limit locals 100\n");
        printf("func: %s\n", $<s_val>2); 
        strcat(func_sig, ")V"); 
        insert_symbol($<s_val>2, -1, "func", -1); 
        strcpy(func_sig, "(");
    }
    | FUNC ID '(' ListofParameter ')' ARROW Type 
    {
        printf("func: %s\n", $<s_val>2); 
        strcat(func_sig, ")"); 
        strcat(func_sig, $7); 
        insert_symbol($<s_val>2, -1, "func", -1); 
        strcpy(func_sig, "(");
    }
;

ListofParameter
    : Parameter
    | ListofParameter ',' Parameter
;

Parameter
    : ID ':' Type 
    {
        insert_symbol($<s_val>1, 0, $3, 0); 
        strcat(func_sig, $3); 
    }

    | { strcat(func_sig, "V"); }
;

ExpressionWithBlock
    : Lparen StatementList '}' 
    { 
        dump_symbol();
    }
;

Lparen 
    : '{' {create_symbol();}
;

StatementList
    : StatementList Statement
    | Statement
;

Statement
    : LetStatement
    | PrintStatement
    | ExpressionWithBlock
    | ArithmeticExpression
    | FunctionCallStatement
    | AssignStatement
    | IfStatement
    | WHILEStatement
    | ForStatement
    | BreakStatement
;
WHILEStatement
    : WHILE ArithmeticExpression ExpressionWithBlock
;

ForStatement
    : FOR ID IN ID ExpressionWithBlock
;   
BreakStatement
    : BREAK '"' STRING_LIT '"' ';'
    {
         printf("STRING_LIT \"%s\"\n", $<s_val>4);
    }
;


IfStatement
    : IF ArithmeticExpression ExpressionWithBlock
    | IF FunctionCallStatement ExpressionWithBlock
    | IF ArithmeticExpression ExpressionWithBlock ELSE ExpressionWithBlock
    | IF FunctionCallStatement ExpressionWithBlock ELSE ExpressionWithBlock
;

FunctionCallStatement
    : ID '(' CallExpression ')'
     {
        if(lookup_symbol($<s_val>1)!= NULL){
            char *sig = lookup_symbol($<s_val>1)->func_sig; printf("call: %s%s\n", $<s_val>1, sig); $$ = sig;
        }
    }
;

CallExpression
    : ParameterCall
    | CallExpression ',' CallExpression
;

ParameterCall
    : ID
    |
;

AssignStatement 
    : ID ADD_ASSIGN ArithmeticExpression ';' 
    {
        Symbol *new_symbol = lookup_symbol($<s_val>1);
        if ($3->type == INT_TYPE) {
            fprintf(fp,"iload %d\nldc %d\niadd\nistore %d\n",new_symbol->addr,$3->val.i_val,new_symbol->addr);
        }else if($3->type == FLOAT_TYPE){
            fprintf(fp,"fload %d\nldc %f\nfadd\nfstore %d\n",new_symbol->addr,$3->val.f_val,new_symbol->addr);
        }
        printf("ADD_ASSIGN\n");
    }
    | ID SUB_ASSIGN ArithmeticExpression ';' 
    {
        Symbol *new_symbol = lookup_symbol($<s_val>1);
        if ($3->type == INT_TYPE) {
            fprintf(fp,"iload %d\nldc %d\nisub\nistore %d\n",new_symbol->addr,$3->val.i_val,new_symbol->addr);
        }else if($3->type == FLOAT_TYPE){
            fprintf(fp,"fload %d\nldc %f\nfsub\nfstore %d\n",new_symbol->addr,$3->val.f_val,new_symbol->addr);
        }
        printf("SUB_ASSIGN\n");
    }
    | ID MUL_ASSIGN ArithmeticExpression ';' 
    {
        Symbol *new_symbol = lookup_symbol($<s_val>1);
        if ($3->type == INT_TYPE) {
            fprintf(fp,"iload %d\nldc %d\nimul\nistore %d\n",new_symbol->addr,$3->val.i_val,new_symbol->addr);
        }else if($3->type == FLOAT_TYPE){
            fprintf(fp,"fload %d\nldc %f\nfmul\nfstore %d\n",new_symbol->addr,$3->val.f_val,new_symbol->addr);
        }
        printf("MUL_ASSIGN\n");
    }
    | ID DIV_ASSIGN ArithmeticExpression ';' 
    {
        Symbol *new_symbol = lookup_symbol($<s_val>1);
        if ($3->type == INT_TYPE) {
            fprintf(fp,"iload %d\nldc %d\nidiv\nistore %d\n",new_symbol->addr,$3->val.i_val,new_symbol->addr);
        }else if($3->type == FLOAT_TYPE){
            fprintf(fp,"fload %d\nldc %f\nfdiv\nfstore %d\n",new_symbol->addr,$3->val.f_val,new_symbol->addr);
        }
        printf("DIV_ASSIGN\n");
    }
    | ID REM_ASSIGN ArithmeticExpression ';' 
    {
        Symbol *new_symbol = lookup_symbol($<s_val>1);
        fprintf(fp,"iload %d\nldc %d\nirem\nistore %d\n",new_symbol->addr,$3->val.i_val,new_symbol->addr);
        printf("REM_ASSIGN\n");
    }
    | ID '=' ArithmeticExpression ';' 
    {
        if(lookup_symbol($<s_val>1)!= NULL){
            Symbol *new_symbol = lookup_symbol($<s_val>1);
            if ($3->type == INT_TYPE) {
                fprintf(fp,"ldc %d\n",$3->val.i_val);
                fprintf(fp , "istore %d\n", new_symbol->addr);
                  
            }
            if ($3->type == FLOAT_TYPE) {
                fprintf(fp,"ldc %f\n",$3->val.f_val);
                fprintf(fp , "fstore %d\n", new_symbol->addr);
                   
            }
            if ($3->type == BOOL_TYPE) {
                if($3->val.b_val == 0){
                    fprintf(fp,"iconst_0\n");
                }else if($3->val.b_val != 0){
                    fprintf(fp,"iconst_1\n");
                }
                
            }
            printf("ASSIGN\n");
        }else{
            error_flag=1;
            printf("error:%d: undefined: %s\n",(yylineno+1),$<s_val>1);
        }
        
    }
    | ID '=' '"' STRING_LIT '"' ';' 
    {
        Symbol *new_symbol = lookup_symbol($<s_val>1);
        fprintf(fp,"ldc \"%s\"\n",$<s_val>4);
        fprintf(fp , "astore %d\n", new_symbol->addr);
        printf("STRING_LIT \"%s\"\n", $<s_val>4); printf("ASSIGN\n");
    }
    | ID '=' '"' '"' ';' 
    {
        printf("STRING_LIT \"\"\n"); printf("ASSIGN\n");
    }
;
PrintStatement
    : PRINTLN '(' TextContent ')' ';' 
    {
         printf("PRINTLN %s\n", $3);
         
    }

    | PRINT '(' TextContent ')' ';' 
    { 
        printf("PRINT %s\n", $3);
    }
    
;

TextContent  
    : '"' STRING_LIT '"' 
    {
        printf("STRING_LIT \"%s\"\n", $2); 
        $$ = "str";
        fprintf(fp, "ldc \"%s\"\n", $2);
        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        fprintf(fp, "swap\n");
        fprintf(fp, "invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
    }
    | ArithmeticExpression
    {
        if($1->type == INT_TYPE){
            $$ = "i32";
            fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            fprintf(fp, "swap\n");
            fprintf(fp, "invokevirtual java/io/PrintStream/println(I)V\n");
        }else if($1->type == FLOAT_TYPE){
            $$ = "f32";
            fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            fprintf(fp, "swap\n");
            fprintf(fp, "invokevirtual java/io/PrintStream/println(F)V\n");
        }else if($1->type == BOOL_TYPE){
            $$ = "bool";
            fprintf(fp, "result%d:\n",resultcnt);        
            resultcnt+=2;    
            fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            fprintf(fp, "swap\n");
            fprintf(fp, "invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }else{
            $$ = "str";
            fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            fprintf(fp, "swap\n");
            fprintf(fp, "invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }
    } 
    
;

LetStatement

    : LET ID ':' Type '=' '"' STRING_LIT '"' ';' 
    {
        printf("STRING_LIT \"%s\"\n", $7); 
        insert_symbol($<s_val>2, 0, $4, -1);
        Symbol *new_symbol = lookup_symbol($<s_val>2);
        fprintf(fp,"ldc \"%s\"\n",$7);
        fprintf(fp , "astore %d\n", new_symbol->addr);
        
    }
    | LET MUT ID ':' Type '=' '"' STRING_LIT '"' ';' 
    {
        printf("STRING_LIT \"%s\"\n", $8); 
        insert_symbol($<s_val>3, 1, $5, -1);
    }
    | LET ID '=' '"' STRING_LIT '"' ';' 
    {
        printf("STRING_LIT \"%s\"\n", $5); 
        insert_symbol($<s_val>2, 0, "str", -1);
    }
    | LET MUT ID '=' '"' STRING_LIT '"' ';' 
    {
        printf("STRING_LIT \"%s\"\n", $6); 
        insert_symbol($<s_val>3, 1, "str", -1);
    }

    | LET ID ':' Type '=' ArithmeticExpression ';' 
    {
        
        if ($6->type == INT_TYPE) {
            insert_symbol($<s_val>2, 0, $4, $6->val.i_val);
            Symbol *new_symbol = lookup_symbol($<s_val>2);
            fprintf(fp,"ldc %d\n",$6->val.i_val);
            fprintf(fp , "istore %d\n", new_symbol->addr);
        }else if($6->type == FLOAT_TYPE){
            insert_symbol($<s_val>2, 0, $4, $6->val.f_val);
            Symbol *new_symbol = lookup_symbol($<s_val>2);
            fprintf(fp,"ldc %f\n",$6->val.f_val);
            fprintf(fp , "fstore %d\n", new_symbol->addr);
        }
        else if($6->type == BOOL_TYPE){
            insert_symbol($<s_val>2, 0, $4, $6->val.b_val);
            if($6->val.b_val == 0){
                fprintf(fp,"iconst_0\n");
            }else if($6->val.b_val != 0){
                fprintf(fp,"iconst_1\n");
            }
        
            
        }
    }
    | LET MUT ID ':' Type '=' ArithmeticExpression ';' 
    {
        if ($7->type == INT_TYPE) {
            insert_symbol($<s_val>3, 1, $5, $7->val.i_val);
            Symbol *new_symbol = lookup_symbol($<s_val>3);
            fprintf(fp,"ldc %d\n",$7->val.i_val);
            fprintf(fp , "istore %d\n", new_symbol->addr);
            
        }else if($7->type == FLOAT_TYPE){          
            insert_symbol($<s_val>3, 1, $5, $7->val.f_val);
            Symbol *new_symbol = lookup_symbol($<s_val>3);
            fprintf(fp,"ldc %f\n",$7->val.f_val);
            fprintf(fp , "fstore %d\n", new_symbol->addr);
        }else if($7->type == BOOL_TYPE){
            insert_symbol($<s_val>3, 1, $5, $7->val.b_val);
            if($7->val.b_val == 0){
                fprintf(fp,"iconst_0\n");
            }else if($7->val.b_val != 0){
                fprintf(fp,"iconst_1\n");
            }
           
           
        }
    }
    | LET ID '=' ArithmeticExpression ';' 
    {     
        //auto_type_detection
        if ($4->type == INT_TYPE) {
            insert_symbol($<s_val>2, 0, "INT", $4->val.i_val);
            Symbol *new_symbol = lookup_symbol($<s_val>2);
            fprintf(fp,"ldc %d\n",$4->val.i_val);
            fprintf(fp , "istore %d\n", new_symbol->addr);
        }else if($4->type == FLOAT_TYPE){
            insert_symbol($<s_val>2, 0, "FLOAT", $4->val.f_val);
            Symbol *new_symbol = lookup_symbol($<s_val>2);
            fprintf(fp,"ldc %f\n",$4->val.f_val);
            fprintf(fp , "fstore %d\n", new_symbol->addr);
        }else if($4->type == BOOL_TYPE){
            insert_symbol($<s_val>2, 0, "BOOL", $4->val.b_val);
            if($4->val.b_val == 0){
                fprintf(fp,"iconst_0\n");
            }else if($4->val.b_val != 0){
                fprintf(fp,"iconst_1\n");
            }
            
        }
    }
    | LET MUT ID '=' ArithmeticExpression ';' 
    {
        
        if ($5->type == INT_TYPE) {
             insert_symbol($<s_val>3, 1, "INT", $5->val.i_val);
        }else{
            insert_symbol($<s_val>3, 1, "FLOAT", $5->val.f_val);
        }
    }

    | LET ID ':' Type ';' 
    {
        insert_symbol($<s_val>2, 0, $4, 0);
    }
    | LET MUT ID ':' Type ';' 
    {
        insert_symbol($<s_val>3, 1, $5, 0);
    }

    | LET ID ':' Type '=' '"' '"' ';' 
    {
        printf("STRING_LIT \"\"\n"); 
        insert_symbol($<s_val>2, 0, $4, -1);
        
    }
    | LET MUT ID ':' Type '=' '"' '"' ';' 
    {
        printf("STRING_LIT \"\"\n"); 
        insert_symbol($<s_val>3, 1, $5, -1);
        Symbol *new_symbol = lookup_symbol($<s_val>3);
        fprintf(fp,"ldc \"\"\n");
        fprintf(fp , "astore %d\n", new_symbol->addr);
    }
    | LET ID '=' '"' '"' ';' 
    {
        printf("STRING_LIT \"\"\n"); 
        insert_symbol($<s_val>2, 0, "STR", -1);
    }

    | LET MUT ID '=' '"' '"' ';' 
    {
        printf("STRING_LIT \"\"\n"); 
        insert_symbol($<s_val>3, 0, "STR", -1);
    }
    | LET ID ':' Type '=' LoopStatement ';'{
        insert_symbol($<s_val>2, 0, "STR", -1);
    }
    | LET  ID ':' Type '=' DotExpression 

    | LET ID ':' '[' Type ';'  INT_LIT ']' '=' ForeachStatementList
    
;

LoopStatement 
    : LOOP ExpressionWithBlock
;

DotExpression
    : '&' ID '[' DOTDOT INT_LIT ']' ';'
    | '&' ID '[' INT_LIT DOTDOT INT_LIT ']' ';'
    | '&' ID '[' INT_LIT DOTDOT  ']' ';'
;   

ForeachStatementList
    : '{' INT_LIT ForeachStatement  '}' ';'
;

ForeachStatement
    : ForeachStatement ',' INT_LIT
    |
;

ArithmeticExpression
    : ArithmeticExpression LOR AndExpression 
    {
        fprintf(fp,"ixor\n");
        printf("LOR\n"); 
        $1->val.b_val =  $1->val.b_val || $3->val.b_val;
        $1->type = BOOL_TYPE; $$ = $1;
    }
    | AndExpression { $$ = $1;}
;

AndExpression
    : AndExpression LAND EqlExpression 
    {
        fprintf(fp,"iand\n");
        printf("LAND\n"); 
        $1->val.b_val =  $1->val.b_val && $3->val.b_val;
        $1->type = BOOL_TYPE; $$ = $1;
    }
    | EqlExpression { $$ = $1;}
;

EqlExpression
    : EqlExpression EQL CmpExpression 
    {
        printf("EQL\n");
        if($1->type == INT_TYPE){
            $1->val.b_val =  $1->val.i_val == $3->val.i_val;
        }else{
            $1->val.b_val =  $1->val.f_val == $3->val.f_val;
        } 
        $1->type = BOOL_TYPE; 
        $$ = $1;
    }
    | EqlExpression NEQ CmpExpression 
    {
        printf("NEQ\n");
        if($1->type == INT_TYPE){
            $1->val.b_val =  $1->val.i_val != $3->val.i_val;
        }else{
            $1->val.b_val =  $1->val.f_val != $3->val.f_val;
        }  
        $1->type = BOOL_TYPE; 
        $$ = $1;
    }
    | CmpExpression {$$ = $1;}
;

CmpExpression
    : CmpExpression '>' ShiftExpression 
    {
        if($1->type!=INT_TYPE&&$1->type!=FLOAT_TYPE){   
            if($3->type==INT_TYPE)
            printf("error:%d: invalid operation: GTR (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($3->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: GTR (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("GTR\n");
        }else if($3->type!=INT_TYPE&&$3->type!=FLOAT_TYPE){
            if($1->type==INT_TYPE)
            printf("error:%d: invalid operation: GTR (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($1->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: GTR (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("GTR\n");
        }else{
            printf("GTR\n");
            if($1->type == INT_TYPE){
                $1->val.b_val = $1->val.i_val > $3->val.i_val;
            }else{
                $1->val.b_val = $1->val.f_val > $3->val.f_val;
            }
            $1->type = BOOL_TYPE; 
            $$ = $1;
        }
    }

    | CmpExpression '<' ShiftExpression 

    {
        if($1->type!=INT_TYPE&&$1->type!=FLOAT_TYPE){
            if($3->type==INT_TYPE)
            printf("error:%d: invalid operation: LSS (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($3->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: LSS (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("LSS\n");
        }else if($3->type!=INT_TYPE&&$3->type!=FLOAT_TYPE){
            if($1->type==INT_TYPE)
            printf("error:%d: invalid operation: LSS (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($1->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: LSS (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("LSS\n");
        }else{
            printf("LSS\n");
            if ($1->type == INT_TYPE){
                $1->val.b_val = $1->val.i_val < $3->val.i_val;
            }else{
                $1->val.b_val = $1->val.f_val < $3->val.f_val;  
            }
            $1->type = BOOL_TYPE; 
            $$ = $1;
        }
    }

    | CmpExpression GEQ ShiftExpression 

    {
        if($1->type!=INT_TYPE&&$1->type!=FLOAT_TYPE){
            if($3->type==INT_TYPE)
            printf("error:%d: invalid operation: GEQ (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($3->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: GEQ (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("GEQ\n");
        }else if($3->type!=INT_TYPE&&$3->type!=FLOAT_TYPE){
            if($1->type==INT_TYPE)
            printf("error:%d: invalid operation: GEQ (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($1->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: GEQ (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("GEQ\n");
        }else{
            printf("GEQ\n");
            if ($1->type == INT_TYPE){
                $1->val.b_val = $1->val.i_val >= $3->val.i_val;
            }else{
                $1->val.b_val = $1->val.f_val >= $3->val.f_val;  
            }
            $1->type = BOOL_TYPE; 
            $$ = $1;
        }
    }
    
    | CmpExpression LEQ ShiftExpression 

    {
        if($1->type!=INT_TYPE){
            if($3->type==INT_TYPE&&$1->type!=FLOAT_TYPE)
            printf("error:%d: invalid operation: LEQ (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($3->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: LEQ (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("LEQ\n");
        }else if($3->type!=INT_TYPE&&$3->type!=FLOAT_TYPE){
            if($1->type==INT_TYPE)
            printf("error:%d: invalid operation: LEQ (mismatched types undefined and %s)\n",(yylineno+1),"i32");
            if($1->type==FLOAT_TYPE)
            printf("error:%d: invalid operation: LEQ (mismatched types undefined and %s)\n",(yylineno+1),"f32");
            printf("LEQ\n");
        }else{
        printf("LEQ\n");
            if ($1->type == INT_TYPE){
                $1->val.b_val = $1->val.i_val <= $3->val.i_val;
            }else{
                $1->val.b_val = $1->val.f_val <= $3->val.f_val;  
            }
            $1->type = BOOL_TYPE; 
            $$ = $1;
        }
    }

    | ShiftExpression {$$ = $1;}
;

ShiftExpression
    : ShiftExpression RSHIFT Expression 
    {
        if($1->type==INT_TYPE&&$3->type==FLOAT_TYPE){
            printf("error:%d: invalid operation: RSHIFT (mismatched types i32 and f32)\n",(yylineno+1));
            printf("RSHIFT\n");
        }else if ($1->type==FLOAT_TYPE&&$3->type==INT_TYPE){
            printf("error:%d: invalid operation: RSHIFT (mismatched types f32 and i32)\n",(yylineno+1));
            printf("RSHIFT\n");
        }else{
            printf("RSHIFT\n");
            $1->val.i_val = $1->val.i_val >> $3->val.i_val; 
            $$ = $1;
        }
    }
    | ShiftExpression LSHIFT Expression 
    {
        if($1->type==INT_TYPE&&$3->type==FLOAT_TYPE){
            printf("error:%d: invalid operation: LSHIFT (mismatched types i32 and f32)\n",(yylineno+1));
            printf("LSHIFT\n");
        }else if ($1->type==FLOAT_TYPE&&$3->type==INT_TYPE){
            printf("error:%d: invalid operation: LSHIFT (mismatched types f32 and i32)\n",(yylineno+1));
            printf("LSHIFT\n");
        }else
        {
            printf("LSHIFT\n");
            $1->val.i_val = $1->val.i_val << $3->val.i_val; 
            $$ = $1;
        }
    }
    | Expression {$$ = $1;}
;

Expression
    : Expression '+' Term 
    {
        
        printf("ADD\n");
        if( $1->type == INT_TYPE ){
            $$->val.i_val = $1->val.i_val + $3->val.i_val;
            $$->type = INT_TYPE;
            fprintf(fp,"iadd\n");
        }else{
            $$->val.f_val = $1->val.f_val + $3->val.f_val;
            $$->type = FLOAT_TYPE;
            fprintf(fp,"fadd\n");
        }
    }  
    | Expression '-' Term 
    {
         printf("SUB\n");
         if( $1->type == INT_TYPE ){
            $$->val.i_val = $1->val.i_val - $3->val.i_val;
            $$->type = INT_TYPE;
            fprintf(fp,"isub\n");
         }else{
            $$->val.f_val = $1->val.f_val - $3->val.f_val;
            $$->type = FLOAT_TYPE;
            fprintf(fp,"fsub\n");
         }
    }  
    | Term { $$ = $1;}
;

Term
    : Term '*' Final
    {
        
         printf("MUL\n");
         if( $1->type == INT_TYPE ){
            $$->val.i_val = $1->val.i_val * $3->val.i_val;
            $$->type = INT_TYPE;
            fprintf(fp,"imul\n");
         }else{
            $$->val.f_val = $1->val.f_val * $3->val.f_val;
            $$->type = FLOAT_TYPE;
            fprintf(fp,"fmul\n");
         }
    }                                  
    | Term '/' Final
     {
         printf("DIV\n");
         if( $1->type == INT_TYPE ){
            $$->val.i_val = $1->val.i_val / $3->val.i_val;
            $$->type = INT_TYPE;
            fprintf(fp,"idiv\n");
         }else{
            $$->val.f_val = $1->val.f_val / $3->val.f_val;
            $$->type = FLOAT_TYPE;
            fprintf(fp,"fdiv\n");
         }
    }           
    | Term '%' Final 
    { 
        if($3->val.i_val != 0){
            printf("REM\n");  
            fprintf(fp,"irem\n");                                              
            $$->val.i_val = $1->val.i_val % $3->val.i_val;
            $$->type = INT_TYPE;
        }                                                                           
    }
    | Final {$$ = $1;}
;

Final
    : '!' Final 
    {
         printf("NOT\n"); 
         if($2->type == BOOL_TYPE){
            $2->val.b_val = !$2->val.b_val;
         }else if ($2->val.i_val == 0){
            $2->val.b_val = 1; 
         }else{
            $2->val.b_val = 0; 
         }
         $2->type = BOOL_TYPE; 
         $$ = $2;
    }

    | '-' Final 
    { 
        printf("NEG\n");
        fprintf(fp,"ineg\n");
        if ($2->type == INT_TYPE){
            $2->val.i_val = -$2->val.i_val;
            $$ = $2;
        }else{
            $2->val.i_val = -$2->val.f_val;
            $$ = $2;
        }                          
                          
    }
    | '(' Expression ')' { $$ = $2;}

    | Bool 
    { 
        $$ = $1;

    }

    | INT_LIT 
    {
        
        printf("INT_LIT %d\n", $1);
        Number *new_num = (Number *)malloc(sizeof(Number));
        new_num->val.i_val = $1;
        new_num->type = INT_TYPE;
        $$ = new_num;
        //fprintf(fp,"ldc %d\n" ,new_num->val.i_val);
    }
    | FLOAT_LIT 
    {
        printf("FLOAT_LIT %f\n", $1);
        Number *new_num = (Number *)malloc(sizeof(Number));
        new_num->val.f_val = $1;
        new_num->type = FLOAT_TYPE;
        $$ = new_num;
        //fprintf(fp,"ldc %f\n" ,new_num->val.f_val);
    }
    | ID 
    {  
        if(lookup_symbol($<s_val>1)!= NULL){
            Symbol *new_symbol = lookup_symbol($<s_val>1);
            //fprintf(fp,"%s---------------%d\n",new_symbol->type,new_symbol->addr); 
            printf("IDENT (name=%s, address=%d)\n", $<s_val>1, new_symbol->addr);
            Number *new_num = (Number *)malloc(sizeof(Number));
            if (strcmp(new_symbol->type, "i32") == 0){
                fprintf(fp,"iload %d\n" ,new_symbol->addr);
                new_num->val.i_val = (int) new_symbol->value;
                new_num->type = INT_TYPE;
            }else if (strcmp(new_symbol->type, "bool") == 0) { 
                if (new_symbol->value != 0){
                    new_num->val.b_val = 1;
                }else{
                    new_num->val.b_val = 0;
                }
                fprintf(fp,"ifeq printf_zero%d\n",printcnt);
                fprintf(fp,"ldc \"true\"\n");
                fprintf(fp,"goto result%d\n",resultcnt);
                fprintf(fp,"printf_zero%d:\n",printcnt);
                printcnt+=2;
                fprintf(fp,"ldc \"false\"\n");   
                new_num->type = BOOL_TYPE;
            }else if (strcmp(new_symbol->type, "str") == 0) {
                fprintf(fp,"aload %d\n" ,new_symbol->addr);
                new_num->val.s_val = new_symbol->name;
                new_num->type = STR_TYPE;
            }else if (strcmp(new_symbol->type, "f32") == 0) {
                fprintf(fp,"fload %d\n" ,new_symbol->addr);
                new_num->val.f_val = new_symbol->value;
                new_num->type = FLOAT_TYPE;
            }
            $$ = new_num;
        }else{
            error_flag=1;
            printf("error:%d: undefined: %s\n",(yylineno+1),$<s_val>1);
        }
            
    }

    | ID AS Type 
    {
        char str[4] = "";
        if(lookup_symbol($<s_val>1)!= NULL){
            Symbol *new_symbol = lookup_symbol($<s_val>1);
            if (strcmp(new_symbol->type, "i32") == 0) {
                strcat(str, "i2");
            } else if (strcmp(new_symbol->type, "f32") == 0) {
                strcat(str, "f2");
            } else if (strcmp(new_symbol->type, "bool") == 0) {
                strcat(str, "b2");
            } else if (strcmp(new_symbol->type, "str") == 0) {
                strcat(str, "s2");
            }
            printf("IDENT (name=%s, address=%d)\n", $<s_val>1, new_symbol->addr);
            Number *new_num = (Number *)malloc(sizeof(Number));
            if (strcmp($3, "INT") == 0){
                strcat(str, "i");
                new_num->val.i_val = (int) new_symbol->value;
                new_num->type = INT_TYPE;
            }else if (strcmp($3, "FLOAT") == 0) {
                strcat(str, "f");
                new_num->val.f_val = new_symbol->value;
                new_num->type = FLOAT_TYPE;
            }else if (strcmp($3, "STR") == 0) {
                strcat(str, "s");
                new_num->val.s_val = new_symbol->name;
                new_num->type = STR_TYPE;
            }else if (strcmp($3, "BOOL") == 0) {
                strcat(str, "b");
                if (new_symbol->value != 0){
                    new_num->val.b_val = 1;
                }else{
                    new_num->val.b_val = 0;
                }
                new_num->type = BOOL_TYPE;
            }
            printf("%s\n", str);
            $$ = new_num;
        }else{
            error_flag=1;
        }
    }

    | INT_LIT AS Type 
    {
        char str[4] = "i2";
        printf("INT_LIT %d\n", $1);
        Number *new_num = (Number *)malloc(sizeof(Number));
        if (strcmp($3, "INT") == 0){
            strcat(str, "i");
            new_num->type = INT_TYPE;
            new_num->val.i_val = $1;                 
        }else if (strcmp($3, "BOOL") == 0) {
            strcat(str, "b");
            new_num->type = BOOL_TYPE;
            if($1 != 0){
                new_num->val.b_val = 1; 
            }else{
                new_num->val.b_val = 0; 
            }
        }else if (strcmp($3, "str") == 0) {
            strcat(str, "s");
            sprintf(new_num->val.s_val, "%d", $1);
            new_num->type = STR_TYPE;
        }else if (strcmp($3, "FLOAT") == 0) {
            strcat(str, "f");
            new_num->type = FLOAT_TYPE;
            new_num->val.f_val = (float) $1;
        }
        printf("%s\n", str);
        $$ = new_num;
    }
    | FLOAT_LIT AS Type 
    {
        char str[4] = "f2";
        printf("FLOAT_LIT %f\n", $1);
        Number *new_num = (Number *)malloc(sizeof(Number));
        if (strcmp($3, "INT") == 0){
            strcat(str, "i");
            new_num->type = INT_TYPE;
            new_num->val.i_val = (int) $1;                    
        }else if (strcmp($3, "FLOAT") == 0) {
            strcat(str, "f");
            new_num->type = FLOAT_TYPE;
            new_num->val.f_val = $1;
        }else if (strcmp($3, "str") == 0) {
            strcat(str, "s");
            sprintf(new_num->val.s_val, "%f", $1);
            new_num->type = STR_TYPE;
        }
        else if (strcmp($3, "BOOL") == 0) {
            strcat(str, "b");
            new_num->type = BOOL_TYPE;
            if($1 != 0){
                new_num->val.b_val = 1; 
            }else{
                new_num->val.b_val = 0; 
            }
        }
        printf("%s\n", str);
        $$ = new_num;
    }
;

Bool
    : TRUE 
    { 
        printf("bool TRUE\n");
        Number *new_num = (Number *)malloc(sizeof(Number));
        new_num->type = BOOL_TYPE;
        new_num->val.b_val = true;
        $$ = new_num;
    }
    | FALSE 
    { 
        printf("bool FALSE\n");
        Number *new_num = (Number *)malloc(sizeof(Number));
        new_num->type = BOOL_TYPE;
        new_num->val.b_val = false;
        $$ = new_num;
    }
;

Type
    : INT { $$ = "INT";}
    | FLOAT { $$ = "FLOAT";}
    | BOOL { $$ = "BOOL";}
    | '&' STR { $$ = "STR";}
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r"); 
    } else {
        yyin = stdin;
    }

    fp = fopen("hw3.j", "w+");
    fprintf(fp, ".source hw3.j\n");
    fprintf(fp, ".class public Main\n");
    fprintf(fp, ".super java/lang/Object\n");
    strcpy(func_sig, "(");
    scope_level = -1;
    yylineno = 0;
    addr = -1;
    table_head = NULL;
    

    create_symbol();
    yyparse();
    
	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    fclose(fp);
    if(error_flag==1){
        remove("hw3.j");
    }
    return 0;
}

static void create_symbol() {
    NodeforTable * newTable = (NodeforTable *)malloc(sizeof(NodeforTable));
    newTable->next = table_head;
    newTable->cnt = 0;
    table_head = newTable;
    printf("> Create symbol table (scope level %d)\n", ++scope_level);
}

static void insert_symbol(char *id, int mut, char *type, float val) {
    
    int cnt = table_head->cnt;
    table_head->symbol_table[cnt].index = cnt;
    table_head->symbol_table[cnt].mut = mut;
    table_head->symbol_table[cnt].name = strdup(id);

    if (strcmp(type, "func") == 0) {
        table_head->symbol_table[cnt].type = strdup(type);
        table_head->symbol_table[cnt].func_sig = strdup(func_sig);
    } else if (strcmp(type, "INT") == 0) {
        table_head->symbol_table[cnt].type = "i32";
        table_head->symbol_table[cnt].func_sig = "-";
    } else if (strcmp(type, "FLOAT") == 0) {
        table_head->symbol_table[cnt].type = "f32";
        table_head->symbol_table[cnt].func_sig = "-";
    }  else if (strcmp(type, "BOOL") == 0) {
        table_head->symbol_table[cnt].type = "bool";
        table_head->symbol_table[cnt].func_sig = "-";
    } else if (strcmp(type, "STR") == 0) {
        table_head->symbol_table[cnt].type = "str";
        table_head->symbol_table[cnt].func_sig = "-";
    }

    table_head->symbol_table[cnt].addr = addr;
    table_head->symbol_table[cnt].value = val;
    table_head->symbol_table[cnt].lineno = yylineno + 1;
    table_head->cnt++;

    printf("> Insert `%s` (addr: %d) to scope level %d\n", id, addr++, scope_level);
}

static Symbol *lookup_symbol(char *id) {
    NodeforTable * ptr = table_head;
    for(;;){
        for (int i = 0; i < ptr->cnt; i++) {
            if (strcmp(ptr->symbol_table[i].name, id) == 0) {
                return &ptr->symbol_table[i];
            }
        }
        ptr = ptr->next;
        if(ptr == NULL){
            break;
        }
    }
    return NULL;
    exit(1);
}

static void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", scope_level--);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    for (int i = 0; i < table_head->cnt; i++)
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            table_head->symbol_table[i].index, table_head->symbol_table[i].name, table_head->symbol_table[i].mut, table_head->symbol_table[i].type, table_head->symbol_table[i].addr, table_head->symbol_table[i].lineno, table_head->symbol_table[i].func_sig);
    
    NodeforTable *temp = table_head;
    table_head = table_head->next;
    free(temp);
}
