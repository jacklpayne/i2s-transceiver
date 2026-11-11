// Unit test for fifo1: unrelated wclk/rclk, random winc/rinc.
// Checks data order, no loss/duplication, Gray pointers change 1 bit at a time.
`timescale 1ns/1ps
module tb_fifo1;
    localparam int DSIZE = 16, ASIZE = 4, N = 20000;

    logic wclk = 0, rclk = 0, wrst_n, rrst_n;
    realtime hw, hr;
    always #(hw) wclk = ~wclk;
    always #(hr) rclk = ~rclk;

    logic [DSIZE-1:0] wdata, rdata;
    logic winc, rinc, wfull, rempty;

    fifo1 #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut (.*);

    logic [DSIZE-1:0] q [$];
    int nw, nr, errors, gray_err, total_fail;
    int wprob, rprob;

    always @(posedge wclk) if (wrst_n) begin
        if (winc && !wfull) begin q.push_back(wdata); nw++; wdata <= $urandom; end
        winc <= ($urandom_range(99) < wprob) && nw < N;
    end
    always @(posedge rclk) if (rrst_n) begin
        if (rinc && !rempty) begin
            logic [DSIZE-1:0] e;
            e = q.pop_front(); nr++;
            if (rdata !== e) begin errors++; if (errors < 4) $display("  MISMATCH %0d: got %h exp %h", nr, rdata, e); end
        end
        rinc <= $urandom_range(99) < rprob;
    end

    // Gray property: synchronized pointers may only change by one bit per clock
    logic [ASIZE:0] wptr_d, rptr_d;
    always @(posedge rclk) begin rptr_d <= dut.rptr; if (rrst_n && $countones(dut.rptr ^ rptr_d) > 1) gray_err++; end
    always @(posedge wclk) begin wptr_d <= dut.wptr; if (wrst_n && $countones(dut.wptr ^ wptr_d) > 1) gray_err++; end

    task automatic run(realtime tw, realtime tr, int wp, int rp, string name);
        hw = tw/2; hr = tr/2; wprob = wp; rprob = rp;
        wrst_n = 0; rrst_n = 0; winc = 0; rinc = 0; wdata = $urandom;
        q.delete(); nw = 0; nr = 0; errors = 0; gray_err = 0;
        #(5*(tw+tr)); wrst_n = 1; rrst_n = 1;
        wait (nr == N);
        $display("%-34s wrote=%0d read=%0d errors=%0d gray_err=%0d %s", name, nw, nr, errors, gray_err,
                 (errors == 0 && gray_err == 0) ? "PASS" : "FAIL");
        if (errors || gray_err) total_fail++;
    endtask

    initial begin
        total_fail = 0;
        run(10.0, 37.3, 90, 90, "fast write, slow read");
        run(41.7, 10.0, 90, 90, "slow write, fast read");
        run(10.0, 10.3, 50, 50, "near-equal clocks, random");
        run(7.1,  13.9, 100, 30, "mostly full");
        run(13.9, 7.1,  30, 100, "mostly empty");
        if (total_fail == 0) $display("ALL PASS"); else $display("%0d FAILED", total_fail);
        $finish;
    end
endmodule
