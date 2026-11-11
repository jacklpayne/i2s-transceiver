// Clock multiplexer. Behavioral model ONLY.
// Silicon: replace with the library's glitch-free clock mux cell (e.g. CKMUX2)
// and mark it dont_touch. Select may change only while the BCLK domain is in reset.
module clk_mux (
    input  logic clk0,  // sel = 0
    input  logic clk1,  // sel = 1
    input  logic sel,
    output logic clk
);
assign clk = sel ? clk1 : clk0;
endmodule
