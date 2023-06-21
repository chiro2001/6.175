function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a&b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a|b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~a;
endfunction

/*
Truth table:
  res  |  sel  |  a  |  b
   0   |   0   |  0  |  0
   0   |   1   |  0  |  0
   1   |   0   |  1  |  0
   0   |   1   |  1  |  0
   0   |   0   |  0  |  1
   1   |   1   |  0  |  1
   1   |   0   |  1  |  1
   1   |   1   |  1  |  1

   sel | 0 | 1
   ------------
ab 00  | 0 | 0
   01  | 0 | 1
   10  | 1 | 0
   11  | 1 | 1

res = (~sel & a & ~b) | (sel & ~a & b) | (~sel & a & b) | (sel & a & b)
    = (~sel & a) | (sel & b)
*/

// Exercise 1
function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    return or1(and1(not1(sel), a), and1(sel, b));
endfunction

// Exercise 2
function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
    Bit#(5) res;
    for (Integer i = 0; i < 5; i = i + 1) begin
        res[i] = multiplexer1(sel, a[i], b[i]);
    end
    return res;
endfunction

// Exercise 3
function Bit#(n) multiplexer_n(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
    Bit#(n) res;
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        res[i] = multiplexer1(sel, a[i], b[i]);
    end
    return res;
endfunction
