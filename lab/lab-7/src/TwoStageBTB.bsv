// TwoStageBTB.bsv
//
// This is a two stage pipelined (with BTB) implementation of the RISC-V processor.

import FIFOF::*;

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import MemInit::*;
import RFile::*;
import DMemory::*;
import IMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import Btb::*;
import GetPut::*;

typedef struct {
    DecodedInst dInst;
    Addr pc;
    Addr pred_pc;
} F2E deriving(Bits, Eq);

(*synthesize*)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    IMemory  iMem <- mkIMemory;
    DMemory  dMem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;
    Btb#(6)   btb <- mkBtb;

    FIFOF#(F2E) f2e <- mkSizedFIFOF(2);
    
    Bool memReady = iMem.init.done() && dMem.init.done();
    rule test (!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule
    
    rule doFetch if (csrf.started);
        let inst = iMem.req(pc);
        let dInst = decode(inst);
        let newpc = btb.predPc(pc);
        pc <= newpc;
        f2e.enq(F2E{ dInst: dInst, pc: pc });
    endrule

    rule doExecute if (csrf.started);
        let x = f2e.first;
        let dInst = x.dInst;
        let x_pc    = x.pc;
        let ppc = x_pc + 4;

        let rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        let rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        let csrVal = csrf.rd(fromMaybe(?, dInst.csr));
        let eInst = exec(dInst, rVal1, rVal2, x_pc, ppc, csrVal);

        if (eInst.iType == Unsupported) begin
            $fwrite(stderr, "EROOR: Executing unsupported instruction at pc: %x. Exiting!\n", x_pc);
            $finish;
        end

        if (eInst.iType == Br || eInst.iType == J || eInst.iType == Jr) begin
            btb.update(x_pc, eInst.addr);
        end

        if (eInst.iType == Ld) begin
            eInst.data <- dMem.req(MemReq{ op: Ld, addr: eInst.addr, data: ? });
        end
        else if (eInst.iType == St) begin
            let dummy <- dMem.req(MemReq{ op: St, addr: eInst.addr, data: eInst.data });
        end

        if (isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        if (eInst.mispredict) begin
            pc <= eInst.addr;
            f2e.clear;
        end
	    else begin
	        f2e.deq;
	    end

        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
    endrule
    
    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod
    
    method Action hostToCpu(Bit#(32) startpc) if (!csrf.started && memReady);
        csrf.start(0);
        pc <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;

endmodule
