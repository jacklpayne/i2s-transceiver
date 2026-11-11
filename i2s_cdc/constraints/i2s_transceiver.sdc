# -----------------------------------------------------------------------------
# Constraint TEMPLATE for i2s_transceiver (CDC version). Not run through STA.
# Instance/pin names depend on your synthesis netlist; adjust get_pins paths.
# Example rates: fs = 48 kHz, mclk = 256*fs, BCLK = 64*fs.
# -----------------------------------------------------------------------------

# Primary clocks
create_clock -name mclk     -period 81.38  [get_ports mclk]      ;# 12.288 MHz
create_clock -name bclk_ext -period 325.52 [get_ports bclk_i]    ;# 3.072 MHz, slave mode

# Master-mode BCLK: flop output divided from mclk (set -divide_by to match clk_div_sel)
create_generated_clock -name bclk_gen -source [get_ports mclk] -divide_by 4 \
    [get_pins u_clkgen/bclk_gen_reg/Q]

# Clock mux: only one of bclk_gen / bclk_ext reaches the datapath at a time
set_clock_groups -logically_exclusive -group bclk_gen -group bclk_ext

# bclk_gen is derived from mclk -> timed synchronously (ws_gen -> datapath relies on this).
# External BCLK is unrelated to mclk.
set_clock_groups -asynchronous -group {mclk bclk_gen} -group {bclk_ext}

# Gray-pointer crossings: bound skew between pointer bits to < 1 destination period
# (Cummings recommends constraining, not just false-pathing, these paths)
set_max_delay -datapath_only 80 -from [get_pins */wptr_reg*/Q] -to [get_pins */sync_w2r/rq1_wptr_reg*/D]
set_max_delay -datapath_only 80 -from [get_pins */rptr_reg*/Q] -to [get_pins */sync_r2w/wq1_rptr_reg*/D]

# Sticky status flags -> 2-FF synchronizers in mclk
set_false_path -to [get_pins *_sync_reg[0]/D]

# I/O, slave mode: ws_i, sd_i launched by external master on BCLK falling edge
set_input_delay  -clock bclk_ext -clock_fall -max 40 [get_ports {ws_i sd_i}]
set_input_delay  -clock bclk_ext -clock_fall -min 5  [get_ports {ws_i sd_i}]
set_output_delay -clock bclk_ext -max 20 [get_ports sd_o]  ;# receiver setup at BCLK rise
set_output_delay -clock bclk_ext -min -5 [get_ports sd_o]

# I/O, master mode: forward the BCLK pin as a clock for output timing
create_generated_clock -name bclk_pin -source [get_pins u_clkgen/bclk_gen_reg/Q] -divide_by 1 [get_ports bclk_o]
set_output_delay -clock bclk_pin -max 20 [get_ports {sd_o ws_o}]
set_output_delay -clock bclk_pin -min -5 [get_ports {sd_o ws_o}]

# Async reset input: synchronized per domain inside (rst_sync)
set_false_path -from [get_ports rst_n]
