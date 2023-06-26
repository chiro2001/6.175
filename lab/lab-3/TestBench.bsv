import LFSR::*;
import Vector::*;

import TestBenchTemplates::*;
import Multipliers::*;

// Example testbenches
(* synthesize *)
module mkTbDumb();
    // Empty tb <- mkTbMulFunction(multiply_unsigned, multiply_unsigned, True);
    // return tb;
    // function Bit#(16) test_function(Bit#(8) a, Bit#(8) b) = multiply_unsigned(a, b);
    // function Bit#(16) ref_function(Bit#(8) a, Bit#(8) b) = multiply_unsigned(a, b);
    // Empty tb <- mkTbMulFunction(test_function, ref_function, True);
    // return tb;

    // Chiro: can we use lambda functions?
    function Bit#(16) test_function(Bit#(8) a, Bit#(8) b) = multiply_unsigned(a, b);
    Empty tb <- mkTbMulFunction(test_function, multiply_unsigned, True);
    return tb;
endmodule

(* synthesize *)
module mkTbFoldedMultiplier();
    Multiplier#(8) dut <- mkFoldedMultiplier();
    // originally: singned
    Empty tb <- mkTbMulModule(dut, multiply_unsigned, True);
    return tb;
endmodule

// Exercise 1
(* synthesize *)
module mkTbMySignedVsUnsigned();
    Reg#(int) cnt <- mkReg(0);
    Reg#(int) cnt_err <- mkReg(0);
    let max_cnt = 512;
    let max_cnt_err = 32;

    // not real random
    Vector#(2, LFSR#(Bit#(8))) lfsr;

    for (Integer i = 0; i < 2; i = i + 1) begin
        lfsr[i] <- mkRCounter(fromInteger('h55 + i * 'hc));
    end

    rule counter;
        let cnt_next = cnt + 1;
        cnt <= cnt_next;
        if (cnt_next == max_cnt) begin
            $finish;
        end
    endrule

    rule err_exit if (cnt_err == max_cnt_err);
        $display("%d differences detected, total %d tries", cnt_err, cnt);
        $finish;
    endrule

    rule feed_and_check;
        let randomVal1 = lfsr[0].value();
        let randomVal2 = lfsr[1].value();
        let unsigned_result = multiply_unsigned(randomVal1, randomVal2);
        let signed_result = multiply_signed(randomVal1, randomVal2);
        if (signed_result != unsigned_result) begin
            $display("Notice: %x * %x = %x (unsigned) != %x (signed)", randomVal1, randomVal2, unsigned_result, signed_result);
            cnt_err <= cnt_err + 1;
        end
        else begin
            $display("OK: %x * %x = %x (unsigned) == %x (signed)", randomVal1, randomVal2, unsigned_result, signed_result);
        end
        for (Integer i = 0; i < 2; i = i + 1) begin
            lfsr[i].next();
        end
    endrule
endmodule

(* synthesize *)
module mkTbSignedVsUnsigned();
    function Bit#(16) test_function(Bit#(8) a, Bit#(8) b) = multiply_unsigned(a, b);
    Empty tb <- mkTbMulFunction(test_function, multiply_signed, True);
    return tb;
endmodule

// Exercise 3
(* synthesize *)
module mkTbEx3();
    function Bit#(16) test_function(Bit#(8) a, Bit#(8) b) = multiply_by_adding(a, b);
    Empty tb <- mkTbMulFunction(test_function, multiply_unsigned, True);
    return tb;
endmodule

// Exercise 5
(* synthesize *)
module mkTbEx5();
    Multiplier#(8) dut <- mkFoldedMultiplier();
    Empty tb <- mkTbMulModule(dut, multiply_by_adding, True);
    return tb;
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

