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
endmodule

// Exercise 2
// Bypass FIFO
// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo(Fifo#(n, t)) provisos (Bits#(t, tSz));
endmodule


// Exercise 3
// Exercise 4
// Conflict-free fifo
// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo(Fifo#(n, t)) provisos (Bits#(t, tSz));
endmodule

