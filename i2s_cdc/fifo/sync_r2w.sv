module sync_r2w #(parameter ADDRSIZE = 4)
  (output logic [ADDRSIZE:0] wq2_rptr,
   input  logic [ADDRSIZE:0] rptr,
   input  logic              wclk, wrst_n);

  logic [ADDRSIZE:0] wq1_rptr;

  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) {wq2_rptr,wq1_rptr} <= '0;
    else         {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};
endmodule
