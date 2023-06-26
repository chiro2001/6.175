1. Hardware-wise, unsigned addition is the same as signed addition when using two's complement encoding. Using evidence from the test bench, is unsigned multiplication the same as signed multiplication?

   从硬件角度来看，使用补码编码时，无符号加法与有符号加法相同。使用测试台中的证据，无符号乘法与有符号乘法相同吗？

   不同。

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

   出现的编译错误：

   ```
   Error: "TestBench.bsv", line 10, column 17: (T0035)
     Bit vector of unknown size introduced near this location.
     Please remove unnecessary extensions, truncations and concatenations and/or
     provide more type information to resolve this ambiguity.
   ```

   原因分析：

   ```
   function Bit#(TAdd#(n, n)) multiply_(un)signed(Bit#(n) a, Bit#(n) b);
   ```

   两个相乘函数都使用泛型方法，将位宽定义为类型变量 `n`，如果这样写的话无法确定 `n` 的实际数值。

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

   当 `multiply_unsigned` 中的类型变量被 `test_function` 限定为 `n == 8`，则也足以推断出使用的另一个 `ref_function` 的类型变量 `n`，所以在这里代码中 `ref_function` 的 `n == 8` 限定是多余的。

3. Is your implementation of `multiply_by_adding` a signed multiplier or an unsigned multiplier? (Note: if it does not match either `multiply_signed` or `multiply_unsigned`, it is wrong).

   ```
   Bit#(TAdd#(n, n)) product = '0;
       for (Integer i = 0; i < valueOf(n); i = i + 1) begin
           // not best solution
           product = product + (zeroExtend(unpack(a[i]) ? b : '0) << i);
       end
       return product;
   ```

   是无符号实现。

4. 