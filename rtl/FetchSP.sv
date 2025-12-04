`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif
 
module FetchSP (
    input  logic Clock,
    input  logic Resetn,
    input  logic [15:0] SRAM_read_data,
    input  logic start,
    input  logic Y_finished, 
    input  logic U_finished,            
 
    input logic [4:0] Rb, Cb,
    output logic DP_RAM_we,
    output logic [17:0] SRAM_address,
    output logic [7:0]  DP_RAM_address,
    output logic [31:0] DP_RAM_write_data,
    output logic done
);
 
typedef enum logic [3:0] {
    S_IDLE_FETCH_SP,
    S_LEADIN0_FETCH_SP,
    S_LEADIN1_FETCH_SP,
    S_COMMON_FETCH_SP_READ,  
    S_COMMON_FETCH_SP_READ_WRITE,  
    S_LEADOUT0_FETCH_SP,
    S_LEADOUT1_FETCH_SP,  
    S_LEADOUT2_FETCH_SP,
    S_LEADOUT3_FETCH_SP,
    S_LEADOUT4_FETCH_SP,
    S_LEADOUT5_FETCH_SP,
    S_END_FETCH_SP
} Fetch_Sp_state;
 
Fetch_Sp_state fetch_sp;
 
logic [17:0] BASE;
 
always_comb begin
    if (!Y_finished) begin
        BASE = 18'd27648;
    end else if (!U_finished)begin
        BASE = 18'd55296;
    end else begin
        BASE = 18'd69120;
    end
end

logic end_of_block, first_cycle;
logic [18:0] DCT_address;
logic [11:0] RA, CA;
logic [3:0]  ci, ri;
logic [15:0] Se;
 
always_comb begin
    if (!Y_finished) begin
        // 16x16 mode
        RA = {Rb, ri};
        CA = {Cb, ci};
        DCT_address = BASE + ({RA, 7'd0}) + ({RA, 6'd0}) + CA;
        end_of_block = (ri == 4'hF && ci == 4'hF);
    end else begin
        // 8x8 mode
        RA = {Rb, ri[2:0]};
        CA = {Cb, ci[2:0]};
        DCT_address = BASE + ({RA, 6'd0}) + ({RA, 5'd0}) + CA;
        end_of_block = (ri == 4'h7 && ci == 4'h7);
    end
end
 
 
always_ff @(posedge Clock or negedge Resetn) begin
    if (~Resetn) begin
        fetch_sp <= S_IDLE_FETCH_SP;
        ri <= 4'd0;
        ci <= 4'd0;
        done <= 1'b0;
        DP_RAM_address <= 8'd0;
        DP_RAM_write_data <= 32'd0;
        DP_RAM_we <= 1'b0;
        SRAM_address <= 18'd0;
        first_cycle <= 1'b0;
        Se <= 16'd0;
    end else begin
        case (fetch_sp)
 
        S_IDLE_FETCH_SP: begin
            if (start) begin
                ri <= 4'd0;
                ci <= 4'd0;
                DP_RAM_address <= 8'd0;
                DP_RAM_write_data <= 32'd0;
                DP_RAM_we <= 1'b0;
                Se <= 16'd0;
                first_cycle <= 1'b1;
                done <= 1'b0;
                
                SRAM_address <= DCT_address;  // Request S0
                fetch_sp <= S_LEADIN0_FETCH_SP;
                ri <= 4'd1;
            end
        end
 
        S_LEADIN0_FETCH_SP: begin
            SRAM_address <= DCT_address;  // Request S1
            fetch_sp <= S_LEADIN1_FETCH_SP;
            ri <= ri + 4'd1;
        end
 
        S_LEADIN1_FETCH_SP: begin
            SRAM_address <= DCT_address;  // Request S2
            fetch_sp <= S_COMMON_FETCH_SP_READ;
            ri <= ri + 4'd1;
        end
 
        S_COMMON_FETCH_SP_READ: begin
            Se <= SRAM_read_data;  // Read Se (even rows)
            SRAM_address <= DCT_address;  
            DP_RAM_we <= 1'b0;
 
            if (end_of_block) begin
                fetch_sp <= S_LEADOUT0_FETCH_SP;
            end else begin
                fetch_sp <= S_COMMON_FETCH_SP_READ_WRITE;
                
                // Increment ri/ci based on mode
                if (!Y_finished) begin
                    if (ri == 4'd15) begin
                        ri <= 4'd0;
                        ci <= ci + 4'd1;
                    end else begin
                        ri <= ri + 4'd1;
                    end
                end else begin
                    if (ri == 4'd7) begin
                        ri <= 4'd0;
                        ci <= ci + 4'd1;
                    end else begin
                        ri <= ri + 4'd1;
                    end
                end
            end
        end
   
        S_COMMON_FETCH_SP_READ_WRITE: begin
            DP_RAM_we <= 1'b1;
            DP_RAM_write_data <= {Se, SRAM_read_data};  // Pack Se and So
            
            Se <= SRAM_read_data;
            SRAM_address <= DCT_address;
            
            if (!first_cycle) begin
                DP_RAM_address <= DP_RAM_address + 8'd1;
            end else begin
                first_cycle <= 1'b0;
            end
            
            // Increment ri based on mode
            if (!Y_finished) begin
                ri <= ri + 4'd1;
            end else begin
                if (ri == 4'd7) begin
                    ri <= 4'd0;
                end else begin
                    ri <= ri + 4'd1;
                end
            end
            
            fetch_sp <= S_COMMON_FETCH_SP_READ;
        end
 
        S_LEADOUT0_FETCH_SP: begin
            DP_RAM_we <= 1'b1;
            DP_RAM_write_data <= {Se, SRAM_read_data};
            
            SRAM_address <= DCT_address;  
            DP_RAM_address <= DP_RAM_address + 8'd1;

            fetch_sp <= S_LEADOUT1_FETCH_SP;
        end
 
        S_LEADOUT1_FETCH_SP: begin
            Se <= SRAM_read_data; 
            DP_RAM_we <= 1'b0;
            fetch_sp <= S_LEADOUT2_FETCH_SP;
        end
   
        S_LEADOUT2_FETCH_SP: begin
            DP_RAM_we <= 1'b1;
            DP_RAM_write_data <= {Se, SRAM_read_data};
            DP_RAM_address <= DP_RAM_address + 8'd1;
            fetch_sp <= S_LEADOUT3_FETCH_SP;
        end

        S_LEADOUT3_FETCH_SP: begin
            Se <= SRAM_read_data;
            DP_RAM_we <= 1'b0;
            done <= 1'b1;
            fetch_sp <= S_END_FETCH_SP;
        end


        S_END_FETCH_SP: begin
            DP_RAM_we <= 1'b0;
            done <= 1'b0;
            fetch_sp <= S_IDLE_FETCH_SP;
            ri <= 4'd0;
            ci <= 4'd0;
            DP_RAM_address <= 8'd0;
            first_cycle <= 1'b0;
            Se <= 16'd0;
        end
 
        endcase
    end
end
endmodule