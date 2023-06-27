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
    Reg#(Bit#(TAdd#(n, n))) product <- mkReg('0);
    Reg#(Bit#(n)) a <- mkReg('0);
    // an extra bit is needed for pairing
    Reg#(Bit#(TAdd#(1, n))) b <- mkReg('0);
    Reg#(Bit#(TAdd#(1, TLog#(n)))) i <- mkReg('0);
    Reg#(Bool) started <- mkReg(False);

    Int#(TAdd#(n, n)) pos_a = unpack(signExtend(a));
    Int#(TAdd#(n, n)) neg_a = -unpack(signExtend(a));

    let b_part = b[1:0];
    function Bit#(TAdd#(n, n)) getAddValue();
        Bit#(TAdd#(n, n)) add_value = '0;
        case (b_part)
            2'b01: add_value = pack(pos_a) << i;
            2'b10: add_value = pack(neg_a) << i;
            default: add_value = '0;
        endcase
        return add_value;
    endfunction

    rule calculate if (started && i < fromInteger(valueOf(n)));
        Bit#(TAdd#(n, n)) add_value = getAddValue();
        // $display("Calculating i=%d, add_value=%d", i, add_value);
        product <= (i == 0 ? '0 : product) + add_value;
        i <= i + 1;
        // b <= b >> 1;
        b <= arth_shift(b, 1, True);
    endrule

    let result_ready_ = i == fromInteger(valueOf(n));
    method start_ready = !started;
    method result_ready = result_ready_;
    // Chiro: function args name can be different from the interface
    method Action start(Bit#(n) a_, Bit#(n) b_) if (!started);
        // $display("Starting multiplication");
        a <= a_;
        b <= {b_, '0};
        i <= '0;
        product <= '0;
        started <= True;
    endmethod
    method ActionValue#(Bit#(TAdd#(n, n))) result() if (result_ready_);
        // $display("Returning result %d", product);
        started <= False;
        i <= '0;
        return product;
    endmethod
endmodule



// Exercise 8
// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4(Multiplier#(n));
    Reg#(Bit#(TAdd#(n, n))) product <- mkReg('0);
    Reg#(Bit#(n)) a <- mkReg('0);
    // an extra bit is needed for pairing
    Reg#(Bit#(TAdd#(3, n))) b <- mkReg('0);
    Reg#(Bit#(TAdd#(1, TLog#(n)))) i <- mkReg('0);
    Reg#(Bool) started <- mkReg(False);

    Int#(TAdd#(n, n)) pos_a = unpack(signExtend(a));
    Int#(TAdd#(n, n)) neg_a = -unpack(signExtend(a));

    let b_part = b[2:0];
    function Bit#(TAdd#(n, n)) getAddValue();
        Bit#(TAdd#(n, n)) add_value = 
            (case (b_part)
                3'b001: return pack(pos_a);
                3'b010: return pack(pos_a);
                3'b011: return pack(pos_a) << 1;
                3'b100: return pack(neg_a) << 1;
                3'b101: return pack(neg_a);
                3'b110: return pack(neg_a);
                default: return '0;
            endcase) << (i << 1);
        return add_value;
    endfunction

    rule calculate if (started && i < fromInteger(valueOf(n) / 2));
        Bit#(TAdd#(n, n)) add_value = getAddValue();
        // $display("Calculating i=%d, add_value=%d", i, add_value);
        product <= (i == 0 ? '0 : product) + add_value;
        i <= i + 1;
        b <= arth_shift(b, 2, True);
    endrule

    let result_ready_ = i == fromInteger(valueOf(n) / 2);
    method start_ready = !started;
    method result_ready = result_ready_;
    method Action start(Bit#(n) a_, Bit#(n) b_) if (!started);
        // $display("Starting multiplication");
        a <= a_;
        b <= signExtend(b_) << 1;
        i <= '0;
        product <= '0;
        started <= True;
    endmethod
    method ActionValue#(Bit#(TAdd#(n, n))) result() if (result_ready_);
        // $display("Returning result %d", product);
        started <= False;
        i <= '0;
        return product;
    endmethod
endmodule
