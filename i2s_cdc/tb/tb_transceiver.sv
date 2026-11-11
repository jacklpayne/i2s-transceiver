// -----------------------------------------------------------------------------
// Two CDC transceivers on one I2S bus, each with its OWN unrelated mclk.
//   A.sd_o -> B.sd_i  and  B.sd_o -> A.sd_i  (both directions checked at once)
// Producers write pairs whenever tx_ready; consumers read whenever rx_valid.
// Every pair read must equal the pair written, in order (bit-exact, no loss,
// no duplication), and neither side may flag underflow/overflow.
// Sweeps 8 configurations of master side, divider, and slave mclk/BCLK ratio,
// including ratios < 8 and < 1 that the mclk-only version cannot handle.
// Run length: +NPAIRS=<n> per direction per config (default 5000 = 10k samples).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_transceiver;
    localparam int SW = 24, SL = 32;

    logic mclk_a = 0, mclk_b = 0, rst_n;
    realtime ha = 5, hb = 5;
    always #(ha) mclk_a = ~mclk_a;
    always #(hb) mclk_b = ~mclk_b;

    logic a_master;
    logic [2:0] sel;
    logic [SW-1:0] a_txl, a_txr, b_txl, b_txr, a_rxl, a_rxr, b_rxl, b_rxr;
    logic a_txv, b_txv, a_txr_dy, b_txr_dy, a_rxv, b_rxv;
    logic a_bclk_o, a_ws_o, b_bclk_o, b_ws_o, a_sd, b_sd;
    logic a_uf, a_of, b_uf, b_of;

    wire bclk = a_master ? a_bclk_o : b_bclk_o;
    wire ws   = a_master ? a_ws_o   : b_ws_o;

    i2s_transceiver #(.SAMPLE_WIDTH(SW), .SLOT_WIDTH(SL)) A (
        .mclk(mclk_a), .rst_n, .master_mode(a_master), .clk_div_sel(sel),
        .bclk_i(bclk), .bclk_o(a_bclk_o), .ws_i(ws), .ws_o(a_ws_o),
        .tx_l_word(a_txl), .tx_r_word(a_txr), .tx_valid(a_txv), .tx_ready(a_txr_dy), .sd_o(a_sd),
        .sd_i(b_sd), .rx_l_word(a_rxl), .rx_r_word(a_rxr), .rx_valid(a_rxv), .rx_ready(1'b1),
        .tx_underflow(a_uf), .rx_overflow(a_of));

    i2s_transceiver #(.SAMPLE_WIDTH(SW), .SLOT_WIDTH(SL)) B (
        .mclk(mclk_b), .rst_n, .master_mode(!a_master), .clk_div_sel(sel),
        .bclk_i(bclk), .bclk_o(b_bclk_o), .ws_i(ws), .ws_o(b_ws_o),
        .tx_l_word(b_txl), .tx_r_word(b_txr), .tx_valid(b_txv), .tx_ready(b_txr_dy), .sd_o(b_sd),
        .sd_i(a_sd), .rx_l_word(b_rxl), .rx_r_word(b_rxr), .rx_valid(b_rxv), .rx_ready(1'b1),
        .tx_underflow(b_uf), .rx_overflow(b_of));

    // Expected pairs per direction: [0] A->B, [1] B->A
    logic [2*SW-1:0] q [2][$];
    int got [2], errors [2], npairs, total_fail;

    // Producers
    always @(posedge mclk_a) if (a_txv && a_txr_dy) begin
        q[0].push_back({a_txl, a_txr}); a_txl <= $urandom; a_txr <= $urandom;
    end
    always @(posedge mclk_b) if (b_txv && b_txr_dy) begin
        q[1].push_back({b_txl, b_txr}); b_txl <= $urandom; b_txr <= $urandom;
    end

    // Consumers
    task automatic check(int d, logic [2*SW-1:0] g);
        logic [2*SW-1:0] e;
        e = q[d].pop_front(); got[d]++;
        if (g !== e) begin
            errors[d]++;
            if (errors[d] < 4) $display("  MISMATCH dir %0d pair %0d: got %h exp %h", d, got[d], g, e);
        end
    endtask
    always @(posedge mclk_b) if (rst_n && b_rxv) check(0, {b_rxl, b_rxr});
    always @(posedge mclk_a) if (rst_n && a_rxv) check(1, {a_rxl, a_rxr});

    task automatic run(input bit am, input logic [2:0] s, input realtime ta, input realtime tb);
        realtime t_bclk, t_slave, timeout;
        bit ok;
        rst_n = 0; a_txv = 0; b_txv = 0;
        a_master = am; sel = s; ha = ta/2; hb = tb/2;
        for (int d = 0; d < 2; d++) begin q[d].delete(); got[d] = 0; errors[d] = 0; end
        a_txl = $urandom; a_txr = $urandom; b_txl = $urandom; b_txr = $urandom;
        t_bclk  = (am ? ta : tb) * (2 << s);
        t_slave = am ? tb : ta;
        #(20*(ta+tb));
        rst_n = 1;
        #(5*(ta+tb));
        a_txv = 1; b_txv = 1;
        timeout = (npairs + 10) * 2 * SL * t_bclk;
        fork
            wait (got[0] >= npairs && got[1] >= npairs);
            #(timeout);
        join_any
        disable fork;
        ok = errors[0] == 0 && errors[1] == 0 && got[0] >= npairs && got[1] >= npairs
             && !a_uf && !a_of && !b_uf && !b_of;
        $display("%s master, div %3d, slave mclk/BCLK = %6.2f | A->B %0d pairs %0d err | B->A %0d pairs %0d err | uf/of A:%0d%0d B:%0d%0d | %s",
                 am ? "A" : "B", 2 << s, t_bclk / t_slave,
                 got[0], errors[0], got[1], errors[1], a_uf, a_of, b_uf, b_of, ok ? "PASS" : "FAIL");
        if (!ok) total_fail++;
    endtask

    initial begin
        total_fail = 0;
        if (!$value$plusargs("NPAIRS=%d", npairs)) npairs = 5000;
        //  master  sel  T_mclk_A  T_mclk_B
        run(1, 3'd1, 10.0,   7.3);   // ratio ~5.5
        run(1, 3'd2, 10.0,  33.7);   // ratio ~2.4
        run(1, 3'd3, 10.0, 171.0);   // ratio ~0.94 (slave mclk slower than BCLK)
        run(1, 3'd0, 10.0,   3.1);   // div 2, ratio ~6.5
        run(0, 3'd1, 13.9,  10.0);   // ratio ~2.9
        run(0, 3'd4,  2.3,  10.0);   // ratio ~139
        run(0, 3'd2, 61.0,  10.0);   // ratio ~1.3
        run(0, 3'd5,  9.7,  10.0);   // ratio ~66
        if (total_fail == 0) $display("ALL PASS"); else $display("%0d FAILED", total_fail);
        $finish;
    end
endmodule
