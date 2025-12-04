`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module M3 (
    input logic Clock_50,
    input logic Resetn,
    
    output logic [17:0] SRAM_address,
    input logic [15:0] SRAM_read_data,
    output logic SRAM_we_n,
    output logic [15:0] SRAM_write_data,
    
    input logic start,
    output logic finish,
    input logic block_mode,
    
    input logic [7:0] m2_read_address_a,
    input logic [7:0] m2_read_address_b,
    output logic [31:0] m2_read_data_a,
    output logic [31:0] m2_read_data_b
);

localparam DEBUG_MODE = 1'b0; 

localparam MIC19_BASE_ADDRESS = 18'h6C00;

typedef enum logic [2:0] {
    S_IDLE,
    S_READ_HEADER,
    S_WAIT_HEADER_1,
    S_WAIT_HEADER_2,
    S_DECODE,
    S_DONE
} M3_state;

M3_state m3_state;

logic decoder_start;
logic decoder_finish;
logic signed [8:0] decoded_coefficient;
logic decoded_valid;
logic [17:0] decoder_sram_address;

logic Q_number;
logic [17:0] m3_sram_address;
logic header_read; 

logic [17:0] selected_sram_address;
logic selected_sram_we_n;
logic [15:0] selected_sram_write_data;

always_comb begin
    if (m3_state == S_READ_HEADER || m3_state == S_WAIT_HEADER_1 || m3_state == S_WAIT_HEADER_2) begin
        selected_sram_address = m3_sram_address;
        selected_sram_we_n = 1'b1;
        selected_sram_write_data = 16'd0;
    end else begin
        selected_sram_address = decoder_sram_address;
        selected_sram_we_n = 1'b1;
        selected_sram_write_data = 16'd0;
    end
end

assign SRAM_address = selected_sram_address;
assign SRAM_we_n = selected_sram_we_n;
assign SRAM_write_data = selected_sram_write_data;

Decoder decoder_inst (
    .clk(Clock_50),
    .reset(Resetn),
    .start(decoder_start),
    .finish(decoder_finish),
    .block_mode(block_mode), 
    
    .SRAM_address(decoder_sram_address),
    .SRAM_data_bitstream(SRAM_read_data),
    
    .decoded_coefficient(decoded_coefficient),
    .decoded_valid(decoded_valid)
);

// Internal RAMs
logic [7:0] address_a_Sp, address_b_Sp;
logic [31:0] write_data_a_Sp, write_data_b_Sp;
logic write_enable_a_Sp, write_enable_b_Sp;
logic [3:0] byteena_a_Sp, byteena_b_Sp;
logic [31:0] read_data_a_Sp, read_data_b_Sp;

logic [7:0] address_a_X, address_b_X;
logic [31:0] write_data_a_X, write_data_b_X;
logic write_enable_a_X, write_enable_b_X;
logic [3:0] byteena_a_X, byteena_b_X;
logic [31:0] read_data_a_X, read_data_b_X;

dual_port_RAMSP RAM_instSP (
    .address_a ( address_a_Sp ),
    .address_b ( address_b_Sp ),
    .clock ( Clock_50 ),
    .data_a ( write_data_a_Sp),
    .data_b ( write_data_b_Sp),
    .wren_a ( write_enable_a_Sp ),
    .wren_b ( write_enable_b_Sp ),
    .byteena_a ( byteena_a_Sp ),
    .byteena_b ( byteena_b_Sp ),
    .q_a ( read_data_a_Sp ),
    .q_b ( read_data_b_Sp )
);

dual_port_RAMX RAM_instX (
    .address_a ( address_a_X ),
    .address_b ( address_b_X ),
    .clock ( Clock_50 ),
    .data_a ( write_data_a_X),
    .data_b ( write_data_b_X),
    .wren_a ( write_enable_a_X ),
    .wren_b ( write_enable_b_X ),
    .byteena_a ( byteena_a_X ),
    .byteena_b ( byteena_b_X ),
    .q_a ( read_data_a_X ),
    .q_b ( read_data_b_X)
);

logic write_toggle;

// Integrated ZZ counter - current position
logic zz_dir;
logic [3:0] zz_ri, zz_ci;
logic [3:0] zz_max;

logic [3:0] zz_ri_next, zz_ci_next;
logic zz_dir_next;

// Max value based on mode
always_comb begin
    if (block_mode == 1'b1) begin
        zz_max = 4'd15;
    end else begin
        zz_max = 4'd7;
    end
end

// Combinational logic for next ZZ position
always_comb begin
    zz_ri_next = zz_ri;
    zz_ci_next = zz_ci;
    zz_dir_next = zz_dir;  // Keep current direction by default
    
    if (decoded_valid && m3_state == S_DECODE) begin
        // 16x16 mode (RIGHT-FIRST zig-zag)
        if (block_mode == 1'b1) begin  
            if (zz_dir == 1'b0) begin  // Moving UP-RIGHT
                if (zz_ri == 4'd0 && zz_ci != zz_max) begin
                    zz_ci_next = zz_ci + 4'd1;
                    zz_dir_next = 1'b1;  // Change to DOWN-LEFT
                end else if (zz_ci == zz_max) begin
                    zz_ri_next = zz_ri + 4'd1;
                    zz_dir_next = 1'b1;  // Change to DOWN-LEFT
                end else begin
                    zz_ri_next = zz_ri - 4'd1;
                    zz_ci_next = zz_ci + 4'd1;
                    // zz_dir_next stays 1'b0 (keep going UP-RIGHT)
                end
            end else begin  // Moving DOWN-LEFT (zz_dir == 1)
                if (zz_ci == 4'd0 && zz_ri != zz_max) begin
                    zz_ri_next = zz_ri + 4'd1;
                    zz_dir_next = 1'b0;  // Change to UP-RIGHT
                end else if (zz_ri == zz_max) begin
                    zz_ci_next = zz_ci + 4'd1;
                    zz_dir_next = 1'b0;  // Change to UP-RIGHT
                end else begin
                    zz_ri_next = zz_ri + 4'd1;
                    zz_ci_next = zz_ci - 4'd1;
                    // zz_dir_next stays 1'b1 (keep going DOWN-LEFT)
                end
            end
        // 8x8 mode (DOWN-FIRST zag-zig)
        end else begin  
            if (zz_dir == 1'b0) begin  // Moving DOWN-LEFT
                if (zz_ci == 4'd0 && zz_ri != zz_max) begin
                    zz_ri_next = zz_ri + 4'd1;
                    zz_dir_next = 1'b1;  // Change to UP-RIGHT
                end else if (zz_ri == zz_max) begin
                    zz_ci_next = zz_ci + 4'd1;
                    zz_dir_next = 1'b1;  // Change to UP-RIGHT
                end else begin
                    zz_ri_next = zz_ri + 4'd1;
                    zz_ci_next = zz_ci - 4'd1;
                    // zz_dir_next stays 1'b0 (keep going DOWN-LEFT)
                end
            end else begin  // Moving UP-RIGHT (zz_dir == 1)
                if (zz_ri == 4'd0 && zz_ci != zz_max) begin
                    zz_ci_next = zz_ci + 4'd1;
                    zz_dir_next = 1'b0;  // Change to DOWN-LEFT
                end else if (zz_ci == zz_max) begin
                    zz_ri_next = zz_ri + 4'd1;
                    zz_dir_next = 1'b0;  // Change to DOWN-LEFT
                end else begin
                    zz_ri_next = zz_ri - 4'd1;
                    zz_ci_next = zz_ci + 4'd1;
                    // zz_dir_next stays 1'b1 (keep going UP-RIGHT)
                end
            end
        end
    end
end

logic [3:0] shift_factor;
logic [3:0] row_index, col_index;
logic [4:0] position;
logic signed [31:0] quantized_value;
logic signed [31:0] final_value;

logic [7:0] row_major_address;
logic position_in_word;

always_comb begin
    row_index = zz_ri;
    col_index = zz_ci;
    position = {1'b0, row_index} + {1'b0, col_index};
end


always_comb begin
    if (block_mode == 1'b0) begin  
        // Address = row/2 + col * 4
        row_major_address = {4'b0, row_index[2:1]} + {col_index[2:0], 2'b0};
        position_in_word = row_index[0];  
		  end else begin  // 16x16
        // Address = row/2 + col * 8
        row_major_address = {4'b0, row_index[3:1]} + {col_index, 3'b0};
        position_in_word = row_index[0];  // Even/odd row
    end
end

always_comb begin 
    if (Q_number == 1'b0) begin
        if (block_mode) begin
            if (position <= 5'd18) begin
                shift_factor = 3'd4;
            end else begin
                shift_factor = 3'd5;
            end
        end else begin
            if (position <= 5'd6) begin
                shift_factor = 3'd3;
            end else if (position <= 5'd10) begin
                shift_factor = 3'd4;
            end else begin
                shift_factor = 3'd5;
            end
        end
    end else begin
        if (block_mode) begin
            if (position <= 5'd5) begin
                shift_factor = 3'd4;
            end else if (position <= 5'd20) begin
                shift_factor = 3'd5;
            end else begin
                shift_factor = 3'd6;
            end
        end else begin
            if (position <= 5'd3) begin
                shift_factor = 3'd3;
            end else if (position <= 5'd6) begin
                shift_factor = 3'd4;
            end else if (position <= 5'd11) begin
                shift_factor = 3'd5;
            end else begin
                shift_factor = 3'd6;
            end
        end
    end
    
    quantized_value = {{23{decoded_coefficient[8]}}, decoded_coefficient} <<< shift_factor;
    

    final_value = quantized_value;

end


always_comb begin
    address_b_Sp = m2_read_address_b;
    address_b_X = m2_read_address_b;
    write_data_b_Sp = 32'd0;
    write_data_b_X = 32'd0;
    write_enable_b_Sp = 1'b0;
    write_enable_b_X = 1'b0;
    byteena_b_Sp = 4'b1111;
    byteena_b_X = 4'b1111;
    
    if (m3_state == S_DECODE && decoded_valid) begin
        address_a_Sp = row_major_address;
        address_a_X = row_major_address;
        
        if (position_in_word == 1'b0) begin
            // Even row - write to UPPER half 
            write_data_a_Sp = {final_value[15:0], 16'h0};
            write_data_a_X = {final_value[15:0], 16'h0};
            byteena_a_Sp = 4'b1100;
            byteena_a_X = 4'b1100;
        end else begin
            write_data_a_Sp = {16'h0, final_value[15:0]};
            write_data_a_X = {16'h0, final_value[15:0]};
            byteena_a_Sp = 4'b0011;
            byteena_a_X = 4'b0011;
        end
        
        write_enable_a_Sp = !write_toggle;
        write_enable_a_X = write_toggle;
        
    end else begin
        address_a_Sp = m2_read_address_a;
        address_a_X = m2_read_address_a;
        write_data_a_Sp = 32'd0;
        write_data_a_X = 32'd0;
        write_enable_a_Sp = 1'b0;
        write_enable_a_X = 1'b0;
        byteena_a_Sp = 4'b1111;
        byteena_a_X = 4'b1111;
    end
end

assign m2_read_data_a = write_toggle ? read_data_a_Sp : read_data_a_X;
assign m2_read_data_b = write_toggle ? read_data_b_Sp : read_data_b_X;

always_ff @(posedge Clock_50 or negedge Resetn) begin
    if (~Resetn) begin
        m3_state <= S_IDLE;
        finish <= 1'b0;
        decoder_start <= 1'b0;
        write_toggle <= 1'b0;
        Q_number <= 1'b0;
        m3_sram_address <= 18'd0;
        header_read <= 1'b0; 
        

        zz_ri <= 4'd0;
        zz_ci <= 4'd0;
        zz_dir <= 1'b0;
        
    end else begin
        
        case (m3_state)
            S_IDLE: begin
                finish <= 1'b0;
                decoder_start <= 1'b0;
                
                zz_ri <= 4'd0;
                zz_ci <= 4'd0;
                zz_dir <= 1'b0;
                
                if (start) begin
                    if (!header_read) begin
                        m3_sram_address <= MIC19_BASE_ADDRESS + 18'd1;
                        m3_state <= S_READ_HEADER;
                    end else begin
                        decoder_start <= 1'b1;
                        m3_state <= S_DECODE;
                    end
                end
            end
            
            S_READ_HEADER: begin
                m3_state <= S_WAIT_HEADER_1;
            end
            
            S_WAIT_HEADER_1: begin
                m3_state <= S_WAIT_HEADER_2;
            end
            
            S_WAIT_HEADER_2: begin
                Q_number <= SRAM_read_data[0];
                header_read <= 1'b1; 
                decoder_start <= 1'b1;
                m3_state <= S_DECODE;
            end
            
            S_DECODE: begin
                decoder_start <= 1'b0;
                
                if (decoded_valid) begin
                    zz_ri <= zz_ri_next;
                    zz_ci <= zz_ci_next;
                    zz_dir <= zz_dir_next;
                end
                
                if (decoder_finish) begin
                    write_toggle <= ~write_toggle;
                    m3_state <= S_DONE;
                end
            end
            
            S_DONE: begin
                finish <= 1'b1;
                m3_state <= S_IDLE;
            end
            
        endcase
    end
end

endmodule
