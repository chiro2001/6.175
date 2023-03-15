// SixStageBHT.bsv
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
import Bht::*;

typedef struct {
    Addr pc;
    Addr pred_pc;
    Bool dec_epoch;
    Bool reg_epoch;
    Bool exe_epoch;
} F2D deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr pred_pc;
    Bool reg_epoch;
    Bool exe_epoch;
    DecodedInst dInst;
} D2R deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr pred_pc;
    Bool exe_epoch;
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
    FPGAMemory iMem <- mkFPGAMemory;
    FPGAMemory dMem <- mkFPGAMemory;
    CsrFile  csrf <- mkCsrFile;
    Scoreboard#(6) sb <- mkBypassScoreboard;
    Btb#(6)     btb <- mkBtb;
    Bht#(8)     bht <- mkBht;

    Reg#(Bool) exe_epoch <- mkReg(False);
    Reg#(Bool) reg_epoch <- mkReg(False);
    Reg#(Bool) dec_epoch <- mkReg(False);

    FIFOF#(F2D) f2d <- mkSizedFIFOF(2);
    FIFOF#(D2R) d2r <- mkSizedFIFOF(2);
    FIFOF#(R2E) r2e <- mkSizedFIFOF(2);
    FIFOF#(E2M) e2m <- mkSizedFIFOF(2);
    FIFOF#(M2W) m2w <- mkSizedFIFOF(2);

    function Bool isBranch(IType iType);
        return (iType == J || iType == Br);
    endfunction

    function Addr getTarget_pc(Data val, Maybe#(Data) imm);
        return {truncateLSB(val + fromMaybe(?, imm)), 1'b0};
    endfunction

    Bool memReady = iMem.init.done() && dMem.init.done();

    rule test(!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule doFetch if (csrf.started);
        iMem.req(MemReq{ op: Ld, addr: pc, data: ? });
        let pred_pc = btb.predPc(pc);
        pc <= pred_pc;

        f2d.enq(F2D {pc: pc, pred_pc: pred_pc, dec_epoch: dec_epoch, reg_epoch: reg_epoch, exe_epoch: exe_epoch });
        $display("do Fetch at pc: %x", pc);
    endrule

    rule doDecode if (csrf.started);
        let x = f2d.first;
        f2d.deq;

        let inst <- iMem.resp;
        if (x.dec_epoch != dec_epoch || x.reg_epoch != reg_epoch || x.exe_epoch != exe_epoch) begin
            $display("doDecode and killed inst with wrong epoch: PC = %x, inst = %x, expanded = ", x.pc, inst, showInst(inst));
        end
        else begin
            DecodedInst dInst = decode(inst);
            let pred_pc = dInst.iType == Br ? bht.ppcDP(x.pc, x.pc + fromMaybe(?, dInst.imm)) : x.pred_pc;

            if (x.pred_pc != pred_pc) begin
                dec_epoch <= !dec_epoch;
                pc <= pred_pc;
                $display("doDecode and pc redirect bt BHT: pc = %x, ppc = %x, inst = %x, expanded = ", x.pc, pred_pc, inst, showInst(inst));
            end

            d2r.enq(D2R { pc: x.pc, pred_pc: pred_pc, reg_epoch: x.reg_epoch, exe_epoch: x.exe_epoch, dInst: dInst });
            $display("doDecode: pc = %x, inst = %x, expanded = ", x.pc, inst, showInst(inst));
        end
    endrule

    rule doRegisterFetch if (csrf.started);
        let x = d2r.first;

        let rVal1 = rf.rd1(fromMaybe(?, x.dInst.src1));
        let rVal2 = rf.rd2(fromMaybe(?, x.dInst.src2));
        let csrVal = csrf.rd(fromMaybe(?, x.dInst.csr));

        if (x.reg_epoch != reg_epoch || x.exe_epoch != exe_epoch) begin
            d2r.deq;
            $display("RegisterFetch kill instruction with wrong epoch at pc: %x", x.pc);
        end
        else begin
            let pred_pc = x.dInst.iType == Jr ? bht.ppcDP(x.pc, getTarget_pc(rVal1, x.dInst.imm)) : x.pred_pc;

            if (pred_pc != x.pred_pc) begin
                reg_epoch <= !reg_epoch;
                pc <= pred_pc;
                $display("RegisterFetch and PC redirect by BHT at pc: %x, pred_pc: %x", x.pc, pred_pc);
            end

            if (!sb.search1(x.dInst.src1) && !sb.search2(x.dInst.src2)) begin
                sb.insert(x.dInst.dst);
                r2e.enq(R2E { pc: x.pc, pred_pc: x.pred_pc, exe_epoch: x.exe_epoch, dInst: x.dInst, rVal1: rVal1, rVal2: rVal2, csrVal: csrVal });
                d2r.deq;
                $display("do RegisterFetch at pc: %x", x.pc);
            end
            else begin
                $display("RegisterFetch Stalled at pc: %x", x.pc);
            end 
        end
    endrule

    rule doExecute if (csrf.started);
        let x = r2e.first;
        r2e.deq;

        Maybe#(ExecInst) new_eInst = Invalid;

        if (x.exe_epoch == exe_epoch) begin
            let eInst = exec(x.dInst, x.rVal1, x.rVal2, x.pc, x.pred_pc, x.csrVal);

            if (eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting!\n", x.pc);
                $finish;
            end

            new_eInst = Valid(eInst);

            if (eInst.mispredict) begin
                $display("do Execute find misprediction at pc: %x", x.pc);
                let jump = eInst.iType == J || eInst.iType == Jr || eInst.iType == Br;
                let next_pc = jump ? eInst.addr : x.pc + 4;
                pc <= next_pc; 
                exe_epoch <= !exe_epoch;
                btb.update(x.pc, eInst.addr);
            end
            else begin
                $display("do Execute at pc: %x", x.pc);
            end

            if (isBranch(eInst.iType)) begin
                bht.update(x.pc, eInst.brTaken);
            end
        end
        else begin
            $display("do Execute: kill instruction at pc: %x\n", x.pc);
        end

        e2m.enq(E2M { pc: x.pc, eInst: new_eInst });
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

        m2w.enq(M2W { pc: x.pc, eInst: x.eInst });
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
            $display("do Writeback at pc: %x", x.pc);
        end
        else begin
            $display("do Writeback find a poisoned instruction at pc: %x", x.pc);
        end

        sb.remove;

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


