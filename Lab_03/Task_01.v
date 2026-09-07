module addsub (a, b, sub, result);
    input  [3:0] a, b;
    input        sub;              
    output reg [4:0] result;     
    always @(*)
    begin
        if (sub == 0)
            result <= a + b;
        else
            result <= a - b; 
    end
endmodule

module addsub_testbench;
    reg  [3:0] a, b;
    reg        sub;
    wire [4:0] result;

    addsub uut (.a(a), .b(b), .sub(sub), .result(result));

    initial
    begin
        a = 4'd5; b = 4'd3; sub = 0; #20;  
        a = 4'd5; b = 4'd3; sub = 1; #20;   
    end
endmodule