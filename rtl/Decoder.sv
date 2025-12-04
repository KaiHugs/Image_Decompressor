`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module Decoder (
    input  logic start,
    output logic finish,
    input  logic block_mode,
    
    input  logic clk,
    input  logic reset,
    
    output logic [17:0] SRAM_address,
    input  logic [15:0] SRAM_data_bitstream,
    
    output logic signed [8:0] decoded_coefficient,
    output logic        decoded_valid
);

parameter MIC19_BASE_ADDRESS = 18'h6C00;  // 27648 in decimal
parameter BITSTREAM_OFFSET = 18'd10;
parameter SRAM_HEADER_OFFSET = MIC19_BASE_ADDRESS + BITSTREAM_OFFSET;

parameter RELOAD_THRESHOLD = 6'd45;
parameter LUMA_BLOCK_SIZE = 9'd256;
parameter CHROMA_BLOCK_SIZE = 9'd64;

typedef enum logic [3:0] {
    D_IDLE,
    D_LEAD_IN_WAIT,
    D_PARSE_HEADER,
    D_DECODE_PAYLOAD,
    D_WRITE_SINGLE,
    D_WRITE_ZERO_RUN,
    D_BLOCK_COMPLETE
} decode_state_t;

decode_state_t decode_state;

typedef enum logic [2:0] {
    R_IDLE,
    R_REQUEST,
    R_WAIT_1,
    R_WAIT_2,
    R_CAPTURE
} reload_state_t;

reload_state_t reload_state;

logic [63:0] bitstream_buffer;
logic [6:0]  bits_valid;

logic [63:0] prefetch_shift_reg;
logic [6:0]  prefetch_valid_bits;

logic [17:0] sram_offset;

logic [6:0] bits_transferred; 
logic lead_in_done_pulse;     

logic [6:0]  bits_consumed_this_cycle;
logic [6:0]  bits_added_this_cycle;
logic [3:0]  shift_amount;
logic [63:0] temp_buffer;
logic [5:0]  insert_pos;
logic [6:0] v;
logic [3:0]  bits_to_consume;
logic        bits_consumed_flag;
logic [1:0]  header_prefix;
logic signed [8:0] decoded_coeff_internal;
logic [8:0]  coeff_position;
logic [8:0]  block_size;
logic [8:0]  zeros_to_write;
logic [8:0]  zeros_written;
logic [6:0] bits_removed;  
logic [6:0] bits_added;   
logic [63:0] temp_prefetch;
logic [2:0] lead_in_counter;
logic lead_in_active;
logic [17:0] lead_in_sram_address;

logic [6:0] next_bits_consumed;
logic [6:0] next_bits_added;
logic [3:0] next_shift_amount;
logic [63:0] next_temp_buffer;
logic [5:0] next_insert_pos;
logic [6:0] next_bits_transferred;

assign SRAM_address = lead_in_active ? lead_in_sram_address : (SRAM_HEADER_OFFSET + sram_offset);

assign decoded_valid = (decode_state == D_WRITE_SINGLE || decode_state == D_WRITE_ZERO_RUN);
assign decoded_coefficient = (decode_state == D_WRITE_SINGLE) ? decoded_coeff_internal : 9'd0;

    reload_state_t n_reload_state;
    logic [63:0] n_prefetch_shift;
    logic [6:0]  n_valid_bits;
    logic [17:0] n_sram_offset;

    always_comb begin
            n_reload_state   = reload_state;
            n_prefetch_shift = prefetch_shift_reg;
            n_valid_bits     = prefetch_valid_bits;
            n_sram_offset    = sram_offset;

            bits_removed = 7'd0;
            bits_added   = 7'd0;
            temp_prefetch = prefetch_shift_reg;

            if (bits_transferred == 5'd16 && prefetch_valid_bits >= 5'd16) begin
                temp_prefetch = prefetch_shift_reg << 5'd16;
                bits_removed = 5'd16;
            end

            v = prefetch_valid_bits - bits_removed;


            case (reload_state)
                R_IDLE: if (!lead_in_active && decode_state != D_IDLE && decode_state != D_BLOCK_COMPLETE
                        && (prefetch_valid_bits - bits_removed) < 6'd49)
                        n_reload_state = R_REQUEST;

                R_REQUEST: n_reload_state = R_WAIT_1;
                R_WAIT_1:  n_reload_state = R_WAIT_2;
                R_WAIT_2:  n_reload_state = R_CAPTURE;

                R_CAPTURE: begin
                    if (v <= 48) begin
                        case (v)
                            7'd0:  temp_prefetch[63:48] = SRAM_data_bitstream;
                            7'd16: temp_prefetch[47:32] = SRAM_data_bitstream;
                            7'd32: temp_prefetch[31:16] = SRAM_data_bitstream;
                            7'd48: temp_prefetch[15:0]  = SRAM_data_bitstream;
                            default: v = 7'd0;
                        endcase
                        bits_added = 5'd16;
                        n_sram_offset = sram_offset + 1'b1;
                    end
                    n_reload_state = R_IDLE;
                end
            endcase

            if (bits_removed || bits_added)
                n_valid_bits = prefetch_valid_bits - bits_removed + bits_added;

            if (lead_in_done_pulse)
                n_sram_offset = 18'd4;

            n_prefetch_shift = temp_prefetch;
    end


    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            reload_state <= R_IDLE;
            prefetch_shift_reg <= 64'd0;
            prefetch_valid_bits <= 7'd0;
            sram_offset <= 18'd0;
        end else begin
            reload_state <= n_reload_state;
            prefetch_shift_reg <= n_prefetch_shift;
            prefetch_valid_bits <= n_valid_bits;
            sram_offset <= n_sram_offset;
        end
    end



    
always_comb begin
    next_bits_consumed = 7'd0;
    next_bits_added = 7'd0;
    next_shift_amount = 4'd0;
    next_temp_buffer = bitstream_buffer;
    next_insert_pos = 6'd0;
    next_bits_transferred = 7'd0;
    

    
    case (decode_state)
        D_WRITE_SINGLE: begin
            if (!bits_consumed_flag) begin
                next_bits_consumed = {3'b0, bits_to_consume};
                next_shift_amount = bits_to_consume;
            end
        end
        
        D_WRITE_ZERO_RUN: begin
            if (zeros_written >= (zeros_to_write - 1) && !bits_consumed_flag) begin
                next_bits_consumed = {3'b0, bits_to_consume};
                next_shift_amount = bits_to_consume;
            end
        end
        
        default: begin
            next_bits_consumed = 7'd0;
            next_shift_amount = 4'd0;
        end
    endcase
    

        if ((bits_valid - next_bits_consumed) < RELOAD_THRESHOLD && 
        prefetch_valid_bits >= 7'd16 &&
        (bits_valid - next_bits_consumed + 7'd16) <= 7'd64) begin
        next_bits_added = 7'd16;
    end else begin
        next_bits_added = 7'd0;
    end
    

        if (next_shift_amount != 4'd0 || next_bits_added != 7'd0) begin
        
        //  Shift
        if (next_shift_amount != 4'd0) begin
            next_temp_buffer = bitstream_buffer << next_shift_amount;
        end else begin
            next_temp_buffer = bitstream_buffer;
        end
        

                if (next_bits_added != 7'd0) begin
            logic [6:0] bits_after_shift;
            bits_after_shift = bits_valid - next_bits_consumed;
            
            if (bits_after_shift <= 7'd48) begin
                next_insert_pos = 6'd63 - bits_after_shift[5:0];
                next_temp_buffer[next_insert_pos -: 16] = prefetch_shift_reg[63:48];
                next_bits_transferred = next_bits_added;
            end
        end
    end
end

    
always_ff @(posedge clk or negedge reset) begin
    if (~reset) begin
        decode_state <= D_IDLE;
        finish <= 1'b0;
        bitstream_buffer <= 64'd0;
        bits_valid <= 7'd0;
        bits_to_consume <= 4'd0;
        bits_consumed_flag <= 1'b0;
        decoded_coeff_internal <= 9'd0;
        coeff_position <= 9'd0;
        block_size <= 9'd0;
        zeros_to_write <= 9'd0;
        zeros_written <= 9'd0;
        lead_in_counter <= 3'd0;
        lead_in_active <= 1'b0;
        lead_in_sram_address <= 18'd0;
        bits_transferred <= 7'd0;
        lead_in_done_pulse <= 1'b0;
    end else begin
        bits_transferred <= next_bits_transferred;
        lead_in_done_pulse <= 1'b0;

        case (decode_state)
            D_IDLE: begin
                finish <= 1'b0;
                if (start) begin
                    coeff_position <= 9'd0;
                    bits_consumed_flag <= 1'b0;
                    block_size <= block_mode ? LUMA_BLOCK_SIZE : CHROMA_BLOCK_SIZE;
                    
                    if (bits_valid == 7'd0) begin
                        lead_in_counter <= 3'd0;
                        lead_in_active <= 1'b1;
                        lead_in_sram_address <= SRAM_HEADER_OFFSET;
                        decode_state <= D_LEAD_IN_WAIT;
                    end else begin
                        decode_state <= D_PARSE_HEADER;
                    end
                end
            end
            
            D_LEAD_IN_WAIT: begin
                lead_in_counter <= lead_in_counter + 3'd1;
                
                case (lead_in_counter)
                    3'd0: begin
                        lead_in_sram_address <= SRAM_HEADER_OFFSET + 18'd1;
                    end
                    3'd1: begin
                        lead_in_sram_address <= SRAM_HEADER_OFFSET + 18'd2;
                    end
                    3'd2: begin
                        bitstream_buffer[63:48] <= SRAM_data_bitstream;
                        lead_in_sram_address <= SRAM_HEADER_OFFSET + 18'd3;
                    end
                    3'd3: begin
                        bitstream_buffer[47:32] <= SRAM_data_bitstream;
                    end
                    3'd4: begin
                        bitstream_buffer[31:16] <= SRAM_data_bitstream;
                    end
                    3'd5: begin
                        bitstream_buffer[15:0] <= SRAM_data_bitstream;
                        bits_valid <= 7'd64;
                        lead_in_active <= 1'b0;
                        lead_in_done_pulse <= 1'b1;
                        decode_state <= D_PARSE_HEADER;
                        lead_in_counter <= 3'd0;
                    end
                endcase
            end
            
            D_PARSE_HEADER: begin
                decode_state <= D_DECODE_PAYLOAD;
            end
            
            D_DECODE_PAYLOAD: begin
                bits_consumed_flag <= 1'b0;
                
                case (bitstream_buffer[63:62])
                    2'b00: begin
                        bits_to_consume <= 4'd4;
                        case (bitstream_buffer[61:60])
                            2'b00: zeros_to_write <= 9'd4;
                            2'b01: zeros_to_write <= 9'd1;
                            2'b10: zeros_to_write <= 9'd2;
                            2'b11: zeros_to_write <= 9'd3;
                        endcase
                        zeros_written <= 9'd0;
                        decoded_coeff_internal <= 9'd0;
                        decode_state <= D_WRITE_ZERO_RUN;
                    end
                    
                    2'b01: begin
                        bits_to_consume <= 4'd4;
                        decoded_coeff_internal[8:0] <= {{7{bitstream_buffer[61]}}, bitstream_buffer[61:60]};
                        decode_state <= D_WRITE_SINGLE;
                    end
                    
                    2'b10: begin
                        bits_to_consume <= 4'd11;
                        decoded_coeff_internal[8:0] <= bitstream_buffer[61:53];
                        decode_state <= D_WRITE_SINGLE;
                    end
                    
                    2'b11: begin
                        bits_to_consume <= 4'd2;
                        zeros_to_write <= block_size - coeff_position;
                        zeros_written <= 9'd0;
                        decoded_coeff_internal <= 9'd0;
                        decode_state <= D_WRITE_ZERO_RUN;
                    end
                endcase
            end
            
            D_WRITE_SINGLE: begin
                coeff_position <= coeff_position + 9'd1;
                
                if (!bits_consumed_flag) begin
                    bits_consumed_flag <= 1'b1;
                end
                
                if ((coeff_position + 9'd1) >= block_size) begin
                    decode_state <= D_BLOCK_COMPLETE;
                end else begin
                    decode_state <= D_PARSE_HEADER;
                end
            end
            
            D_WRITE_ZERO_RUN: begin
                coeff_position <= coeff_position + 9'd1;
                zeros_written <= zeros_written + 9'd1;
                
                if (zeros_written >= (zeros_to_write - 1)) begin
                    if (!bits_consumed_flag) begin
                        bits_consumed_flag <= 1'b1;
                    end
                    
                    if ((coeff_position + 9'd1) >= block_size) begin
                        decode_state <= D_BLOCK_COMPLETE;
                    end else begin
                        decode_state <= D_PARSE_HEADER;
                    end
                end
            end
            
            D_BLOCK_COMPLETE: begin
                finish <= 1'b1;
                decode_state <= D_IDLE;
            end
        endcase
        

        // Apply net change to bits_valid
        if (next_bits_consumed != 7'd0 || next_bits_added != 7'd0) begin
            bits_valid <= bits_valid - next_bits_consumed + next_bits_added;
        end
        
        if (next_shift_amount != 4'd0 || next_bits_added != 7'd0) begin
            bitstream_buffer <= next_temp_buffer;
        end
    end
end

endmodule