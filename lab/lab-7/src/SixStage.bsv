// SixStage.bsv
// 
// This is a six stage implementation of the RISC-V processor

import FIFOF::*;
import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import FPGAMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Scoreboard::*;
import Btb::*;

typedef struct {
    Addr pc;
    Addr pred_pc;
    Bool epoch;
} F2D deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr pred_pc;
    Bool epoch;
    DecodedInst dInst;
} D2R deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr pred_pc;
    Bool epoch;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
} R2E deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} E2M deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} M2W deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr pred_pc;
} ExRedirect deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    // IMemory  iMem <- mkIMemory;
    // DMemory  dMem <- mkDMemory;
    FPGAMemory iMem <- mkFPGAMemory;
    FPGAMemory dMem <- mkFPGAMemory;
    CsrFile  csrf <- mkCsrFile;
    Scoreboard#(6) sb <- mkBypassScoreboard;
    Btb#(6)   btb <- mkBtb;

    Reg#(Bool) epoch <- mkReg(False);
    FIFOF#(ExRedirect) redirect_pcQ <- mkFIFOF;

    FIFOF#(F2D) f2d <- mkSizedFIFOF(2);
    FIFOF#(D2R) d2r <- mkSizedFIFOF(2);
    FIFOF#(R2E) r2e <- mkSizedFIFOF(2);
    FIFOF#(E2M) e2m <- mkSizedFIFOF(2);
    FIFOF#(M2W) m2w <- mkSizedFIFOF(2);
        
    Bool memReady = iMem.init.done() && dMem.init.done();

    rule test(!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule doFetch if (csrf.started);
        iMem.req(MemReq{ op: Ld, addr: pc, data: ? });
        let pred_pc = btb.predPc(pc);
        // pc need to be updated in the end
        pc <= pred_pc;

        f2d.enq(F2D {pc: pc, pred_pc: pred_pc, epoch: epoch});
        $display("do Fetch at pc: %x", pc);
    endrule

    rule doDecode if (csrf.started);
        let x = f2d.first;
        f2d.deq;

        let inst <- iMem.resp;
        DecodedInst dInst = decode(inst);

        d2r.enq(D2R {pc: x.pc, pred_pc: x.pred_pc, epoch: x.epoch, dInst: dInst});
        $display("do Decode at pc: %x", x.pc);
    endrule

    rule doRegisterFetch if (csrf.started);
        let x = d2r.first;
        // d2r.deq;

        let rVal1 = rf.rd1(fromMaybe(?, x.dInst.src1));
        let rVal2 = rf.rd2(fromMaybe(?, x.dInst.src2));
        let csrVal = csrf.rd(fromMaybe(?, x.dInst.csr));

        if (!sb.search1(x.dInst.src1) && !sb.search2(x.dInst.src2)) begin
            sb.insert(x.dInst.dst);
            r2e.enq(R2E {pc: x.pc, pred_pc: x.pred_pc, epoch: x.epoch, dInst: x.dInst, rVal1: rVal1, rVal2: rVal2, csrVal: csrVal});
            d2r.deq;
            $display("do RegisterFetch at pc: %x", x.pc);
        end
        else begin
            $display("Stalled at pc: %x", x.pc);
        end
    endrule
        
    rule doExecute if (csrf.started);
        let x = r2e.first;
        r2e.deq;

        Maybe#(ExecInst) new_eInst = Invalid;

        if (x.epoch == epoch) begin
            let eInst = exec(x.dInst, x.rVal1, x.rVal2, x.pc, x.pred_pc, x.csrVal);

            if (eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting!\n", x.pc);
                $finish;
            end

            new_eInst = Valid(eInst);

            if (eInst.mispredict) begin
                $display("do Execute find misprediction at pc: %x", x.pc);
                redirect_pcQ.enq(ExRedirect {pc: x.pc, pred_pc: eInst.addr});
            end
            else begin
                $display("do Execute at pc: %x", x.pc);
            end
        end 
        // else means x.epoch != epoch

        e2m.enq(E2M {pc: x.pc, eInst: new_eInst});
    endrule

    rule doMemory if (csrf.started);
        let x = e2m.first;
        e2m.deq;

        if (isValid(x.eInst)) begin
            let eInst = fromMaybe(?, x.eInst);

            if (eInst.iType == Ld) begin
                dMem.req(MemReq{ op: Ld, addr: eInst.addr, data: ? });
            end
            else if (eInst.iType == St) begin
                dMem.req(MemReq{ op: St, addr: eInst.addr, data: eInst.data });
            end
            $display("do Memory at pc: %x", x.pc);
        end
        else begin
            $display("do Memory find a poisoned instruction at pc: %x", x.pc);
        end

        m2w.enq(M2W {pc: x.pc, eInst: x.eInst});
    endrule

    rule doWriteback if (csrf.started);
        let x = m2w.first;
        m2w.deq;

        if (isValid(x.eInst)) begin
            let eInst = fromMaybe(?, x.eInst);

            if (eInst.iType == Ld) begin
                eInst.data <- dMem.resp;
            end

            if (isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
        end
        else begin
            $display("do Writeback find a poisoned instruction at pc: %x", x.pc);
        end

        sb.remove;

    endrule


    // (* fire_when_enabled *)
    // (* no_implicit_conditions *)
    rule cononicalizeRedirect(csrf.started);
        if (redirect_pcQ.notEmpty) begin
            let x = redirect_pcQ.first;
            redirect_pcQ.deq;
            pc <= x.pred_pc;
            epoch <= !epoch;
            btb.update(x.pc, x.pred_pc);
            $display("cononicalizeRedirect Fetch: Mispredict, redirected by Execute");
        end
    endrule

    method ActionValue#(CpuToHostData) cpuToHost if (csrf.started);
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
