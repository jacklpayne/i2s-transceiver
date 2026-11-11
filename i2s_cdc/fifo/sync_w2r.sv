module sync_w2r #(parameter ADDRSIZE = 4)
  (output logic [ADDRSIZE:0] rq2_wptr,
   input  logic [ADDRSIZE:0] wptr,
   input  logic              rclk, rrst_n);

  logic [ADDRSIZE:0] rq1_wptr;

  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) {rq2_wptr,rq1_wptr} <= '0;
    else         {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
endmodule
