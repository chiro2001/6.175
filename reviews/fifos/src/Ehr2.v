module Ehr2 #(
    parameter N = 1
) (
    input clk,
    input rst_n,
    input [N-1:0] wd0,
    input wv0,
    input [N-1:0] wd1,
    input wv1,
    output [N-1:0] r0,
    output [N-1:0] r1
);
    reg [N-1:0] data;

    wire [N-1:0] mux1;
    assign mux1 = wv0 ? wd0 : data;

    wire [N-1:0] mux2;
    assign mux2 = wv1 ? wd1 : mux1;

    assign r0 = data;
    assign r1 = mux1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data <= {N{1'b0}};
        end
        else begin
            data <= mux2;
        end
    end

endmodule
