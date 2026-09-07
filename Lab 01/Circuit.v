module circuit(a,b,g);
input a,b;
output g;
wire c,d,e,f;

assign c = ~a;
assign d = ~b;

assign e = c&b;
assign f = a&d;

assign g = e|f;
endmodule

module Circuit_TB();
reg x,y;
wire z;
circuit uut(x,y,z);

initial
begin
x = 0; y = 0;
#50
x = 0; y = 1;
#50
x = 1; y = 0;
#50
x = 1; y = 1;
end
endmodule
