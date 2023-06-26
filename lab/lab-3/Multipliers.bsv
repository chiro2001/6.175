// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n, n)) multiply_unsigned(Bit#(n) a, Bit#(n) b);
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n, n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
    return pack(product_uint);
endfunction

function Bit#(TAdd#(n, n)) multiply_signed(Bit#(n) a, Bit#(n) b);
    Int#(n) a_int = unpack(a);
    Int#(n) b_int = unpack(b);
    Int#(TAdd#(n, n)) product_int = signExtend(a_int) * signExtend(b_int);
    return pack(product_int);
endfunction

// Exercise 2
// Multiplication by repeated addition
function Bit#(TAdd#(n, n)) multiply_by_adding(Bit#(n) a, Bit#(n) b);
    // silly version
    // Bit#(TAdd#(n, n)) out = '0;
    // Bit#(TAdd#(n, n)) extended_b = zeroExtend(b);
    // for (Bit#(n) i = 0; i < a; i = i + 1) begin
    //     out = out + extended_b;
    // end
    // return out;

    Bit#(TAdd#(n, n)) product = '0;
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        // not best solution
        product = product + (zeroExtend(unpack(a[i]) ? b : '0) << i);
    end
    return product;
endfunction

// Multiplier Interface
interface Multiplier#(numeric type n);
    method Bool start_ready();
    method Action start(Bit#(n) a, Bit#(n) b);
    method Bool result_ready();
    method ActionValue#(Bit#(TAdd#(n, n))) result();
endinterface


// Exercise 4
// Folded multiplier by repeated addition
module mkFoldedMultiplier(Multiplier#(n));
    Reg#(Bit#(TAdd#(n, n))) product <- mkReg('0);
    Reg#(Bit#(n)) a <- mkRegU;
    Reg#(Bit#(n)) b <- mkRegU;
    Reg#(Bit#(TAdd#(1, TLog#(n)))) i <- mkReg('0);
    Reg#(Bool) started <- mkReg(False);
    rule acc if (started && i < fromInteger(valueOf(n)));
        // $display("Accumulating i=%d", i);
        product <= (i == 0 ? '0 : product) + (zeroExtend(unpack(a[0]) ? b : '0) << i);
        i <= i + 1;
        a <= a >> 1;
    endrule
    let result_ready_ = i == fromInteger(valueOf(n));
    method start_ready = !started;
    method result_ready = result_ready_;
    method Action start(Bit#(n) a_, Bit#(n) b_) if (!started);
        // $display("Starting multiplication");
        a <= a_;
        b <= b_;
        started <= True;
    endmethod
    method ActionValue#(Bit#(TAdd#(n, n))) result() if (result_ready_);
        // $display("Returning result %d", product);
        started <= False;
        i <= '0;
        return product;
    endmethod
endmodule



function Bit#(n) arth_shift(Bit#(n) a, Integer n, Bool right_shift);
    Int#(n) a_int = unpack(a);
    Bit#(n) out = 0;
    if (right_shift) begin
        out = pack(a_int >> n);
    end
    else begin //left shift
        out = pack(a_int << n); end
    return out;
endfunction



// Exercise 6
// Booth Multiplier
module mkBoothMultiplier(Multiplier#(n));
endmodule



// Exercise 8
// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4(Multiplier#(n));
endmodule
