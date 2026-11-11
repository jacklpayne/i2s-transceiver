module i2s_receiver #(
    int IN_SAMP_WIDTH, int OUT_SAMP_WIDTH // Same meaning as TX: sample width, slot width on the line
)(
    input logic mclk, // Assumed to drive converters, e.g some N*fs
    input logic rst,

    input logic master_mode, // Selects raw sd (M mode) or synchronized sd (S mode)

    // From i2s_clkgen
    input logic bclk_rise_en, // Where we sample sd
    input logic ws,           // ws_at_rise: ws at this bclk rise

    input logic sd,
    output logic[IN_SAMP_WIDTH-1:0] l_word,
    output logic[IN_SAMP_WIDTH-1:0] r_word
);

logic ws_r;    // ws at previous bclk rise; ws change marks the last bit of a word
logic word_ok; // Current word started at a ws edge (first word after reset is partial, discarded)

// S mode: 2FF synchronizer for external sd; [1] sampled on same mclk edge as detected bclk rise
logic[1:0] sd_i_sync;
logic sd_in;
always_ff @(posedge mclk) begin
    if(rst)
        sd_i_sync <= '0;
    else
        sd_i_sync <= {sd_i_sync[0], sd};
end
assign sd_in = master_mode ? sd : sd_i_sync[1];
// -----------------------------------------------------

// Word being received; bits placed MSB first, bits past IN_SAMP_WIDTH (padding) dropped
logic[IN_SAMP_WIDTH-1:0] word_r;
logic[IN_SAMP_WIDTH-1:0] word_nxt;
logic[$clog2(OUT_SAMP_WIDTH):0] bit_idx;

always_comb begin
    word_nxt = word_r;
    if (bit_idx < IN_SAMP_WIDTH)
        word_nxt[IN_SAMP_WIDTH-1-bit_idx] = sd_in;
end

always_ff @(posedge mclk) begin
    if(rst) begin
            word_r  <= '0;
            l_word  <= '0;
            r_word  <= '0;
            bit_idx <= '0;
            ws_r    <= 1'b0;
            word_ok <= 1'b0;
    end
    else if (bclk_rise_en) begin // Where we sample sd
        ws_r <= ws;
        if (ws != ws_r) begin
            // ws has changed: this bit is the last bit of the previous word, word complete
            if (word_ok) begin
                if (!ws_r)
                    l_word <= word_nxt;
                else
                    r_word <= word_nxt;
            end
            word_ok <= 1'b1;
            word_r  <= '0;
            bit_idx <= '0;
        end
        else begin
            word_r <= word_nxt;
            if (bit_idx < OUT_SAMP_WIDTH)
                bit_idx <= bit_idx + 1;
        end
    end
end
endmodule