module fifomem #(parameter DATASIZE = 8, // Memory data word width
                 parameter ADDRSIZE = 4) // Number of mem address bits
  (output logic [DATASIZE-1:0] rdata,
   input  logic [DATASIZE-1:0] wdata,
   input  logic [ADDRSIZE-1:0] waddr, raddr,
   input  logic                wclken, wfull, wclk);

  // RTL Verilog memory model
  localparam DEPTH = 1<<ADDRSIZE;
  logic [DATASIZE-1:0] mem [0:DEPTH-1];

  assign rdata = mem[raddr];

  always_ff @(posedge wclk)
    if (wclken && !wfull) mem[waddr] <= wdata;
endmodule
