# ===============================
# M2 – Pipeline State Machine
# ===============================
add wave -divider -height 18 "M2 – Pipeline Control"

add wave -dec  UUT/M2_unit/M2_S_state
add wave -bin  UUT/M2_unit/start
add wave -bin  UUT/M2_unit/done

# Block counters
add wave -uns  UUT/M2_unit/Rblock
add wave -uns  UUT/M2_unit/Cblock
add wave -uns  UUT/M2_unit/Rblock_WS
add wave -uns  UUT/M2_unit/Cblock_WS
add wave -uns  UUT/M2_unit/MAX_RBLOCK
add wave -uns  UUT/M2_unit/MAX_CBLOCK

# Pass tracking
add wave -bin  UUT/M2_unit/Y_finished_W
add wave -bin  UUT/M2_unit/U_finished_W

# ===============================
# Module Start/Done Handshakes
# ===============================
add wave -divider -height 15 "Module Handshakes"
add wave -dec  UUT/top_state
# M3
add wave -bin  UUT/M2_unit/m3_start
add wave -bin  UUT/M2_unit/m3_finish
add wave -bin  UUT/M2_unit/m3_done_reg

# ComputeT
add wave -bin  UUT/M2_unit/compute_T_start
add wave -bin  UUT/M2_unit/compute_T_finish
add wave -bin  UUT/M2_unit/compute_T_done_reg

# ComputeS
add wave -bin  UUT/M2_unit/compute_S_start
add wave -bin  UUT/M2_unit/compute_S_finish
add wave -bin  UUT/M2_unit/compute_S_done_reg

# WriteS
add wave -bin  UUT/M2_unit/write_S_start
add wave -bin  UUT/M2_unit/write_S_finish
add wave -bin  UUT/M2_unit/write_S_done_reg

# ===============================
# M3 Ping-Pong Buffering
# ===============================
add wave -divider -height 15 "M3 Ping-Pong Buffer"

add wave -bin  UUT/M2_unit/M3_unit/write_toggle
add wave -hex  UUT/M2_unit/M3_unit/m2_read_address_a
add wave -hex  UUT/M2_unit/M3_unit/m2_read_address_b
add wave -hex  UUT/M2_unit/M3_unit/m2_read_data_a
add wave -hex  UUT/M2_unit/M3_unit/m2_read_data_b

# RAM write enables (to see which buffer is active)
add wave -bin  UUT/M2_unit/M3_unit/write_enable_a_Sp
add wave -bin  UUT/M2_unit/M3_unit/write_enable_a_X

# ===============================
# ComputeT Activity
# ===============================
add wave -divider -height 15 "ComputeT"

add wave -hex  UUT/M2_unit/ComputeT_unit/Address_Sp_a
add wave -hex  UUT/M2_unit/ComputeT_unit/Address_Sp_b
add wave -hex  UUT/M2_unit/ComputeT_unit/Data_out_Sp_a
add wave -hex  UUT/M2_unit/ComputeT_unit/Data_out_Sp_b
add wave -hex  UUT/M2_unit/ComputeT_unit/T_DP_RAM_address_a
add wave -hex  UUT/M2_unit/ComputeT_unit/T_DP_RAM_address_b
add wave -bin  UUT/M2_unit/ComputeT_unit/Write_en_T_a
add wave -bin  UUT/M2_unit/ComputeT_unit/Write_en_T_b

# ===============================
# ComputeS Activity
# ===============================
add wave -divider -height 15 "ComputeS"

add wave -hex  UUT/M2_unit/ComputeS_unit/Address_T_a
add wave -hex  UUT/M2_unit/ComputeS_unit/Data_out_T_a
add wave -hex  UUT/M2_unit/ComputeS_unit/S_DP_RAM_address_a
add wave -bin  UUT/M2_unit/ComputeS_unit/Write_en_S_a
add wave -hex  UUT/M2_unit/ComputeS_unit/S_DP_RAM_write_data_a

# ===============================
# WriteS Activity
# ===============================
add wave -divider -height 15 "WriteS"

