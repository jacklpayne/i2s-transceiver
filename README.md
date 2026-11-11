# I2S transceiver

This is a design for an I2S transmitter and receiver for an audio codec. The main version is in i2s_cdc, which uses asynchronous FIFOS to cross parallel samples between the oversampled mclk domain and the sample-rate bclk domain. The early "non-cdc" version implemented bclk as an enable synchronized to mclk, which effectively crossed clock domains at the serial side and requires mclk to be a higher multiple of bclk to accomplish the edge detection.


## I2S_CDC Overview
| File | Contents |
|---|---|
| fifo1, fifomem, sync_r2w, sync_w2r, rptr_empty, wptr_full | Cummings async FIFO, one module per file as in the paper |
| rst_sync.sv | Reset synchronizer, async assert / sync deassert |
| clk_mux.sv | Behavioral clock mux; replace with library glitch-free cell |
| i2s_clkgen.sv | Master BCLK/WS generation on mclk; selects datapath clock |
| i2s_transmitter.sv | TX on BCLK falling edge (tx_clk = ~BCLK), pops one pair per frame |
| i2s_receiver.sv | RX on BCLK rising edge, pushes one pair per frame |
| i2s_transceiver.sv | Top: clkgen, 2 FIFOs, TX, RX, reset and status syncs |
| tb_fifo1.sv | FIFO unit test: unrelated clocks, random traffic, Gray 1-bit check |
| tb_transceiver.sv | Two transceivers, independent mclks, 8 configs, both directions |
| i2s_transceiver.sdc | Constraint template (not STA-verified) |

## Run testbenches (Xcelium)
    xrun -sv -timescale 1ns/1ps -f files.f tb_fifo1.sv
    xrun -sv -timescale 1ns/1ps -f files.f tb_transceiver.sv +NPAIRS=5000
