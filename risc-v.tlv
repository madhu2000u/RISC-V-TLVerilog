\m4_TLV_version 1d: tl-x.org
\SV
   
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   m4_asm(ADD, x14, x13, x14)           // Incremental summation
   m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_asm_end()
   m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   //Program counter logic
   $next_pc[31:0] = $reset ? 0 : $pc[31:0];
   $pc[31:0] = >>1$next_pc + 1;
   
   //Instruction memory
   `READONLY_MEM($pc, $$instruction[31:0]);  //loads instruction from memory where $pc points to address and stores it in $$instruction

   //Decode Logic - based on RISC-V Instruction Set Specification
   //$instruction[1:0] must be 2'b11 for opcode to be valid so here we'll assume it is and ignore those bits. That is y we consider [6:2]
   $is_instr_type_u = $instruction[6:2] == 5'b00101 || $instruction[6:2] == 5'b01101;  //boolean to track instruction type

   $is_instr_type_i = $instruction[6:2] ==? 5'b0000x ||
                      $instruction[6:2] ==? 5'b001x0 ||    //==? operator allows some bits to be excluded from comparison by setting them to x which mean "don't care". i.e it mean the instruction can can a 0 or a 1 in those bits and the instruction is still valid.
                      $instruction[6:2] == 5'b11001;

   $is_instr_type_r = $instruction[6:2] == 5'b01011 || $instruction[6:2] == 5'b01100 || 
                      $instruction[6:2] == 5'b01110 || $instruction[6:2] == 5'b10100;

   $is_instr_type_s = $instruction[6:2] == 5'b01000 || $instruction[6:2] == 5'b01001;

   $is_instr_type_b = $instruction[6:2] == 5'b11000;

   $is_instr_type_j = $instruction[6:2] == 5'b11011;

   //Extract instruction fields from decoded instruction
   $funct3[2:0] = $instruction[14:12];
   $rs1[4:0] = $instruction[19:15];
   $rs2[4:0] = $instruction[24:20];
   $rd[4:0] = $instruction[11:7];
   $opcode[6:0] = $instruction[6:0];
   $imm[31:0] = $is_instr_type_i ? {{21{$instruction[31]}}, $instruction[30:20]} :
                $is_instr_type_s ? {{21{$instruction[31]}}, $instruction[30:25], $instruction[11:7]} :
                $is_instr_type_b ? {{20{$instruction[31]}}, $instruction[7], $instruction[30:25], $instruction[11:8], 1'b0} :
                $is_instr_type_u ? {$instruction[31:12], 12'b0} :
                $is_instr_type_j ? {{12{$instruction[31]}}, $instruction[19:12], $instruction[20], $instruction[30:21], 1'b0} : 32'b0;
   
   //Decode the specific instruction
   $decoded_instr[10:0] = {$instruction[30], $funct3, $opcode};

   $is_beq = $decoded_instr ==? 11'bx0001100011;    //x because these don't use instruction[30]
   $is_bne = $decoded_instr ==? 11'bx0011100011;
   $is_blt = $decoded_instr ==? 11'bx1001100011;
   $is_bge = $decoded_instr ==? 11'bx1011100011;
   $is_bltu = $decoded_instr ==? 11'bx1101100011;
   $is_bgeu = $decoded_instr ==? 11'bx1111100011;
   $is_addi = $decoded_instr ==? 11'bx0000010011;
   $is_add = $decoded_instr == 11'b00000110011;

   

   //check instruction fields validity
   $funct3_valid = $is_instr_type_r || $is_instr_type_i || $is_instr_type_s || $is_instr_type_b;    //funct3 is valid only for these types of instructions as per RISC-V sepecifications
   $rs1_valid = $is_instr_type_r || $is_instr_type_i || $is_instr_type_s || $is_instr_type_b;
   $rs2_valid = $$is_instr_type_r || $is_instr_type_s || $is_instr_type_b;
   $rd_valid = $is_instr_type_r || $is_instr_type_i || $is_instr_type_u || $is_instr_type_j;
   $imm_valid = $is_instr_type_i || $is_instr_type_s || $is_instr_type_b || $is_instr_type_u || $is_instr_type_j;
   //no need for opcode validity checking because opcode is always valid.
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = 1'b0;
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   m4+cpu_viz()
\SV
   endmodule