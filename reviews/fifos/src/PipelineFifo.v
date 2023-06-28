module PipelineFifo #(
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
    reg [N-1:0] data;

    wire wd0;
    wire wd1;
    wire wv0;
    wire wv1;
    wire r0;
    wire r1;
    Ehr2 #(
        .N(1)
    ) u_Ehr2 (
        .clk(clk),
        .rst_n(rst_n),
        .wd0(wd0),
        .wv0(wv0),
        .wd1(wd1),
        .wv1(wv1),
        .r0(r0),
        .r1(r1)
    );
    
    assign full = r1;
    assign empty = !r0;
    assign rdata = data;

    assign wd0 = 1'b0;
    assign wv0 = re && !empty;
    assign wd1 = 1'b1;
    assign wv1 = we && !full;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data <= {N{1'b0}};
        end
        else begin
            if (we) begin
                data <= wdata;
            end
        end
    end

endmodule
