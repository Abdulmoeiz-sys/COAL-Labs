module gates(a,b,c,d,e,f,g,h);
input a, b, c, d;
output e, f, g, h;
assign e = ~a;
assign f = ~b;
assign g = ~c;
assign h = ~d;
endmodule


module testbench();
reg a1,b1,c1,d1;
wire e1,f1,g1,h1;
gates uut(a1,b1,c1,d1,e1,f1,g1,h1);
initial
begin
a1 = 1; b1 = 1; c1 = 0; d1 = 0;

end
endmodule

