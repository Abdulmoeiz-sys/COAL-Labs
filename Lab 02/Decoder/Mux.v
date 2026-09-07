module Mux( I0, I1, I2, I3, I4, I5, I6, I7, S2, S1, S0,Y);

input D0,D1,D2,D3,D4,D5,D6,D7,S2,S1,S0;
output Y;

wire ns2,ns1,ns0;
wire i0,i1,i2,i3,i4,i5,i6,i7;

not(ns2,S2);
not(ns1,S1);
not(ns0,S0);
and(i0,ns2,ns1,ns0,I0);
and(i1,ns2,ns1,S0,I1);
and(i2,ns2,S1,ns0,I2);
and(i3,ns2,S1,S0,I3);
and(i4,S2,ns1,ns0,I4);
and(i5,S2,ns1,S0,I5);
and(i6,S2,S1,ns0,I6);
and(i7,S2,S1,S0,I7);

or(Y,i0,i1,i2,i3,i4,i5,i6,i7);

endmodule

module mux_tb;

reg d0,d1,d2,d3,d4,d5,d6,d7;
reg s0,s1,s2;
wire Y;

Mux testmux(d0,d1,d2,d3,d4,d5,d6,d7,s2,s1,s0,Y);
initial
begin

d0=0; d1=1; d2=0; d3=1;
d4=0; d5=1; d6=0; d7=1;

s2=0; s1=0; s0=0;
#50;
s2=0; s1=0; s0=1;
#50;
s2=0; s1=1; s0=0;
#50;
s2=0; s1=1; s0=1;
#50;
s2=1; s1=0; s0=0;
#50;
s2=1; s1=0; s0=1;
#50;
s2=1; s1=1; s0=0;
#50;
s2=1; s1=1; s0=1;
#50;  

end
endmodule
