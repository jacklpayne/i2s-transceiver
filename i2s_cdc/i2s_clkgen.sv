module i2s_clkgen #(
    int SLOT_WIDTH // bclk periods per word
)(
    input logic mclk, // Assumed to drive converters, e.g some N*fs
    input logic rst_n, // mclk domain, async assert / sync deassert

    input logic master_mode,      // Change only while in reset
    input logic[2:0] clk_div_sel, // [2,4,8,16,32,64,128,256]; bclk_o = mclk/(2*(bclk_gen_cnt+1)) if master_mode

    input  logic bclk_i, // If S mode
    output logic bclk_o, // If M mode
    input  logic ws_i,   // If S mode
    output logic ws_o,   // If M mode

    output logic bclk_clk, // Datapath clock: bclk_gen (M) or bclk_i (S)
    output logic ws_line   // WS seen by datapath, changes on BCLK falling edge
);

logic bclk_gen;
logic ws_gen;
logic m_bclk_fall_en;

// Datapath clock: glitch-free clock mux
clk_mux u_bclk_mux (.clk0(bclk_i), .clk1(bclk_gen), .sel(master_mode), .clk(bclk_clk));

// ws_gen is a flop on mclk that changes on the same edge bclk_gen falls:
// synchronous to bclk_gen (generated clock), no synchronizer needed.
assign ws_line = master_mode ? ws_gen : ws_i;

assign bclk_o = master_mode ? bclk_gen : 1'b0;
assign ws_o   = master_mode ? ws_gen   : 1'b0;
// -----------------------------------------------------

// Clock division & bclk/ws generation logic
logic[6:0] clk_div_ctr;
logic[6:0] bclk_gen_cnt; // Half of bclk period in mclk cycles - 1
logic[$clog2(SLOT_WIDTH)-1:0] ws_ctr;

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

// bclk_gen falls on this mclk edge
assign m_bclk_fall_en = master_mode && (clk_div_ctr == 0) && bclk_gen;

// Generate bclk_gen
always_ff @(posedge mclk or negedge rst_n) begin
    if (!rst_n) begin
        bclk_gen    <= 0;
        clk_div_ctr <= 0;
    end
    else if (master_mode) begin
        bclk_gen <= (clk_div_ctr == 0)? ~bclk_gen : bclk_gen;
        clk_div_ctr <= (clk_div_ctr == bclk_gen_cnt)?
                        '0 : clk_div_ctr + 1;
    end
end

// Generate ws_gen
always_ff @(posedge mclk or negedge rst_n) begin
    if (!rst_n) begin
        ws_gen    <= 0;
        ws_ctr    <= 0;
    end
    else if (m_bclk_fall_en) begin
        ws_gen <= (ws_ctr == SLOT_WIDTH-1)? ~ws_gen : ws_gen;
        ws_ctr <= (ws_ctr == SLOT_WIDTH-1)?
                        '0 : ws_ctr + 1;
    end
end
// -----------------------------------------------------
endmodule
