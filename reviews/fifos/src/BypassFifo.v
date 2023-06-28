module BypassFifo #(
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
    wire wd0;
    wire wd1;
    wire wv0;
    wire wv1;
    wire r0;
    wire r1;
    Ehr2 #(
        .N(1)
    ) ehr_v (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(wd0),
        .wv0(wv0),
        .wd1(wd1),
        .wv1(wv1),
        .r0(r0),
        .r1(r1)
    );
    
    wire [N-1:0] dwd0;
    wire [N-1:0] dwd1;
    wire dwv0;
    wire dwv1;
    wire [N-1:0] dr0;
    wire [N-1:0] dr1;
    Ehr2 #(
        .N(N)
    ) ehr_d (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(dwd0),
        .wv0(dwv0),
        .wd1(dwd1),
        .wv1(dwv1),
        .r0(dr0),
        .r1(dr1)
    );

    assign full = r0;
    assign empty = !r1;

    // enq
    assign wd0 = 1'b1;
    assign wv0 = we && !full;
    assign dwd0 = wdata;
    assign dwv0 = we && !full;
    // deq
    assign wd1 = 1'b0;
    assign wv1 = re && !empty;
    // first
    assign rdata = dr1;

endmodule
