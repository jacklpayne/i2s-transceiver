module wptr_full #(parameter ADDRSIZE = 4)
  (output logic                wfull,
   output logic [ADDRSIZE-1:0] waddr,
   output logic [ADDRSIZE  :0] wptr,
   input  logic [ADDRSIZE  :0] wq2_rptr,
   input  logic                winc, wclk, wrst_n);

  logic [ADDRSIZE:0] wbin;
  logic [ADDRSIZE:0] wgraynext, wbinnext;
  logic              wfull_val;

  // GRAYSTYLE2 pointer
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) {wbin, wptr} <= '0;
    else         {wbin, wptr} <= {wbinnext, wgraynext};

  // Memory write-address pointer (okay to use binary to address memory)
  assign waddr = wbin[ADDRSIZE-1:0];

  assign wbinnext  = wbin + (winc & ~wfull);
  assign wgraynext = (wbinnext>>1) ^ wbinnext;

  assign wfull_val = (wgraynext=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1],
                                   wq2_rptr[ADDRSIZE-2:0]});

  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) wfull <= 1'b0;
    else         wfull <= wfull_val;
endmodule
