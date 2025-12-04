`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif
 
module FetchSPX (
    input  logic Clock,
    input  logic Resetn,
    input  logic [15:0] SRAM_read_data,
    input  logic start,
    input  logic Y_finished,
    input  logic U_finished,
    
    output logic SRAM_we_n,
    output logic [17:0] SRAM_address,
    output logic [15:0] SRAM_write_data,

    output logic [7:0] Address_Sp_a,
    input  logic [31:0] Data_out_Sp_a,
    output logic [7:0] Address_Sp_b,
    input  logic [31:0] Data_out_Sp_b,
    
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
    S_END_FETCH_SP
} Fetch_Sp_state;
 
Fetch_Sp_state fetch_sp;

// Block row and column counters
logic [7:0] Rb, Cb;  // Need these declared
 
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
        Address_Sp_a <= 8'd0;
        Address_Sp_b <= 8'd0;
        SRAM_address <= 18'd0;
        SRAM_write_data <= 16'd0;
        SRAM_we_n <= 1'b1;
        first_cycle <= 1'b0;
        Se <= 16'd0;
        Rb <= 8'd0;
        Cb <= 8'd0;
    end else begin
        case (fetch_sp)
 
        S_IDLE_FETCH_SP: begin
            if (start) begin
                ri <= 4'd0;
                ci <= 4'd0;
                Address_Sp_a <= 8'd0;
                Address_Sp_b <= 8'd0;
                Se <= 16'd0;
                first_cycle <= 1'b1;
                done <= 1'b0;
                SRAM_we_n <= 1'b1;
                
                SRAM_address <= DCT_address;  // Request write location
                fetch_sp <= S_LEADIN0_FETCH_SP;
                ri <= 4'd1;
            end
        end
 
        S_LEADIN0_FETCH_SP: begin
            // Read from RAM_instSP port A (even data)
            Address_Sp_a <= Address_Sp_a + 8'd1;
            fetch_sp <= S_LEADIN1_FETCH_SP;
            ri <= ri + 4'd1;
        end
 
        S_LEADIN1_FETCH_SP: begin
            // Capture first even value
            Se <= Data_out_Sp_a[31:16];  // Upper 16 bits
            Address_Sp_a <= Address_Sp_a + 8'd1;
            fetch_sp <= S_COMMON_FETCH_SP_READ;
            ri <= ri + 4'd1;
        end
 
        S_COMMON_FETCH_SP_READ: begin
            // Write Se to SRAM (even rows)
            SRAM_address <= DCT_address;
            SRAM_write_data <= Se;
            SRAM_we_n <= 1'b0;  // Enable write
 
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
            // Write So to SRAM (odd rows)
            SRAM_address <= DCT_address;
            SRAM_write_data <= Data_out_Sp_a[15:0];  // Lower 16 bits (odd)
            SRAM_we_n <= 1'b0;
            
            // Prepare next Se
            Se <= Data_out_Sp_a[31:16];
            Address_Sp_a <= Address_Sp_a + 8'd1;
            
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
            // Write final Se
            SRAM_address <= DCT_address;
            SRAM_write_data <= Se;
            SRAM_we_n <= 1'b0;
            fetch_sp <= S_LEADOUT1_FETCH_SP;
        end
 
        S_LEADOUT1_FETCH_SP: begin
            // Write final So
            SRAM_address <= DCT_address;
            SRAM_write_data <= Data_out_Sp_a[15:0];
            SRAM_we_n <= 1'b0;
            fetch_sp <= S_LEADOUT2_FETCH_SP;
        end
   
        S_LEADOUT2_FETCH_SP: begin
            SRAM_we_n <= 1'b1;
            done <= 1'b1;
            fetch_sp <= S_LEADOUT3_FETCH_SP;
        end

        S_LEADOUT3_FETCH_SP: begin
            done <= 1'b0;
            fetch_sp <= S_END_FETCH_SP;
        end

        S_END_FETCH_SP: begin
            SRAM_we_n <= 1'b1;
            fetch_sp <= S_IDLE_FETCH_SP;
            ri <= 4'd0;
            ci <= 4'd0;
            Address_Sp_a <= 8'd0;
            first_cycle <= 1'b0;
            Se <= 16'd0;
        end
 
        endcase
    end
end
endmodule