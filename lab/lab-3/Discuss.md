1. Hardware-wise, unsigned addition is the same as signed addition when using two's complement encoding. Using evidence from the test bench, is unsigned multiplication the same as signed multiplication?

   从硬件角度来看，使用补码编码时，无符号加法与有符号加法相同。使用测试台中的证据，无符号乘法与有符号乘法相同吗？

2. In `mkTBDumb` excluding the line

   ```
   function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
   ```

   and modifying the rest of the module to have

   ```
   (* synthesize *)
   module mkTbDumb();
       Empty tb <- mkTbMulFunction(multiply_unsigned, multiply_unsigned, True);
       return tb;
   endmodule
   ```

   will result in a compilation error. What is that error? How does the original code fix the compilation error? You could also fix the error by having two function definitions as shown below.

   ```
   (* synthesize *)
   module mkTbDumb();
       function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
       function Bit#(16) ref_function( Bit#(8) a, Bit#(8) b ) = multiply_unsigned( a, b );
       Empty tb <- mkTbMulFunction(test_function, ref_function, True);
       return tb;
   endmodule
   ```

   Why is two function definitions not necessary? (i.e. why can the second operand to `mkTbMulFunction` have variables in its type?) *Hint:* Look at the types of the operands of `mkTbMulFunction` in `TestBenchTemplates.bsv`.