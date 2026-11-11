// asynchronous assert, synchronous deassert
// in slave mode BCLK may not be running while reset is applied, so the BCLK domain must still enter reset immediately.
module rst_sync (
    input  logic clk,
    input  logic arst_n,   // asynchronous, active low
    output logic rst_n     // asserts immediately, deasserts on 2nd clk edge
);
logic rff1;
always_ff @(posedge clk or negedge arst_n)
    if (!arst_n) {rst_n, rff1} <= 2'b00;
    else         {rst_n, rff1} <= {rff1, 1'b1};
endmodule
