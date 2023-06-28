module Ehr_tb ();
    localparam P = 2;
    localparam N = 32;

    reg clk;
    reg rst_n;

    initial begin
        rst_n <= 0;
        #5 rst_n <= 1;
        #100
        $finish;
    end

    always #1 clk <= ~clk;

    reg [P-1:0][N-1:0] wd;
    reg [P-1:0] wv;
    wire [P-1:0][N-1:0] r;

    reg [N-1:0] cnt;

    Ehr #(.N(N), .P(P)) u_Ehr(.clk(clk), .rst_n(rst_n), .wd(wd), .wv(wv), .r(r));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
        end
        else begin
            cnt <= cnt + 1;
            wd[0] <= cnt;
            $display("[%d] r[0]: %x, r[1]: %x", cnt, r[0], r[1]);
        end
    end
endmodule
