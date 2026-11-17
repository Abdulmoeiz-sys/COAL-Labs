module decoder_2_to4(output reg [3:0] dec_out, input [1:0] wr, input write_enable);
    always @(*) begin
        if (write_enable) begin
            case (wr)
                2'b00: dec_out = 4'b0001;   //r1
                2'b01: dec_out = 4'b0010;   //r2
                2'b10: dec_out = 4'b0100;   //r3
                2'b11: dec_out = 4'b1000;   //r4
                default: dec_out = 4'b0000;
            endcase
        end else begin
            dec_out = 4'b0000;              // no write
        end
    end
endmodule

module mux4_1(output reg [3:0] out, input [3:0] in0, in1, in2, in3, input [1:0] sel);
    always @(*) begin
        if (sel == 2'b00)
            out = in0;
        else if (sel == 2'b01)
            out = in1;
        else if (sel == 2'b10)
            out = in2;
        else if (sel == 2'b11)
            out = in3;
        else
            out = 4'b0000;   // optional, for safety
    end
endmodule

module register_4bit(output reg [3:0] q, input [3:0] d, input load, input clk);
    always @(posedge clk) begin
        if (load)
            q <= d;
    end
endmodule

module register_file_4x4(data_out1, data_out2, data_in, wr, write_enable, rd1, rd2, clk);
    // output ports
    output [3:0] data_out1, data_out2;

    // input ports
    input [3:0] data_in;
    input [1:0] wr;
    input write_enable;
    input [1:0] rd1, rd2;
    input clk;

    // Internal wires
    wire [3:0] dec_out;
    wire [3:0] q0, q1, q2, q3;

    // Instantiate decoder
    decoder_2_to4 decoder(dec_out, wr, write_enable);

    // Instantiate four 4-bit registers
    register_4bit reg0(q0, data_in, dec_out[0], clk);
    register_4bit reg1(q1, data_in, dec_out[1], clk);
    register_4bit reg2(q2, data_in, dec_out[2], clk);
    register_4bit reg3(q3, data_in, dec_out[3], clk);

    // Instantiate two 4-to-1 multiplexers for reading
    mux4_1 mux1(data_out1, q0, q1, q2, q3, rd1);
    mux4_1 mux2(data_out2, q0, q1, q2, q3, rd2);
endmodule

module tb_register_file_4x4;
    // inputs to the design ? reg
    reg  [3:0] data_in;
    reg  [1:0] wr, rd1, rd2;
    reg        write_enable, clk;
    // outputs 
    wire [3:0] data_out1, data_out2;

    // connect your register file
    register_file_4x4 uut(data_out1, data_out2, data_in, wr, write_enable, rd1, rd2, clk);

    // clock: flips every 5 units ? period 10, rising edges at t = 5, 15, 25, 35...
    always #5 clk = ~clk;

    initial begin
        // start everything at 0
        clk = 0; write_enable = 0; wr = 0; data_in = 0; rd1 = 0; rd2 = 0;

        #2  write_enable = 1; wr = 2'b01; data_in = 4'd6;   // t=2:  6 in R1 
        #10 wr = 2'b10; data_in = 4'd3;                     // t=12: 3 in R2 
        #10 wr = 2'b11; data_in = 4'd13;                    // t=22: 13 in R3 
        #10 write_enable = 0; rd1 = 2'b01; rd2 = 2'b10;     // t=32: read R1 and R2
        
    end
endmodule
