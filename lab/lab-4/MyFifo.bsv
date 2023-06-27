import Ehr :: *;
import Vector :: *;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

/////////////////
// Conflict FIFO

// Exercise 1
module mkMyConflictFifo(Fifo#(n, t)) provisos (Bits#(t, tSz));
    Vector#(n, Reg#(t)) data <- replicateM(mkRegU);
    // pointers
    Reg#(Bit#(TLog#(n))) wp <- mkReg(0);
    Reg#(Bit#(TLog#(n))) rp <- mkReg(0);
    // use registers instead of pointer MSB
    Reg#(Bool) full <- mkReg(False);
    Reg#(Bool) empty <- mkReg(True);

    method notFull = !full;
    method notEmpty = !empty;
    method t first if (!empty) = data[rp];
    method Action enq(t x) if (!full);
        data[wp] <= x;
        let next_wp = (wp == fromInteger(valueOf(n) - 1)) ? 0 : wp + 1;
        wp <= next_wp;
        full <= next_wp == rp;
        empty <= False;
    endmethod
    method Action deq if (!empty);
        let next_rp = (rp == fromInteger(valueOf(n) - 1)) ? 0 : rp + 1;
        rp <= next_rp;
        full <= False;
        empty <= next_rp == wp;
    endmethod
    method Action clear;
        wp <= 0;
        rp <= 0;
        full <= False;
        empty <= True;
    endmethod
endmodule


//Exercise 2
// Pipeline FIFO
// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo(Fifo#(n, t)) provisos (Bits#(t, tSz));
    Vector#(n, Reg#(t)) data <- replicateM(mkRegU);
    // pointers
    Ehr#(3, Bit#(TLog#(n))) wp <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) rp <- mkEhr(0);
    // use registers instead of pointer MSB
    Ehr#(3, Bool) full <- mkEhr(False);
    Ehr#(3, Bool) empty <- mkEhr(True);

    method notFull = !full[1];
    method notEmpty = !empty[0];
    method t first if (!empty[0]) = data[rp[0]];
    method Action enq(t x) if (!full[1]);
        data[wp[1]] <= x;
        let next_wp = (wp[1] == fromInteger(valueOf(n) - 1)) ? 0 : wp[1] + 1;
        wp[1] <= next_wp;
        full[1] <= next_wp == rp[1];
        empty[1] <= False;
    endmethod
    // can concurrently deq and enq when not full
    method Action deq;
        let next_rp = (rp[0] == fromInteger(valueOf(n) - 1)) ? 0 : rp[0] + 1;
        rp[0] <= next_rp;
        full[0] <= False;
        empty[0] <= next_rp == wp[0];
    endmethod
    method Action clear;
        wp[2] <= 0;
        rp[2] <= 0;
        full[2] <= False;
        empty[2] <= True;
    endmethod
endmodule

// Exercise 2
// Bypass FIFO
// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo(Fifo#(n, t)) provisos (Bits#(t, tSz), Literal#(t));
    Vector#(n, Ehr#(2, t)) data <- replicateM(mkEhr(0));
    // pointers
    Ehr#(3, Bit#(TLog#(n))) wp <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) rp <- mkEhr(0);
    // use registers instead of pointer MSB
    Ehr#(3, Bool) full <- mkEhr(False);
    Ehr#(3, Bool) empty <- mkEhr(True);

    method notFull = !full[0];
    method notEmpty = !empty[1];
    method t first if (!empty[1]) = data[rp[1]][1];
    method Action enq(t x) if (!full[0]);
        data[wp[0]][0] <= x;
        let next_wp = (wp[0] == fromInteger(valueOf(n) - 1)) ? 0 : wp[0] + 1;
        wp[0] <= next_wp;
        full[0] <= next_wp == rp[0];
        empty[0] <= False;
    endmethod
    // can concurrently deq and enq when not full
    method Action deq;
        let next_rp = (rp[1] == fromInteger(valueOf(n) - 1)) ? 0 : rp[1] + 1;
        rp[1] <= next_rp;
        full[1] <= False;
        empty[1] <= next_rp == wp[1];
    endmethod
    method Action clear;
        wp[2] <= 0;
        rp[2] <= 0;
        full[2] <= False;
        empty[2] <= True;
    endmethod
endmodule


// Exercise 3
// Exercise 4
// Conflict-free fifo
// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo(Fifo#(n, t)) provisos (Bits#(t, tSz));
    Vector#(n, Reg#(t)) data <- replicateM(mkRegU);
    // pointers
    Ehr#(2, Bit#(TLog#(n))) wp <- mkEhr(0);
    Ehr#(2, Bit#(TLog#(n))) rp <- mkEhr(0);
    // use registers instead of pointer MSB
    Ehr#(2, Bool) full <- mkEhr(False);
    Ehr#(2, Bool) empty <- mkEhr(True);

    // Ehr for methods
    Ehr#(2, Maybe#(t)) req_enq <- mkEhr(tagged Invalid);
    Ehr#(2, Bool) req_deq <- mkEhr(False);
    Ehr#(2, Bool) req_clear <- mkEhr(False);

    // this rule is always avaiable, should fire after all methods
    (* no_implicit_conditions, fire_when_enabled *)
    rule canonicalize;
        let next_rp = (rp[0] == fromInteger(valueOf(n) - 1)) ? 0 : rp[0] + 1;
        let next_wp = (wp[0] == fromInteger(valueOf(n) - 1)) ? 0 : wp[0] + 1;
        let can_enq = !full[0] && isValid(req_enq[1]);
        let can_deq = !empty[0] && req_deq[1];
        // handle enq & deq concurrently
        if (can_enq && can_deq) begin
            data[wp[0]] <= fromMaybe(?, req_enq[1]);
            wp[0] <= next_wp;
            rp[0] <= next_rp;
        end
        // handle enq only
        else if (can_enq) begin
            full[0] <= next_wp == rp[0];
            data[wp[0]] <= fromMaybe(?, req_enq[1]);
            wp[0] <= next_wp;
            empty[0] <= False;
        end
        // handle deq only
        else if (can_deq) begin
            empty[0] <= next_rp == wp[0];
            rp[0] <= next_rp;
            full[0] <= False;
        end
        // handle clear
        if (req_clear[1]) begin
            wp[1] <= 0;
            rp[1] <= 0;
            full[1] <= False;
            empty[1] <= True;
        end
        // clear method ehrs
        req_clear[1] <= False;
        req_deq[1] <= False;
        req_enq[1] <= tagged Invalid;
    endrule

    // in the same level 0
    method notFull = !full[0];
    method notEmpty = !empty[0];
    method t first if (!empty[0]) = data[rp[0]];
    method Action enq(t x) if (!full[0]);
        req_enq[0] <= tagged Valid(x);
    endmethod
    method Action deq if (!empty[0]);
        req_deq[0] <= True;
    endmethod
    method Action clear;
        req_clear[0] <= True;
    endmethod
endmodule

