module i2s_clkgen #(
    int OUT_SAMP_WIDTH // Slot width on the line (bclk periods per word)
)(
    input logic mclk, // Assumed to drive converters, e.g some N*fs
    input logic rst,

    input logic master_mode,
    input logic[2:0] clk_div_sel, // [2,4,8,16,32,64,128,256]; bclk_o = mclk/(2*(bclk_gen_cnt+1)) if master_mode

    input  logic bclk_i, // If S mode
    output logic bclk_o, // If M mode
    input  logic ws_i,   // If S mode
    output logic ws_o,   // If M mode

    // bclk edges as 1-cycle enables, all logic clocked by mclk
    output logic bclk_rise_en, // RX samples sd here
    output logic bclk_fall_en, // TX drives sd here
    output logic ws_at_fall,   // ws before the bclk fall (TX)
    output logic ws_at_rise    // ws at the bclk rise (RX)
);

logic bclk_gen;
logic ws_gen;
logic m_bclk_rise_en;
logic m_bclk_fall_en;
logic s_bclk_rise_en;
logic s_bclk_fall_en;


// S mode: 3FF synchronizers for external bclk/ws to mclk
// [0],[1]: synchronizer; [2]: previous value for edge detect (bclk) / ws before the fall (ws)
logic[2:0] bclk_i_sync;
logic[2:0] ws_i_sync;
always_ff @(posedge mclk) begin
    if(rst) begin
        bclk_i_sync <= '0;
        ws_i_sync   <= '0;
    end
    else begin
        bclk_i_sync <= {bclk_i_sync[1:0], bclk_i};
        ws_i_sync   <= {ws_i_sync[1:0], ws_i};
    end
end
assign s_bclk_rise_en =  bclk_i_sync[1] && !bclk_i_sync[2];
assign s_bclk_fall_en = !bclk_i_sync[1] &&  bclk_i_sync[2];

// Route enables and ws based on M/S mode
assign bclk_rise_en = master_mode ? m_bclk_rise_en : s_bclk_rise_en;
assign bclk_fall_en = master_mode ? m_bclk_fall_en : s_bclk_fall_en;
assign ws_at_fall   = master_mode ? ws_gen : ws_i_sync[2];
assign ws_at_rise   = master_mode ? ws_gen : ws_i_sync[1];

assign bclk_o = master_mode ? bclk_gen : 1'b0;
assign ws_o   = master_mode ? ws_gen   : 1'b0;
// -----------------------------------------------------

// Clock division & bclk/ws generation logic
logic[6:0] clk_div_ctr;
logic[6:0] bclk_gen_cnt; // Half of bclk period in mclk cycles - 1
logic[$clog2(OUT_SAMP_WIDTH)-1:0] ws_ctr;

always_comb begin
    case(clk_div_sel)
        default: bclk_gen_cnt = 7'd0;        // Div = 2
        3'd1:    bclk_gen_cnt = 7'd2  - 1;   // Div = 4
        3'd2:    bclk_gen_cnt = 7'd4  - 1;   // Div = 8
        3'd3:    bclk_gen_cnt = 7'd8  - 1;   // Div = 16
        3'd4:    bclk_gen_cnt = 7'd16  - 1;  // Div = 32
        3'd5:    bclk_gen_cnt = 7'd32 - 1;   // Div = 64
        3'd6:    bclk_gen_cnt = 7'd64 - 1;   // Div = 128
        3'd7:    bclk_gen_cnt = 7'd127;      // Div = 256
    endcase
end

// bclk_gen rises / falls on this mclk edge
assign m_bclk_rise_en = master_mode && (clk_div_ctr == 0) && !bclk_gen;
assign m_bclk_fall_en = master_mode && (clk_div_ctr == 0) && bclk_gen;

// Generate bclk_gen
always_ff @(posedge mclk) begin
    if (rst || !master_mode) begin
        bclk_gen    <= 0;
        clk_div_ctr <= 0;
    end
    else begin
        bclk_gen <= (clk_div_ctr == 0)? ~bclk_gen : bclk_gen;
        clk_div_ctr <= (clk_div_ctr == bclk_gen_cnt)?
                        '0 : clk_div_ctr + 1;
    end
end

// Generate ws_gen
always_ff @(posedge mclk) begin
    if (rst || !master_mode) begin
        ws_gen    <= 0;
        ws_ctr    <= 0;
    end
    else if (m_bclk_fall_en) begin
        ws_gen <= (ws_ctr == OUT_SAMP_WIDTH-1)? ~ws_gen : ws_gen;
        ws_ctr <= (ws_ctr == OUT_SAMP_WIDTH-1)?
                        '0 : ws_ctr + 1;
    end
end
// -----------------------------------------------------
endmodule