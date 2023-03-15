import TestBenchTemplates::*;
import Multipliers::*;

// Example testbenches
(* synthesize *)
module mkTbDumb();
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
    Empty tb <- mkTbMulFunction(test_function, multiply_unsigned, True);
    return tb;
endmodule

(* synthesize *)
module mkTbFoldedMultiplier();
    Multiplier#(8) dut <- mkFoldedMultiplier();
    Empty tb <- mkTbMulModule(dut, multiply_signed, True);
    return tb;
endmodule

// Exercise 1
(* synthesize *)
module mkTbSignedVsUnsigned();
endmodule

// Exercise 3
(* synthesize *)
module mkTbEx3();
endmodule

// Exercise 5
(* synthesize *)
module mkTbEx5();
endmodule

// Exercise 7
(* synthesize *)
module mkTbEx7a();
endmodule

// Exercise 7
(* synthesize *)
module mkTbEx7b();
endmodule

// Exercise 9
(* synthesize *)
module mkTbEx9a();
endmodule

// Exercise 9
(* synthesize *)
module mkTbEx9b();
endmodule

