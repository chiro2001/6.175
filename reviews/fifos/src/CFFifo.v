module CFFifo #(
    parameter N = 32
) (
    input clk,
    input rst_n,
    input we,
    input [N-1:0] wdata,
    input re,
    output [N-1:0] rdata,
    output full,
    output empty
);
    wire va_wd0;
    wire va_wd1;
    wire va_wv0;
    wire va_wv1;
    wire va_r0;
    wire va_r1;
    Ehr2 #(
        .N(1)
    ) ehr_va (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(va_wd0),
        .wv0(va_wv0),
        .wd1(va_wd1),
        .wv1(va_wv1),
        .r0(va_r0),
        .r1(va_r1)
    );
    
    wire [N-1:0] da_wd0;
    wire [N-1:0] da_wd1;
    wire da_wv0;
    wire da_wv1;
    wire [N-1:0] da_r0;
    wire [N-1:0] da_r1;
    Ehr2 #(
        .N(N)
    ) ehr_da (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(da_wd0),
        .wv0(da_wv0),
        .wd1(da_wd1),
        .wv1(da_wv1),
        .r0(da_r0),
        .r1(da_r1)
    );
    
    wire vb_wd0;
    wire vb_wd1;
    wire vb_wv0;
    wire vb_wv1;
    wire vb_r0;
    wire vb_r1;
    Ehr2 #(
        .N(1)
    ) ehr_vb (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(vb_wd0),
        .wv0(vb_wv0),
        .wd1(vb_wd1),
        .wv1(vb_wv1),
        .r0(vb_r0),
        .r1(vb_r1)
    );
    
    wire [N-1:0] db_wd0;
    wire [N-1:0] db_wd1;
    wire db_wv0;
    wire db_wv1;
    wire [N-1:0] db_r0;
    wire [N-1:0] db_r1;
    Ehr2 #(
        .N(N)
    ) ehr_db (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(db_wd0),
        .wv0(db_wv0),
        .wd1(db_wd1),
        .wv1(db_wv1),
        .r0(db_r0),
        .r1(db_r1)
    );

    assign full = !vb_r0;
    assign empty = !va_r0;

    // enq
    assign db_wd0 = wdata;
    assign db_wv0 = we && !full;
    assign vb_wd0 = 1;
    assign vb_wv0 = we && !full;
    // deq
    assign va_wd0 = 0;
    assign va_wv0 = re && !empty;
    // first
    assign rdata = va_r0 ? da_r0 : {N{'b1}};
    // canonicalize
    wire canonicalize;
    assign canonicalize = vb_r1 && !va_r0;
    assign da_wd1 = db_r1;
    assign da_wv1 = canonicalize;
    assign va_wd1 = 1;
    assign va_wv1 = canonicalize;
    assign vb_wd1 = 0;
    assign vb_wv1 = canonicalize;

endmodule
