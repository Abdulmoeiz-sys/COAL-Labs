module gates(a,b,c);
input a, b;
output c;
nor(c,a,b);
endmodule


module testbench();
reg x,y;
wire z;
gates uut(x,y,z);

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
