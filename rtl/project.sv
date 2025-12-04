/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

module project (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_N_I,         // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O,             // VGA blue
		
		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[19:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask 
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask 
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable
		
		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
);
	
logic resetn;

top_state_type top_state;

logic [3:0] PB_pushed;

logic VGA_enable;
logic [17:0] VGA_base_address;
logic [17:0] VGA_SRAM_address;

logic [17:0] SRAM_address;
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

logic UART_rx_enable;
logic UART_rx_initialize;
logic [17:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

logic [6:0] value_7_segment [7:0];

logic Frame_error;

assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

logic M1_start;
logic M1_done;
logic [17:0]M1_SRAM_address;
logic M1_SRAM_we_n;
logic [15:0]M1_SRAM_write_data;

// M2 contains M3 as a submodule - no separate M3 signals at top level
logic M2_start;
logic M2_done;
logic [17:0]M2_SRAM_address;
logic M2_SRAM_we_n;
logic [15:0]M2_SRAM_write_data;

logic M2_Y_finished;
logic M2_U_finished;

PB_controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_N_I),	
	.PB_pushed(PB_pushed)
);

M1 M1_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.SRAM_address(M1_SRAM_address),
	.SRAM_write_data(M1_SRAM_write_data),
	.SRAM_we_n(M1_SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.start(M1_start),
	.done(M1_done)
);

M2 M2_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.SRAM_address(M2_SRAM_address),
	.SRAM_read_data(SRAM_read_data),
	.SRAM_write_data(M2_SRAM_write_data),
	.SRAM_we_n(M2_SRAM_we_n),
	.start(M2_start),
	.done(M2_done),
	.Y_finished_out(M2_Y_finished),
	.U_finished_out(M2_U_finished)
);

VGA_SRAM_interface VGA_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.VGA_enable(VGA_enable),
   
	.SRAM_base_address(VGA_base_address),
	.SRAM_address(VGA_SRAM_address),
	.SRAM_read_data(SRAM_read_data),
   
	.VGA_CLOCK_O(VGA_CLOCK_O),
	.VGA_HSYNC_O(VGA_HSYNC_O),
	.VGA_VSYNC_O(VGA_VSYNC_O),
	.VGA_BLANK_O(VGA_BLANK_O),
	.VGA_SYNC_O(VGA_SYNC_O),
	.VGA_RED_O(VGA_RED_O),
	.VGA_GREEN_O(VGA_GREEN_O),
	.VGA_BLUE_O(VGA_BLUE_O)
);

UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
   
	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),
   
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

SRAM_controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.SRAM_ready(SRAM_ready),
		
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O[17:0]),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);

assign SRAM_ADDRESS_O[19:18] = 2'b00;

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		
		M1_start <= 1'b0;
		M2_start <= 1'b0;
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		
		VGA_enable <= 1'b1;
	end else begin

		UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			VGA_enable <= 1'b1;  
			if (~UART_RX_I) begin
				UART_rx_initialize <= 1'b1;
				UART_timer <= 26'd0;
				VGA_enable <= 1'b0;
				top_state <= S_UART_RX;
			end
			M1_start <= 1'b0;
			M2_start <= 1'b0;
		end

		S_UART_RX: begin
			UART_rx_initialize <= 1'b0;
			UART_rx_enable <= 1'b0;
			if (UART_rx_initialize == 1'b1) 
				UART_rx_enable <= 1'b1;

			if (~UART_SRAM_we_n) 
				UART_timer <= 26'd0;

			// After UART completes, start M2 (which contains M3)
			// M2 internally manages block_mode based on Y_finished/U_finished
			if (UART_timer == 26'd49999999) begin
				top_state <= S_M2;
				M2_start <= 1'b1;
				UART_timer <= 26'd0;
			end
		end

		S_M1: begin
			M1_start <= 1'b0;
			if(M1_done) begin
				top_state <= S_IDLE;
			end
		end


		S_M2: begin
			M2_start <= 1'b0;
			if(M2_done) begin
				M1_start <= 1'b1;
				top_state <= S_M1;
			end
		end

		default: top_state <= S_IDLE;

		endcase
	end
end

assign VGA_base_address = 18'd220672;

always_comb begin 
	if (top_state == S_UART_RX) begin 
		SRAM_address = UART_SRAM_address;
		SRAM_write_data = UART_SRAM_write_data;
		SRAM_we_n = UART_SRAM_we_n;
	end
	else if (top_state == S_M1) begin 
		SRAM_address = M1_SRAM_address;
		SRAM_write_data = M1_SRAM_write_data;
		SRAM_we_n = M1_SRAM_we_n;
	end 
	else if (top_state == S_M2) begin 
		SRAM_address = M2_SRAM_address;
		SRAM_write_data = M2_SRAM_write_data;
		SRAM_we_n = M2_SRAM_we_n;
	end 
	else begin 
		SRAM_address = VGA_SRAM_address;
		SRAM_write_data = 16'b0;	
		SRAM_we_n = 1'b1;
	end
end

convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]), 
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]), 
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]), 
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value({2'b00, SRAM_address[17:16]}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[0])
);

assign   
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, VGA_enable, ~SRAM_we_n, Frame_error, UART_rx_initialize, PB_pushed};

endmodule