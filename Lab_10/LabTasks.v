module pc_reg #(parameter RESET_VAL = 32'h0000_0000)( 
    input  wire        clk, reset, 
    input  wire [31:0] next_pc, 
    output reg  [31:0] pc 
); 
    always @(posedge clk or posedge reset) begin 
        if (reset) pc <= RESET_VAL; 
        else       pc <= next_pc; 
    end 
endmodule 
 
// PC+4 adder 
module pc_adder(input wire [31:0] pc, output wire [31:0] pc4); 
    assign pc4 = pc + 32'd4; 
endmodule 
 
// Used for PC mux, ASel mux, BSel mux 
module mux2 #(parameter W = 32)( 
    input  wire [W-1:0] in0, in1, 
    input  wire         sel, 
    output wire [W-1:0] out 
); 
    assign out = sel ? in1 : in0; 
endmodule 
 
// Instruction memory: 64-word array, word addressed by pc[7:2]. 
// Out-of-range addresses  return  (ADDI x0,x0,0). 
module imem(input wire [31:0] pc, output wire [31:0] inst); 
    reg [31:0] mem [0:63]; 
    integer i; 
    initial for (i = 0; i < 64; i = i + 1) mem[i] = 32'h0000_0013;  // NOP 
    assign inst = (pc[31:8] == 24'd0) ? mem[pc[7:2]] : 32'h0000_0013; 
endmodule 
 
// 32 x 32-bit register file, 2 read ports, 1 synch write port, x0 = 0 
module regfile( 
    input  wire        clk, RegWEn, 
    input  wire [4:0]  AddrA, AddrB, AddrD, 
    input  wire [31:0] DataD, 
    output wire [31:0] DataA, DataB 
);
 reg [31:0] regs [0:31]; 
    integer i; 
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0; 
 
    always @(posedge clk) 
        if (RegWEn && AddrD != 5'd0) regs[AddrD] <= DataD; 
 
    assign DataA = (AddrA == 5'd0) ? 32'd0 : regs[AddrA]; 
    assign DataB = (AddrB == 5'd0) ? 32'd0 : regs[AddrB]; 
endmodule 
 
// Immediate generator. ImmSel: 00=I, 01=S, 10=B, 11=J 
module imm_gen( 
    input  wire [31:0] inst, 
    input  wire [1:0]  ImmSel, 
    output reg  [31:0] Imm 
); 
    always @(*) begin 
        case (ImmSel) 
            2'b00: Imm = {{20{inst[31]}}, inst[31:20]};                                   // I 
            2'b01: Imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};                       // S 
            2'b10: Imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}; // B 
            2'b11: Imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; // J 
        endcase 
    end 
endmodule 
 
// Branch comparator (separate from ALU). Signed compare. 
module branch_comp( 
    input  wire [31:0] DataA, DataB, 
    output wire        BrEq, BrLT 
); 
    assign BrEq = (DataA == DataB); 
    assign BrLT = ($signed(DataA) < $signed(DataB)); 
endmodule 
 
// ALU 
 
module alu( 
    input  wire [31:0] A, B, 
    input  wire [2:0]  ALUSel, 
    output reg  [31:0] result 
); 
    always @(*) begin 
        case (ALUSel) 
            3'b000: result = A + B; 
            3'b001: result = A - B; 
            3'b010: result = A & B;
 	    3'b011: result = A | B; 
            3'b100: result = A ^ B; 
            3'b101: result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0; 
            default: result = 32'd0; 
        endcase 
    end 
endmodule 
 
// Write-back mux. WBSel: 00=ALU result, 01=pc+4, 10=mem data (reserved, never selected in tests) 
module wb_mux( 
    input  wire [31:0] alu_result, pc4, mem_data, 
    input  wire [1:0]  WBSel, 
    output reg  [31:0] wb 
); 
    always @(*) begin 
        case (WBSel) 
            2'b00:   wb = alu_result; 
            2'b01:   wb = pc4; 
            2'b10:   wb = mem_data;   // reserved 
            default: wb = alu_result; 
        endcase 
    end 
endmodule 
 
// Single-cycle RV32I-style datapath. No opcode decoding: all controls are external inputs. 
// Conventions: PCSel 0=pc+4, 1=ALU result (branch/jump target = PC + Imm computed by ALU) 
//              ASel  0=DataA, 1=PC      BSel 0=DataB, 1=Imm 
module datapath_top( 
    input  wire        clk, reset, 
    input  wire        PCSel, RegWEn, ASel, BSel, 
    input  wire [2:0]  ALUSel, 
    input  wire [1:0]  ImmSel, 
    input  wire [1:0]  WBSel, 
    output wire [31:0] pc, inst, alu_result, wb, 
    output wire        BrEq, BrLT 
); 
    wire [31:0] pc4, next_pc, DataA, DataB, Imm, alu_a, alu_b; 
    wire [31:0] mem_data = 32'd0;               // reserved WB input (DMEM excluded) 
 
    wire [4:0] rs1 = inst[19:15]; 
    wire [4:0] rs2 = inst[24:20]; 
    wire [4:0] rd  = inst[11:7]; 
 
    pc_reg      u_pc   (.clk(clk), .reset(reset), .next_pc(next_pc), .pc(pc)); 
    pc_adder    u_add4 (.pc(pc), .pc4(pc4)); 
    mux2        u_pcmux(.in0(pc4), .in1(alu_result), .sel(PCSel), .out(next_pc)); 
    imem        u_imem (.pc(pc), .inst(inst)); 
    regfile     u_rf   (.clk(clk), .RegWEn(RegWEn), .AddrA(rs1), .AddrB(rs2), .AddrD(rd), .DataD(wb), .DataA(DataA), .DataB(DataB)); 
    imm_gen     u_imm  (.inst(inst), .ImmSel(ImmSel), .Imm(Imm)); 
    branch_comp u_bc   (.DataA(DataA), .DataB(DataB), .BrEq(BrEq), .BrLT(BrLT)); 
    mux2        u_amux (.in0(DataA), .in1(pc),  .sel(ASel), .out(alu_a)); 
    mux2        u_bmux (.in0(DataB), .in1(Imm), .sel(BSel), .out(alu_b)); 
    alu         u_alu  (.A(alu_a), .B(alu_b), .ALUSel(ALUSel), .result(alu_result)); 
    wb_mux      u_wb   (.alu_result(alu_result), .pc4(pc4), .mem_data(mem_data), .WBSel(WBSel), .wb(wb)); 
endmodule 

module datapath_tb; 
 
    // ---------- 1. Signals ---------- 
    reg clk = 0, reset = 1; 
    reg PCSel = 0, RegWEn = 0, ASel = 0, BSel = 0; 
    reg [2:0] ALUSel = 0; 
    reg [1:0] ImmSel = 0, WBSel = 0; 
    wire [31:0] pc, inst, alu_result, wb; 
    wire BrEq, BrLT; 
    integer errors = 0; 
 
    datapath_top dut (.clk(clk), .reset(reset), .PCSel(PCSel), .RegWEn(RegWEn), 
        .ASel(ASel), .BSel(BSel), .ALUSel(ALUSel), .ImmSel(ImmSel), .WBSel(WBSel), 
        .pc(pc), .inst(inst), .alu_result(alu_result), .wb(wb), .BrEq(BrEq), .BrLT(BrLT)); 
 
    always #5 clk = ~clk;     
 
    // 2. Names for control codes 
    localparam ADD = 3'b000, SUB = 3'b001, AND_ = 3'b010, OR_ = 3'b011, XOR_ = 3'b100, SLT = 3'b101; 
    localparam I_ = 2'b00, B_ = 2'b10, J_ = 2'b11;       // ImmSel 
    localparam WB_ALU = 2'b00, WB_PC4 = 2'b01;           // WBSel 
 
    //  3. Instruction encoders (just to build the program) ---------- 
    function [31:0] enc_i(input [11:0] imm, input [4:0] rs1, input [2:0] f3, input [4:0] rd); 
        enc_i = {imm, rs1, f3, rd, 7'h13}; 
    endfunction 
    function [31:0] enc_r(input [6:0] f7, input [4:0] rs2, input [4:0] rs1, input [2:0] f3, input [4:0] rd); 
        enc_r = {f7, rs2, rs1, f3, rd, 7'h33}; 
    endfunction 
    function [31:0] enc_b(input [12:0] o, input [4:0] rs2, input [4:0] rs1, input [2:0] f3); 
        enc_b = {o[12], o[10:5], rs2, rs1, f3, o[4:1], o[11], 7'h63}; 
    endfunction 
    function [31:0] enc_j(input [20:0] o, input [4:0] rd); 
        enc_j = {o[20], o[10:1], o[11], o[19:12], rd, 7'h6F}; 
    endfunction 
 
    // ---------- 4. Helper tasks ---------- 
    task check(input [255:0] name, input [31:0] got, input [31:0] expd); 
        begin
	 if (got === expd) $display("PASS  %0s = %h", name, got); 
            else begin 
                $display("FAIL  %0s : got %h, expected %h", name, got, expd); 
                errors = errors + 1; 
            end 
        end 
    endtask 
 
    // set all control signals at once 
    task ctl(input pcs, input rw, input as, input bs, input [2:0] al, input [1:0] im, input [1:0] wbs); 
        begin PCSel=pcs; RegWEn=rw; ASel=as; BSel=bs; ALUSel=al; ImmSel=im; WBSel=wbs; end 
    endtask 
 
    // wait for one clock edge (+1 ns so outputs have settled) 
    task step; begin @(posedge clk); #1; end endtask 
 
    // I-type: reg + immediate -> reg      (ASel=0, BSel=1) 
    task do_itype(input [2:0] al); begin ctl(0,1,0,1,al,I_,WB_ALU); step; end endtask 
    // R-type: reg op reg -> reg           (ASel=0, BSel=0) 
    task do_rtype(input [2:0] al); begin ctl(0,1,0,0,al,I_,WB_ALU); step; end endtask 
    // Branch: target = PC + Imm (ASel=1, BSel=1)
    // kind 0=BEQ 1=BNE 2=BLT 3=BGE  
    task do_branch(input [1:0] kind); 
        begin 
            ctl(0,0,1,1,ADD,B_,WB_ALU); #1; 
            case (kind) 
                0: PCSel = BrEq; 
                1: PCSel = ~BrEq; 
                2: PCSel = BrLT; 
                3: PCSel = ~BrLT; 
            endcase 
            step; 
        end 
    endtask 

  // 5. The test 
    initial begin 
        // Loading the program into instruction memory ----- 
        dut.u_imem.mem[0]  = enc_i(12'd7,   5'd0,  3'b000, 5'd5);       // 0x00 ADDI x5,x0,7 
        dut.u_imem.mem[1]  = enc_i(12'd5,   5'd0,  3'b000, 5'd6);       // 0x04 ADDI x6,x0,5 
        dut.u_imem.mem[2]  = enc_r(7'h00, 5'd6, 5'd5, 3'b000, 5'd7);    // 0x08 ADD  x7,x5,x6 
        dut.u_imem.mem[3]  = enc_r(7'h20, 5'd6, 5'd5, 3'b000, 5'd8);    // 0x0C SUB  x8,x5,x6 
        dut.u_imem.mem[4]  = enc_b(13'd8, 5'd0, 5'd7, 3'b000);          // 0x10 BEQ  x7,x0,+8  (not taken) 
        dut.u_imem.mem[5]  = enc_r(7'h00, 5'd8, 5'd7, 3'b000, 5'd9);    // 0x14 ADD  x9,x7,x8 
        dut.u_imem.mem[6]  = enc_i(12'hFFF, 5'd0,  3'b000, 5'd12);      // 0x18 ADDI x12,x0,-1 
        dut.u_imem.mem[7]  = enc_i(12'd1,   5'd0,  3'b000, 5'd11);      // 0x1C ADDI x11,x0,1 
        dut.u_imem.mem[8]  = enc_r(7'h00, 5'd5, 5'd12, 3'b010, 5'd13);  // 0x20 SLT  x13,x12,x5 
        dut.u_imem.mem[9]  = enc_r(7'h00, 5'd6, 5'd5, 3'b111, 5'd14);   // 0x24 AND  x14,x5,x6 
	dut.u_imem.mem[10] = enc_r(7'h00, 5'd6, 5'd5, 3'b110, 5'd15);   // 0x28 OR   x15,x5,x6 
        dut.u_imem.mem[11] = enc_r(7'h00, 5'd6, 5'd5, 3'b100, 5'd16);   // 0x2C XOR  x16,x5,x6 
        dut.u_imem.mem[12] = enc_i(12'd5,   5'd0,  3'b000, 5'd0);       // 0x30 ADDI x0,x0,5   (write to x0) 
        dut.u_imem.mem[13] = enc_r(7'h00, 5'd5, 5'd0, 3'b000, 5'd17);   // 0x34 ADD  x17,x0,x5 (x0 reads 0) 
        dut.u_imem.mem[14] = enc_b(13'd8, 5'd5, 5'd5, 3'b000);          // 0x38 BEQ  x5,x5,+8  (taken) 
        dut.u_imem.mem[15] = enc_i(12'd99,  5'd0,  3'b000, 5'd10);      // 0x3C ADDI x10,x0,99 (skipped) 
        dut.u_imem.mem[16] = enc_j(21'd8, 5'd1);                        // 0x40 JAL  x1,+8 
        dut.u_imem.mem[17] = enc_i(12'd1,   5'd0,  3'b000, 5'd18);      // 0x44 ADDI x18,x0,1  (skipped) 
        dut.u_imem.mem[18] = enc_i(12'd42,  5'd0,  3'b000, 5'd19);      // 0x48 ADDI x19,x0,42 
        dut.u_imem.mem[19] = enc_b(13'd8, 5'd11, 5'd12, 3'b100);        // 0x4C BLT  x12,x11,+8 (-1<1 taken) 
        dut.u_imem.mem[20] = enc_i(12'd1,   5'd0,  3'b000, 5'd25);      // 0x50 ADDI x25,x0,1  (skipped) 
        dut.u_imem.mem[21] = enc_b(-13'sd8, 5'd5, 5'd5, 3'b001);        // 0x54 BNE  x5,x5,-8   (not taken) 
        dut.u_imem.mem[22] = enc_i(-12'sd3, 5'd0,  3'b000, 5'd20);      // 0x58 ADDI x20,x0,-3 
        dut.u_imem.mem[23] = enc_i(12'd99,  5'd0,  3'b000, 5'd5);       // 0x5C ADDI x5,x0,99  (RegWEn=0) 
	
	$display("TEST 1: Reset PC "); 
        step; check("pc while reset held", pc, 32'h0); 
        @(negedge clk); reset = 0;                      // release between clock edges 
        ctl(0,0,0,0,ADD,I_,WB_ALU); #1; 
        check("pc before first edge (no change)", pc, 32'h0); 
 
        $display("---- TEST 2: Sequential PC (PCSel=0)"); 
        step; check("pc after edge 1", pc, 32'h4); 
        step; check("pc after edge 2", pc, 32'h8); 
        step; check("pc after edge 3", pc, 32'hC); 
        reset = 1; #1; check("pc after reset again", pc, 32'h0); 
        @(negedge clk); reset = 0; 
 
        $display(" TEST 3: PC target mux"); 
        ctl(0,0,0,1,ADD,I_,WB_ALU); #1;                // alu_result = x0 + 7 = 7, pc4 = 4 
        check("next_pc, PCSel=0 -> pc4", dut.next_pc, 32'h4); 
        PCSel = 1; #1; 
        check("next_pc, PCSel=1 -> ALU target", dut.next_pc, 32'h7); 
        PCSel = 0; 
 
        $display(" TEST 4: Run the program"); 
        do_itype(ADD);  check("x5  = 7",  dut.u_rf.regs[5], 7); 
        do_itype(ADD);  check("x6  = 5",  dut.u_rf.regs[6], 5); 
        do_rtype(ADD);  check("x7  = 12", dut.u_rf.regs[7], 12); 
        do_rtype(SUB);  check("x8  = 2",  dut.u_rf.regs[8], 2); 
        do_branch(0);   check("BEQ not taken, pc", pc, 32'h14); 
        do_rtype(ADD);  check("x9  = 14", dut.u_rf.regs[9], 14); 
 
        $display("TEST 5: ALU logic and signed compare "); 
        do_itype(ADD);  check("x12 = -1", dut.u_rf.regs[12], 32'hFFFF_FFFF); 
        do_itype(ADD);  check("x11 = 1",  dut.u_rf.regs[11], 1); 
        do_rtype(SLT);  check("x13 = SLT(-1,7)", dut.u_rf.regs[13], 1); 
        do_rtype(AND_); check("x14 = 7 AND 5", dut.u_rf.regs[14], 5); 
	 do_rtype(OR_);  check("x15 = 7 OR 5",  dut.u_rf.regs[15], 7); 
        do_rtype(XOR_); check("x16 = 7 XOR 5", dut.u_rf.regs[16], 2); 
 
        $display("TEST 6: x0 protection "); 
        do_itype(ADD);  check("x0 still 0 after write", dut.u_rf.regs[0], 0); 
        do_rtype(ADD);  check("x17 = x0 + x5 = 7", dut.u_rf.regs[17], 7); 
 
        $display("TEST 7: Branch taken, JAL"); 
        do_branch(0);   check("BEQ taken, pc", pc, 32'h40); 
        check("x10 skipped", dut.u_rf.regs[10], 0); 
        ctl(1,1,1,1,ADD,J_,WB_PC4); #1; 
        check("WB=PC4 : wb = pc+4", wb, 32'h44); 
        step; 
        check("x1 (link) = 0x44", dut.u_rf.regs[1], 32'h44); 
        check("JAL target, pc", pc, 32'h48); 
        do_itype(ADD);  check("x19 = 42", dut.u_rf.regs[19], 42); 
        check("x18 skipped", dut.u_rf.regs[18], 0); 
 
        $display("TEST 8: Signed compare flags (-1 vs +1)"); 
        ctl(0,0,1,1,ADD,B_,WB_ALU); #1; 
        check("BrLT (-1 < 1)", BrLT, 1); 
        check("BrEq (-1 == 1)", BrEq, 0); 
        do_branch(2);   check("BLT taken, pc", pc, 32'h54); 
        check("x25 skipped", dut.u_rf.regs[25], 0); 
 
        $display(" TEST 9: Immediates (negative I and backward B)"); 
        ctl(0,0,1,1,ADD,B_,WB_ALU); #1; 
        check("B-type imm = -8", dut.Imm, 32'hFFFF_FFF8); 
        do_branch(1);   check("BNE not taken, pc", pc, 32'h58); 
        ctl(0,1,0,1,ADD,I_,WB_ALU); #1; 
        check("I-type imm = -3", dut.Imm, 32'hFFFF_FFFD); 
        step;           check("x20 = -3", dut.u_rf.regs[20], 32'hFFFF_FFFD); 
 
        $display("TEST 10: Write disabled (RegWEn=0)"); 
        ctl(0,0,0,1,ADD,I_,WB_ALU); #1; 
        check("wb is 99 (would-be write)", wb, 99); 
        step;           check("x5 still 7", dut.u_rf.regs[5], 7); 
 
        // Summary 
        $display("========================================="); 
        if (errors == 0) $display("ALL TESTS PASSED"); 
        else             $display("%0d TEST(S) FAILED", errors);
 
        $finish; 
    end 
endmodule



