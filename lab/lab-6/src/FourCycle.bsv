// FourCycle.bsv
//
// This is a four cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import MemInit::*;
import RFile::*;
import DelayedMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import FIFO::*;
import Ehr::*;
import GetPut::*;

typedef enum {
    Fetch,
    Decode,
    Execute,
    Writeback
} State deriving(Bits, Eq, FShow);

(*synthesize*)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    DelayedMemory iMem <- mkDelayedMemory;
    DelayedMemory dMem <- mkDelayedMemory;
    CsrFile  csrf <- mkCsrFile;
    
    Reg#(State) stage <- mkReg(Fetch);
    Reg#(DecodedInst) decodedInst <- mkRegU;
    Reg#(ExecInst)       execInst <- mkRegU; 

    Bool memReady = iMem.init.done() && dMem.init.done();
    rule test (!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule doFetch if (csrf.started && stage == Fetch);
        iMem.req(MemReq{ op: Ld, addr: pc, data: ? });
        stage <= Decode;
    endrule

    rule doDecode if (csrf.started && stage == Decode);
        let inst <- iMem.resp;
        decodedInst <= decode(inst);
        stage <= Execute;
    endrule

    rule doExecute if (csrf.started && stage == Execute);
        let dInst = decodedInst;
        let rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        let rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        let csrVal = csrf.rd(fromMaybe(?, dInst.csr));
        
        let eInst = exec(dInst, rVal1, rVal2, pc, ?, csrVal);

        if (eInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting!\n", pc);
            $finish;
        end
        
        if (eInst.iType == Ld) begin
            dMem.req(MemReq{ op: Ld, addr: eInst.addr, data: ? });
        end
        else if (eInst.iType == St) begin
            dMem.req(MemReq{ op: St, addr: eInst.addr, data: eInst.data});
        end

        pc <= eInst.brTaken ? eInst.addr : (pc + 4);
        execInst <= eInst;
        stage <= Writeback;
    endrule

    rule doWriteback if (csrf.started && stage == Writeback);
        let eInst = execInst;

        if (eInst.iType == Ld) begin
            eInst.data <- dMem.resp;
        end
        
        if (isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        stage <= Fetch;
        
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if (!csrf.started && memReady);
        csrf.start(0);
        $display("Start at pc %h\n", startpc);
        $fflush(stdout);
        pc <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;

endmodule
