module decoder( a, b,c,en,o0,o1,o2,o3,o4,o5,o6,o7);
input en,a,b,c;
output o0,o1,o2,o3,o4,o5,o6,o7;
wire na,nb, nc;

assign na =~a;
assign nb =~b;
assign nc =~c;

not(nc,c);

assign o0 = na& nb& nc &en;
assign o1 = na& nb& c &en;
assign o2 = na& b& nc &en;
assign o3 = na& b& c &en;
assign o4 = a& nb& nc &en;
assign o5 = a& nb& c &en;
assign o6 = a& b& nc &en;
assign o7 = a& b& c &en;
 
endmodule

module Decode_TB;
reg en,a,b,c;
wire o0,o1,o2,o3,o4,o5,o6,o7;

decoder d1(a,b,c,en,o0,o1,o2,o3,o4,o5,o6,o7);

initial
begin
en = 0; a = 0; b = 0; c = 0;
#10
en = 1; a = 0; b = 0; c = 0;
#10
en = 1; a = 0; b = 0; c = 1;
#10
en = 1; a = 0; b = 1; c = 0;
#10
en = 1; a = 0; b = 1; c = 1;
#10
en = 1; a = 1; b = 0; c = 0;
#10
en = 1; a = 1; b = 0; c = 1;
#10
en = 1; a = 1; b = 1; c = 0;
#10
en = 1; a = 1; b = 1; c = 1;
end
endmodule











