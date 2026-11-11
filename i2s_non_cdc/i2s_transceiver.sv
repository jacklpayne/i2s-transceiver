// One clock/ws generator shared by TX and RX on the same bclk/ws pins (typical codec port)
module i2s_transceiver #(
    int IN_SAMP_WIDTH, int OUT_SAMP_WIDTH
)(
    input logic mclk, // Assumed to drive converters, e.g some N*fs
    input logic rst,

    input logic master_mode,
    input logic[2:0] clk_div_sel, // [2,4,8,16,32,64,128,256]

    input  logic bclk_i, // If S mode
    output logic bclk_o, // If M mode
    input  logic ws_i,   // If S mode
    output logic ws_o,   // If M mode

    input  logic[IN_SAMP_WIDTH-1:0] tx_l_word,
    input  logic[IN_SAMP_WIDTH-1:0] tx_r_word,
    output logic sd_o, // DOUT

    input  logic sd_i, // DIN
    output logic[IN_SAMP_WIDTH-1:0] rx_l_word,
    output logic[IN_SAMP_WIDTH-1:0] rx_r_word
);

logic bclk_rise_en, bclk_fall_en, ws_at_fall, ws_at_rise;

i2s_clkgen #(.OUT_SAMP_WIDTH(OUT_SAMP_WIDTH)) u_clkgen (
    .mclk, .rst, .master_mode, .clk_div_sel,
    .bclk_i, .bclk_o, .ws_i, .ws_o,
    .bclk_rise_en, .bclk_fall_en, .ws_at_fall, .ws_at_rise
);

i2s_transmitter #(.IN_SAMP_WIDTH(IN_SAMP_WIDTH), .OUT_SAMP_WIDTH(OUT_SAMP_WIDTH)) u_tx (
    .mclk, .rst, .bclk_fall_en, .ws(ws_at_fall),
    .l_word(tx_l_word), .r_word(tx_r_word), .sd(sd_o)
);

i2s_receiver #(.IN_SAMP_WIDTH(IN_SAMP_WIDTH), .OUT_SAMP_WIDTH(OUT_SAMP_WIDTH)) u_rx (
    .mclk, .rst, .master_mode, .bclk_rise_en, .ws(ws_at_rise),
    .sd(sd_i), .l_word(rx_l_word), .r_word(rx_r_word)
);
endmodule