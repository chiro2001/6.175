module BypassFifo_tb ();
    parameter N = 4;
    reg clk;
    reg rst_n;
    reg [31:0] cnt;
    reg [N-1:0] d;

    initial begin
        cnt   <= 3;
        clk   <= 0;
        rst_n <= 0;
        #10 rst_n <= 1;
        #100 $finish;
    end

    always #1 clk <= ~clk;

    reg we;
    reg [N-1:0] wdata;
    reg re;
    wire [N-1:0] rdata;
    wire full;
    wire empty;

    BypassFifo #(
        .N(N)
    ) ehr_v (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .wdata(wdata),
        .re(re),
        .rdata(rdata),
        .full(full),
        .empty(empty)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            we <= 0;
            wdata <= 0;
            re <= 0;
            d <= 0;
        end
        else begin
            cnt <= cnt + 1;

            // always enq
            we <= 1;
            wdata <= d;
            d <= d + 1;

            if (!empty) begin
                re <= 1;
            end
            else begin
                re <= 0;
            end

            if (we) begin
                $display("enq: %d", wdata);
            end
            if (re && !empty) begin
                $display("deq: %d", rdata);
            end
            if (full) $display("full");
            if (empty) $display("empty");
            $display("=== [cnt=%x, d=%d] ===", cnt, d);
        end
    end

endmodule
