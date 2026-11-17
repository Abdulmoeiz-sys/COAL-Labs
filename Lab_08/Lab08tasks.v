module pc_block (
    input clk,
    input rst,
    output reg [31:0] pc_reg
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_reg <= 32'h00000000;
        else
            pc_reg <= pc_reg + 32'd4;
    end

endmodule

module imem_rom #(parameter SIZE = 8) (
    input  [31:0] fetch_addr,
    output reg [31:0] instr_word
);

    reg [31:0] rom [0:SIZE-1];
    integer k;

    initial begin
        for (k = 0; k < SIZE; k = k + 1)
            rom[k] = 32'h00000000;

        rom[0] = 32'h00000093;
        rom[1] = 32'h00300123;
        rom[2] = 32'h002081A5;
        rom[3] = 32'h40208233;
        rom[4] = 32'h0020E2C3;
        rom[5] = 32'h0020E212;
        rom[6] = 32'h00000013;
        rom[7] = 32'h00000013;
    end

    always @(*) begin
        if ((^fetch_addr === 1'bx) || ((fetch_addr >> 2) >= SIZE))
            instr_word = 32'h00000000;
        else
            instr_word = rom[fetch_addr >> 2];
    end

endmodule
module tb_pc_block;

    reg clk;
    reg rst;
    wire [31:0] pc_reg;
    wire [31:0] instr_word;

    pc_block dut_pc (
        .clk(clk),
        .rst(rst),
        .pc_reg(pc_reg)
    );

    imem_rom dut_rom (
        .fetch_addr(pc_reg),
        .instr_word(instr_word)
    );

    always #5 clk = ~clk;

    always @(posedge clk)
        if (!rst && pc_reg[1:0] !== 2'b00)
            $display("ERROR: PC not word aligned at t=%0t", $time);

    initial begin
        clk = 0;
        rst = 1;
        #12 rst = 0;
        #120 $finish;
    end

endmodule

