module Ehr #(
  parameter N = 4,
  parameter P = 2
) (
  input clk,
  input rst_n,
  input [P-1:0][N-1:0] wd,
  input [P-1:0] wv,
  output [P-1:0][N-1:0] r
);

  reg [N-1:0] data;

  // WARNING: not supported in Verilog-2001
  // `multiple packed dimensions are not allowed in this mode of verilog'
  wire [N-1:0] mux [P-1:0];
  assign mux[0] = wv[0] ? wd[0] : data;
  assign r[0] = data;
  genvar i;
  generate
    for (i = 1; i < P; i = i + 1) begin
      assign mux[i] = wv[i] ? wd[i] : mux[i-1];
      assign r[i] = mux[i-1];
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data <= {N{1'b0}};
    end
    else begin
      data <= mux[P-1];
    end
  end
  
endmodule