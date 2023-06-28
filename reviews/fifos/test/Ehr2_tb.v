module Ehr2_tb ();
    parameter N = 32;
    reg clk;
    reg rst_n;

    initial begin
        clk <= 0;
        rst_n <= 0;
        #8 rst_n <= 1;
        #100 $finish;
    end
    always #1 clk <= ~clk;
    reg [N-1:0] cnt;

    reg [N-1:0] wd0;
    reg [N-1:0] wd1;
    reg wv0;
    reg wv1;
    wire [N-1:0] r0;
    wire [N-1:0] r1;

    Ehr2 #(
        .N(N)
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

    always #2 begin
        if (!rst_n) begin
            cnt <= 0;
            wd0 <= 1;
            wd1 <= 2;
            wv0 <= 0;
            wv1 <= 0;
        end
        else begin
            cnt <= cnt + 1;
            wv0 <= 1;
            wv1 <= 1;
            wd0 <= cnt;
            wd1 <= ~cnt;
        end
    end
endmodule
