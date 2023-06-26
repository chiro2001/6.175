import Vector :: *;
import Complex :: *;

import FftCommon :: *;
import Fifo :: *;
import FIFOF :: *;
import FIFO :: *;
import SpecialFIFOs :: *;

interface Fft;
    method Action enq(Vector#(FftPoints, ComplexData) in);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
endinterface


(* synthesize *)
module mkFftCombinational(Fft);
    FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
    FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction
  
    rule doFft;
            inFifo.deq;
            Vector#(4, Vector#(FftPoints, ComplexData)) stage_data;
            stage_data[0] = inFifo.first;
      
            for (StageIdx stage = 0; stage < 3; stage = stage + 1) begin
                stage_data[stage + 1] = stage_f(stage, stage_data[stage]);
            end
            outFifo.enq(stage_data[3]);
    endrule
    
    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

typedef Vector#(FftPoints, ComplexData) FftFrameData;

// Exercise 2
// Chiro: `Inelastic' means stages data should always pass to next stage if output fifo is not full
(* synthesize *)
module mkFftInelasticPipeline(Fft);
    // copy from mkFftCombinational
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));
    function FftFrameData stage_f(StageIdx stage, FftFrameData stage_in);
        FftFrameData stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction
    // input output fifos. `mkFIFOF': size 2, can concurrenly enq and deq when size == 1
    FIFOF#(FftFrameData) inFifo <- mkFIFOF;
    FIFOF#(FftFrameData) outFifo <- mkFIFOF;
    
    // stage regs with valid bit
    // Chiro: get value `fromMaybe', other functions?
    Vector#(2, Reg#(Maybe#(FftFrameData))) stages <- replicateM(mkReg(tagged Invalid));

    rule input_to_stage1 /* if (inFifo.notEmpty) */;
        inFifo.deq;
        stages[0] <= tagged Valid(stage_f(0, inFifo.first));
    endrule

    rule insert_buble if (!inFifo.notEmpty);
        stages[0] <= tagged Invalid;
    endrule

    // only stage 1 to stage 2 when NumStages == 3
    for (Integer i = 0; i < valueOf(NumStages) - 2; i = i + 1) begin
        // failed on: `if (outFifo.notFull)`, why?
        rule stage_to_next_stage;
            if (isValid(stages[i])) begin
                stages[i + 1] <= tagged Valid(stage_f(fromInteger(i + 1), fromMaybe(unpack('0), stages[i])));
            end else begin
                stages[i + 1] <= tagged Invalid;
            end
        endrule
    end
    
    rule stage_to_output;
        if (isValid(stages[valueOf(NumStages) - 2])) begin
            outFifo.enq(stage_f(fromInteger(valueOf(NumStages) - 1), fromMaybe(unpack('0), stages[valueOf(NumStages) - 2])));
        end
    endrule

    // same logic as belows when NumStages == 3
    // rule sync_pipeline;
    //     if (outFifo.notFull || isValid(stages[1])) begin
    //         if (inFifo.notEmpty) begin
    //             stages[0] <= tagged Valid(stage_f(0, inFifo.first));
    //             inFifo.deq;
    //         end else begin
    //             stages[0] <= tagged Invalid;
    //         end
    //     end
    //     // Chiro: better ways to use Maybe#()?
    //     if (isValid(stages[0])) begin
    //         stages[1] <= tagged Valid(stage_f(1, fromMaybe(unpack('0), stages[0])));
    //     end else begin
    //         stages[1] <= tagged Invalid;
    //     end
    //     if (isValid(stages[1])) begin
    //         // Chiro: implicit `outFifo.notFull`?
    //         outFifo.enq(stage_f(2, fromMaybe(unpack('0), stages[1])));
    //     end
    // endrule

    method Action enq(FftFrameData in);
        inFifo.enq(in);
        // $display("enq");
    endmethod

    method ActionValue#(FftFrameData) deq;
        outFifo.deq;
        // $display("deq");
        return outFifo.first;
    endmethod

    // logic from slides
    // rule sync_pipeline;
    //     if (outQ.notFull || sReg2v != True)
    //         if (inQ.notEmpty) begin
    //             sReg1 <= f0(inQ.first);
    //             inQ.deq;
    //             sReg1v <= True;
    //         end else begin
    //             sReg1v <= False;
    //         end
    //     end
    //     sReg2 <= f1(sReg1);
    //     sReg2v <= sReg1v;
    //     if (sReg2v == true) begin
    //         outQ.enq(f2(sReg2));
    //     end
    // endrule

endmodule

// Exercise 3
(* synthesize *)
module mkFftElasticPipeline(Fft);
   // copy from mkFftCombinational
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));
    function FftFrameData stage_f(StageIdx stage, FftFrameData stage_in);
        FftFrameData stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction
    // input output fifos. `mkFIFOF': size 2, can concurrenly enq and deq when size == 1
    FIFOF#(FftFrameData) inFifo <- mkFIFOF;
    FIFOF#(FftFrameData) outFifo <- mkFIFOF;
    // stage fifos
    // FIFO cannot concurrenly enq and deq when full, sz=2, finish at #193
    // Vector#(NumStages, FIFO#(FftFrameData)) stages <- replicateM(mkFIFO);
    // FIFO1 cannot concurrenly enq and deq when full, sz=1, finish at #258
    // Vector#(NumStages, FIFO#(FftFrameData)) stages <- replicateM(mkFIFO1);
    // LFIFO can concurrenly enq and deq when full, finish at #193
    // Vector#(NumStages, FIFO#(FftFrameData)) stages <- replicateM(mkLFIFO);
    // BypassFIFO can concurrenly enq and deq when empty, finish at #129
    // Vector#(NumStages, FIFO#(FftFrameData)) stages <- replicateM(mkBypassFIFO);
    // using my CFifo1, finish at #258
    // Vector#(NumStages, Fifo#(1, FftFrameData)) stages <- replicateM(mkCFifo1);
    // using CFFifo, finish at #193
    // Vector#(NumStages, Fifo#(2, FftFrameData)) stages <- replicateM(mkCFFifo);
    // using my CFifo3, finish at #193
    // Vector#(NumStages, Fifo#(3, FftFrameData)) stages <- replicateM(mkCFifo3);
    // using mkFifo, finish at #193
    // Vector#(NumStages, Fifo#(3, FftFrameData)) stages <- replicateM(mkFifo);
    // using BypassFifo, finish at #129
    Vector#(NumStages, Fifo#(1, FftFrameData)) stages <- replicateM(mkBypassFifo);
    

    rule input_to_stages;
        inFifo.deq;
        stages[0].enq(stage_f(0, inFifo.first));
    endrule

    for (Integer i = 0; i < valueOf(NumStages) - 2; i = i + 1) begin
        rule stage_to_next_stage;
            stages[i + 1].enq(stage_f(fromInteger(i + 1), stages[i].first));
            stages[i].deq;
        endrule
    end

    rule stages_to_output;
        outFifo.enq(stage_f(fromInteger(valueOf(NumStages) - 1), stages[valueOf(NumStages) - 2].first));
        stages[valueOf(NumStages) - 2].deq;
    endrule

    method Action enq(FftFrameData in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(FftFrameData) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

