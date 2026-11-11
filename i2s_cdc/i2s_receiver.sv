module i2s_receiver #(
    int SAMPLE_WIDTH, int SLOT_WIDTH
)(
    input logic rx_clk, // BCLK: rising edge = where we sample sd
    input logic rst_n,  // rx_clk domain, async assert / sync deassert

    input logic ws,     // WS line
    input logic sd,

    // RX FIFO write side (rx_clk domain)
    output logic[2*SAMPLE_WIDTH-1:0]  fifo_wdata, // {l_word, r_word}
    output logic                      fifo_winc,
    input  logic                      fifo_wfull,

    output logic overflow // Sticky: FIFO full when a pair completed, pair dropped
);

logic ws_r;    // ws at previous bclk rise; ws change marks the last bit of a word
logic word_ok; // Set at the first frame start (ws 1 -> 0) after reset: words from then on are whole
               // and every right word follows a captured left word
logic r_done;  // Right word completes on this edge -> {L,R} pair complete

// Word being received; bits placed MSB first, bits past IN_SAMP_WIDTH (padding) dropped
logic[SAMPLE_WIDTH-1:0] word_r;
logic[SAMPLE_WIDTH-1:0] word_nxt;
logic[SAMPLE_WIDTH-1:0] l_hold;
logic[$clog2(SLOT_WIDTH):0] bit_idx;

always_comb begin
    word_nxt = word_r;
    if (bit_idx < SAMPLE_WIDTH)
        word_nxt[SAMPLE_WIDTH-1-bit_idx] = sd;
end

// Pair complete when the right word ends (ws 1 -> 0) after a complete left word
assign r_done     = (ws != ws_r) && ws_r && word_ok;
assign fifo_wdata = {l_hold, word_nxt};
assign fifo_winc  = r_done && !fifo_wfull;

always_ff @(posedge rx_clk or negedge rst_n) begin // Where we sample sd
    if(!rst_n) begin
            word_r   <= '0;
            l_hold   <= '0;
            bit_idx  <= '0;
            ws_r     <= 1'b0;
            word_ok  <= 1'b0;
            overflow <= 1'b0;
    end
    else begin
        ws_r <= ws;
        if (ws != ws_r) begin
            // ws has changed: this bit is the last bit of the previous word, word complete
            if (word_ok && !ws_r)          // left word complete
                l_hold <= word_nxt;
            if (r_done && fifo_wfull)      // pair complete but FIFO full: dropped
                overflow <= 1'b1;
            if (!ws)                       // frame start (ws 1 -> 0)
                word_ok <= 1'b1;
            word_r  <= '0;
            bit_idx <= '0;
        end
        else begin
            word_r <= word_nxt;
            if (bit_idx < SLOT_WIDTH)
                bit_idx <= bit_idx + 1;
        end
    end
end
endmodule