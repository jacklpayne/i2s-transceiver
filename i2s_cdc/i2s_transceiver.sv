// -----------------------------------------------------------------------------
// I2S transceiver, CDC version: words cross clock domains through async FIFOs.
//
// Domains
//   mclk     : sample interface (tx_*, rx_*), status, master-mode BCLK/WS generator
//   bclk_clk : RX datapath (rising edge), RX FIFO write side
//   tx_clk   : ~bclk_clk, TX datapath (BCLK falling edge), TX FIFO read side
//
// Crossings
//   TX words  mclk -> tx_clk   : fifo1 (Gray pointers, 2-FF pointer sync)
//   RX words  bclk_clk -> mclk : fifo1
//   Status    tx_clk/bclk_clk -> mclk : sticky flags through 2-FF synchronizers
//   Reset     per-domain rst_sync (async assert, sync deassert)
//
// No mclk/BCLK ratio requirement for the serial side. mclk only has to keep up
// with one pair per frame on the FIFO interfaces.
// -----------------------------------------------------------------------------
module i2s_transceiver #(
    int SAMPLE_WIDTH, int SLOT_WIDTH,
    int FIFO_ASIZE = 4 // FIFO depth = 2**FIFO_ASIZE pairs
)(
    input logic mclk,  // Assumed to drive converters, e.g some N*fs
    input logic rst_n, // Async, active low

    input logic master_mode,      // Change only while in reset
    input logic[2:0] clk_div_sel, // [2,4,8,16,32,64,128,256]

    input  logic bclk_i, // If S mode
    output logic bclk_o, // If M mode
    input  logic ws_i,   // If S mode
    output logic ws_o,   // If M mode

    // TX samples in (mclk domain, valid/ready)
    input  logic[SAMPLE_WIDTH-1:0] tx_l_word,
    input  logic[SAMPLE_WIDTH-1:0] tx_r_word,
    input  logic                    tx_valid,
    output logic                    tx_ready,
    output logic sd_o, // DOUT

    // RX samples out (mclk domain, valid/ready)
    input  logic sd_i, // DIN
    output logic[SAMPLE_WIDTH-1:0] rx_l_word,
    output logic[SAMPLE_WIDTH-1:0] rx_r_word,
    output logic                    rx_valid,
    input  logic                    rx_ready,

    // Status (mclk domain, sticky until reset)
    output logic tx_underflow,
    output logic rx_overflow
);

localparam int DSIZE = 2*SAMPLE_WIDTH;

logic bclk_clk, tx_clk, ws_line;
logic mclk_rst_n, bclk_rst_n, tx_rst_n;

// ---------------- Clock / WS generation ----------------
i2s_clkgen #(.SLOT_WIDTH(SLOT_WIDTH)) u_clkgen (
    .mclk, .rst_n(mclk_rst_n), .master_mode, .clk_div_sel,
    .bclk_i, .bclk_o, .ws_i, .ws_o,
    .bclk_clk, .ws_line
);

assign tx_clk = ~bclk_clk;

// ---------------- Reset synchronizers ----------------
rst_sync u_rst_mclk (.clk(mclk),     .arst_n(rst_n), .rst_n(mclk_rst_n));
rst_sync u_rst_bclk (.clk(bclk_clk), .arst_n(rst_n), .rst_n(bclk_rst_n));
rst_sync u_rst_tx   (.clk(tx_clk),   .arst_n(rst_n), .rst_n(tx_rst_n));

// ---------------- TX path: mclk -> FIFO -> tx_clk ----------------
logic[DSIZE-1:0] tx_fifo_rdata;
logic tx_fifo_wfull, tx_fifo_rempty, tx_fifo_rinc, tx_underflow_s;

assign tx_ready = !tx_fifo_wfull;

fifo1 #(.DSIZE(DSIZE), .ASIZE(FIFO_ASIZE)) u_tx_fifo (
    .rdata(tx_fifo_rdata), .wfull(tx_fifo_wfull), .rempty(tx_fifo_rempty),
    .wdata({tx_l_word, tx_r_word}), .winc(tx_valid), .wclk(mclk), .wrst_n(mclk_rst_n),
    .rinc(tx_fifo_rinc), .rclk(tx_clk), .rrst_n(tx_rst_n)
);

i2s_transmitter #(.IN_SAMP_WIDTH(SAMPLE_WIDTH), .OUT_SAMP_WIDTH(SLOT_WIDTH)) u_tx (
    .tx_clk, .rst_n(tx_rst_n), .ws(ws_line),
    .fifo_rdata(tx_fifo_rdata), .fifo_rempty(tx_fifo_rempty), .fifo_rinc(tx_fifo_rinc),
    .sd(sd_o), .underflow(tx_underflow_s)
);

// ---------------- RX path: bclk_clk -> FIFO -> mclk ----------------
logic[DSIZE-1:0] rx_fifo_wdata;
logic rx_fifo_winc, rx_fifo_wfull, rx_fifo_rempty, rx_overflow_s;

i2s_receiver #(.SAMPLE_WIDTH(SAMPLE_WIDTH), .SLOT_WIDTH(SLOT_WIDTH)) u_rx (
    .rx_clk(bclk_clk), .rst_n(bclk_rst_n), .ws(ws_line), .sd(sd_i),
    .fifo_wdata(rx_fifo_wdata), .fifo_winc(rx_fifo_winc), .fifo_wfull(rx_fifo_wfull),
    .overflow(rx_overflow_s)
);

fifo1 #(.DSIZE(DSIZE), .ASIZE(FIFO_ASIZE)) u_rx_fifo (
    .rdata({rx_l_word, rx_r_word}), .wfull(rx_fifo_wfull), .rempty(rx_fifo_rempty),
    .wdata(rx_fifo_wdata), .winc(rx_fifo_winc), .wclk(bclk_clk), .wrst_n(bclk_rst_n),
    .rinc(rx_ready), .rclk(mclk), .rrst_n(mclk_rst_n)
);

assign rx_valid = !rx_fifo_rempty;

// ---------------- Status: sticky flags, 2-FF sync into mclk ----------------
logic[1:0] tx_underflow_sync, rx_overflow_sync;
always_ff @(posedge mclk or negedge mclk_rst_n) begin
    if (!mclk_rst_n) begin
        tx_underflow_sync <= '0;
        rx_overflow_sync  <= '0;
    end
    else begin
        tx_underflow_sync <= {tx_underflow_sync[0], tx_underflow_s};
        rx_overflow_sync  <= {rx_overflow_sync[0],  rx_overflow_s};
    end
end
assign tx_underflow = tx_underflow_sync[1];
assign rx_overflow  = rx_overflow_sync[1];
endmodule
