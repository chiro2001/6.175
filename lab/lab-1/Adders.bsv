import Multiplexer::*;

function Bit#(1) fa_sum(Bit#(1) a, Bit#(1) b, Bit#(1) c);
    return a^b^c;
endfunction

function Bit#(1) fa_carry(Bit#(1) a, Bit#(1) b, Bit#(1) c);
    return (a&b)|(a&c)|(b&c);
endfunction

function Bit#(TAdd#(n,1)) addN(Bit#(n) a, Bit#(n) b, Bit#(1) c0);
    Bit#(n) s;
    Bit#(1) c=c0;
    for(Integer i = 0; i < valueOf(n); i=i+1) begin
        s[i] = fa_sum(a[i], b[i], c);
        c = fa_carry(a[i], b[i], c);
    end
    return {c,s};
endfunction

// Exercise 4
function Bit#(5) add4(Bit#(4) a, Bit#(4) b, Bit#(1) c0);

endfunction

interface Adder8;
    method ActionValue#(Bit#(9)) sum(Bit#(8) a,Bit#(8) b, Bit#(1) c_in);
endinterface

module mkRCAdder(Adder8);
    method ActionValue#(Bit#(9)) sum(Bit#(8) a,Bit#(8) b,Bit#(1) c_in);
        let low = add4(a[3:0], b[3:0], c_in);
        let high = add4(a[7:4], b[7:4], low[4]);
        return {high, low[3:0]};
    endmethod
endmodule

// Exercise 5
module mkCSAdder(Adder8);
    method ActionValue#(Bit#(9)) sum(Bit#(8) a,Bit#(8) b,Bit#(1) c_in);

    endmethod
endmodule