add wave -hex  UUT/M2_unit/WS/SRAM_address
add wave -hex  UUT/M2_unit/WS/SRAM_write_data
add wave -bin  UUT/M2_unit/WS/SRAM_we_n
add wave -hex  UUT/M2_unit/WS/Address_Sp_a
add wave -hex  UUT/M2_unit/WS/Address_Sp_b

# ===============================
# RAM Multiplexing
# ===============================
add wave -divider -height 15 "RAM Mux Control"

# C RAM
add wave -hex  UUT/M2_unit/address_a_C
add wave -hex  UUT/M2_unit/address_b_C
add wave -bin  UUT/M2_unit/write_enable_a_C

# T RAM
add wave -hex  UUT/M2_unit/address_a_T
add wave -hex  UUT/M2_unit/address_b_T
add wave -bin  UUT/M2_unit/write_enable_a_T
add wave -bin  UUT/M2_unit/write_enable_b_T

# S RAM
add wave -hex  UUT/M2_unit/address_a_S
add wave -hex  UUT/M2_unit/address_b_S
add wave -bin  UUT/M2_unit/write_enable_a_S

# ===============================
# Decoder-Prefetch Communication
# ===============================
add wave -divider -height 15 "Decoder-Prefetch Sync"

add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/bits_transferred
add wave -bin  UUT/M2_unit/M3_unit/decoder_inst/lead_in_done_pulse

# Coefficient output stream
add wave -dec  UUT/M2_unit/M3_unit/decoder_inst/decoded_coefficient
add wave -bin  UUT/M2_unit/M3_unit/decoder_inst/decoded_valid
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/coeff_position

# ===============================
# DECODER – Buffer Mechanics
# ===============================
add wave -divider -height 15 "Buffer Consumption & Refill"

# Main buffer consumption
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/bits_valid
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/bits_to_consume
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/bits_consumed_this_cycle
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/shift_amount

# Prefetch refill
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/prefetch_valid_bits
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/bits_added_this_cycle
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/bits_transferred


# ===============================
# DECODER – Prefetch FSM Detail
# ===============================
add wave -divider -height 15 "Prefetch Reload FSM"

add wave -ascii UUT/M2_unit/M3_unit/decoder_inst/reload_state
add wave -hex  UUT/M2_unit/M3_unit/decoder_inst/prefetch_shift_reg
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/prefetch_valid_bits
add wave -hex  UUT/M2_unit/M3_unit/decoder_inst/sram_offset

# SRAM reads for prefetch
add wave -hex  UUT/M2_unit/M3_unit/decoder_inst/SRAM_address
add wave -hex  UUT/SRAM_read_data
add wave -bin  UUT/M2_unit/M3_unit/decoder_inst/lead_in_active

# ===============================
# DECODER – Symbol Type Breakdown
# ===============================
add wave -divider -height 15 "Symbol Type Analysis"

add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/zeros_to_write
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/zeros_written
add wave -dec  UUT/M2_unit/M3_unit/decoder_inst/decoded_coeff_internal

# Track block boundaries
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/coeff_position
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/block_size

# ===============================
# DECODER – Timing Critical Paths
# ===============================

# ===============================
# DECODER – Lead-in Sequence
# ===============================
add wave -divider -height 15 "Lead-in Initial Load"

add wave -bin  UUT/M2_unit/M3_unit/decoder_inst/lead_in_active
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/lead_in_counter
add wave -hex  UUT/M2_unit/M3_unit/decoder_inst/lead_in_sram_address
add wave -bin  UUT/M2_unit/M3_unit/decoder_inst/lead_in_done_pulse



# ===============================
# DECODER – Coefficient Output Stream
# ===============================
add wave -divider -height 15 "Coefficient Output Stream"

# Create a counter that increments on each valid output
add wave -uns  UUT/M2_unit/M3_unit/decoder_inst/coeff_position
add wave -bin  UUT/M2_unit/M3_unit/decoder_inst/decoded_valid
add wave -dec  UUT/M2_unit/M3_unit/decoder_inst/decoded_coefficient


add wave -hex  UUT/M2_unit/m3_SRAM_address
add wave -hex  UUT/M2_unit/writeS_SRAM_address
add wave -hex  UUT/M2_unit/SRAM_address
add wave -bin  UUT/M2_unit/SRAM_we_n