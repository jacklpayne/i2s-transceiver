module i2s_transmitter #(
    int IN_SAMP_WIDTH, int OUT_SAMP_WIDTH
)(
    input logic mclk, // Assumed to drive converters, e.g some N*fs
    input logic rst,

    // From i2s_clkgen
    input logic bclk_fall_en, // Where we assert sd
    input logic ws,           // ws_at_fall: ws before this bclk fall

    input logic[IN_SAMP_WIDTH-1:0] l_word, // Captured at start of each frame
    input logic[IN_SAMP_WIDTH-1:0] r_word, // Captured at start of each frame

    output logic sd
);

logic ws_r; // Used to implement 1-cycle delay between ws changing and word actually changing

// Internal registers for left and right word inputs, captured at start of each frame
logic[IN_SAMP_WIDTH-1:0] l_word_r;
logic[IN_SAMP_WIDTH-1:0] r_word_r;
logic[$clog2(OUT_SAMP_WIDTH):0] bit_idx; // Next bit to output, 0 = MSB

always_ff @(posedge mclk) begin
    if(rst) begin
            l_word_r <= '0;
            r_word_r <= '0;
            bit_idx <= '0;
            ws_r  <= 1'b1; // First ws low seen as a change -> first word is left
            sd <= 1'b0;
    end
    else if (bclk_fall_en) begin // Where we assert sd
        ws_r <= ws;
        if (ws != ws_r) begin
            // ws has changed, start new word
            bit_idx <= 1;
            if (!ws) begin
                l_word_r <= l_word;
                r_word_r <= r_word;
                sd <= l_word[IN_SAMP_WIDTH-1];
            end
            else
                sd <= r_word_r[IN_SAMP_WIDTH-1];
        end
        else begin
            // Output next bit and zero-pad past input SAMP_WIDTH
            if (bit_idx < IN_SAMP_WIDTH) begin
                if(!ws)
                    sd <= l_word_r[IN_SAMP_WIDTH-1-bit_idx];
                else
                    sd <= r_word_r[IN_SAMP_WIDTH-1-bit_idx];
            end
            else
                sd <= 1'b0;
            if (bit_idx < OUT_SAMP_WIDTH)
                bit_idx <= bit_idx + 1;
        end
    end
end
endmodule