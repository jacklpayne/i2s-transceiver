module i2s_transmitter #(
    int SAMPLE_WIDTH, int SLOT_WIDTH
)(
    input logic tx_clk, // inverted BCLK, rising edge = BCLK falling edge where sd changes
    input logic rst_n,  // tx_clk domain, async assert / sync deassert

    input logic ws,     // changes on BCLK falling edge

    // Words arrive from the mclk domain through an async FIFO
    input  logic[2*SAMPLE_WIDTH-1:0]  fifo_rdata, // {l_word, r_word}
    input  logic                      fifo_rempty,
    output logic                      fifo_rinc,

    output logic sd,
    output logic underflow // Sticky: FIFO empty at frame start, zeros sent
);

logic ws_s; // ws sampled on BCLK rise: ws before the next BCLK fall
logic ws_r; // Used to implement 1-cycle delay between ws changing and word actually changing
logic frame_start;

// Sample ws mid-bit (BCLK rise = tx_clk fall)
always_ff @(negedge tx_clk or negedge rst_n) begin
    if (!rst_n) ws_s <= 1'b0;
    else        ws_s <= ws;
end

// ws went low one bclk ago so left word starts now, pop next pair
assign frame_start = (ws_s != ws_r) && !ws_s;
assign fifo_rinc   = frame_start && !fifo_rempty;

// Internal registers for left and right words, loaded from FIFO at start of each frame
logic[SAMPLE_WIDTH-1:0] l_word_r;
logic[SAMPLE_WIDTH-1:0] r_word_r;
logic[SAMPLE_WIDTH-1:0] fifo_l;
logic[SAMPLE_WIDTH-1:0] fifo_r;
logic[$clog2(SLOT_WIDTH):0] bit_idx; // Next bit to output, 0 = MSB

assign {fifo_l, fifo_r} = fifo_rdata;

always_ff @(posedge tx_clk or negedge rst_n) begin // BCLK falling edge: where we assert sd
    if(!rst_n) begin
            l_word_r  <= '0;
            r_word_r  <= '0;
            bit_idx   <= '0;
            ws_r      <= 1'b0; // Wait for a real ws edge (first pair goes into a complete frame)
            sd        <= 1'b0;
            underflow <= 1'b0;
    end
    else begin
        ws_r <= ws_s;
        if (ws_s != ws_r) begin
            // ws has changed, start new word
            bit_idx <= 1;
            if (!ws_s) begin
                if (!fifo_rempty) begin
                    l_word_r <= fifo_l;
                    r_word_r <= fifo_r;
                    sd       <= fifo_l[SAMPLE_WIDTH-1];
                end
                else begin
                    // underflow
                    l_word_r  <= '0;
                    r_word_r  <= '0;
                    sd        <= 1'b0;
                    underflow <= 1'b1;
                end
            end
            else
                sd <= r_word_r[SAMPLE_WIDTH-1];
        end
        else begin
            // Output next bit and zero-pad past input SAMP_WIDTH
            if (bit_idx < SAMPLE_WIDTH) begin
                if(!ws_s)
                    sd <= l_word_r[SAMPLE_WIDTH-1-bit_idx];
                else
                    sd <= r_word_r[SAMPLE_WIDTH-1-bit_idx];
            end
            else
                sd <= 1'b0;
            if (bit_idx < SLOT_WIDTH)
                bit_idx <= bit_idx + 1;
        end
    end
end
endmodule
