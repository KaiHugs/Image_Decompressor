`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module WriteS (
    input  logic Clock,
    input  logic Resetn,
    input  logic start,
    input  logic Y_finished,      
    input  logic U_finished,       

    output logic SRAM_we_n,
    output logic [17:0] SRAM_address,
    output logic [15:0] SRAM_write_data,

    output logic [7:0] Address_Sp_a,
    input logic [31:0] Data_out_Sp_a,
    output logic [7:0] Address_Sp_b,
    input logic [31:0] Data_out_Sp_b,

    input logic [4:0] Rb, Cb,
    output logic done
);

typedef enum logic [3:0] {
    S_IDLE_WRITE,
    S_LEADIN0_WRITE,
    S_LEADIN1_WRITE,
    S_COMMON0_WRITE,
    S_COMMON1_WRITE,
    S_COMMON2_WRITE,
    S_LEADOUT0_WRITE,
    S_LEADOUT1_WRITE,
    S_END_WRITE
} WRITE_state;

WRITE_state WRITE;

logic [17:0] BASE;

always_comb begin
    if (!Y_finished) begin
        BASE = 18'd0; // Y base
    end else if(!U_finished) begin
        BASE = 18'd13824; //. U Base
    end else begin
        BASE = 18'd20736; 
    end
end

logic end_of_block;
logic [17:0] IDCT_address; 
logic [11:0] RA, CA;
logic [3:0]  ri;
logic [2:0]  ci;
logic [7:0]  col_pair;

logic [31:0] A_data;
logic [31:0] B_data;

always_comb begin
    if (!Y_finished) begin    
        RA = {Rb, ri};
        CA = {Cb, ci};
        IDCT_address = BASE + ({RA, 6'd0}) + ({RA, 5'd0}) + CA;
        end_of_block = (ri == 4'd15 && ci == 4'd7);
    end else begin
        RA = {Rb, ri[2:0]};
        CA = {Cb, ci[1:0]};
        IDCT_address = BASE + ({RA, 5'd0}) + ({RA, 4'd0}) + CA;
        end_of_block = (ri == 4'd7 && ci == 4'd3);
    end 
end

always_ff @(posedge Clock or negedge Resetn) begin
    if (~Resetn) begin
        WRITE <= S_IDLE_WRITE;
        done <= 1'b0;
        Address_Sp_a <= 8'd0;
        Address_Sp_b <= 8'd0;
        SRAM_address <= 18'd0;
        SRAM_write_data <= 16'd0;
        SRAM_we_n <= 1'b1;
        A_data <= 32'd0;
        B_data <= 32'd0;
        ri <= 4'd0;
        ci <= 3'd0;
        col_pair <= 8'd0;
    end else begin
        case (WRITE)

        S_IDLE_WRITE: begin 
            done <= 1'b0;
            Address_Sp_a <= 8'd0;
            Address_Sp_b <= 8'd0;
            SRAM_address <= 18'd0;
            SRAM_write_data <= 16'd0;
            SRAM_we_n <= 1'b1;
            A_data <= 32'd0;
            B_data <= 32'd0;
            ri <= 4'd0;
            ci <= 3'd0;
            col_pair <= 8'd0;
            
            if (start) begin
                if(!Y_finished) begin
                    Address_Sp_a <= 8'd0;
                    Address_Sp_b <= 8'd6;
                end else begin
                    Address_Sp_a <= 8'd0;
                    Address_Sp_b <= 8'd3;
                end
                SRAM_we_n <= 1'b1; 
                done <= 1'b0;
                WRITE <= S_LEADIN0_WRITE;
            end
        end

        S_LEADIN0_WRITE: begin  
            WRITE <= S_LEADIN1_WRITE;
        end

        S_LEADIN1_WRITE: begin  
            SRAM_address <= IDCT_address;
            A_data <= Data_out_Sp_a; // Capture column 0 data
            B_data <= Data_out_Sp_b; // Capture column 1 data
            WRITE <= S_COMMON0_WRITE;
        end

        S_COMMON0_WRITE: begin  
            SRAM_address <= IDCT_address; 
            SRAM_write_data <= {A_data[7:0], B_data[7:0]}; 
            SRAM_we_n <= 1'b0;

            if (!Y_finished) begin
                // 16x16 mode
                if(ri != 4'd15) begin
                    ri <= ri + 4'd1;    
                    Address_Sp_a <= Address_Sp_a + 8'd1;
                    Address_Sp_b <= Address_Sp_b + 8'd1;
                end else begin
                    Address_Sp_a <= Address_Sp_a + 8'd7;
                    Address_Sp_b <= Address_Sp_b + 8'd7;
                end
            end else begin
                // 8x8 mode
                ri <= ri + 4'd1;
                if(ri == 4'd6) begin
                    Address_Sp_a <= Address_Sp_a + 8'd4;
                    Address_Sp_b <= Address_Sp_b + 8'd4;
                end else begin
                    Address_Sp_a <= Address_Sp_a + 8'd1;
                    Address_Sp_b <= Address_Sp_b + 8'd1;
                end
            end
            WRITE <= S_COMMON1_WRITE;
        end

        S_COMMON1_WRITE: begin 
            if (!Y_finished) begin
                // 16x16 mode
                if(ri == 4'd15) begin
                    SRAM_we_n <= 1'b1;
                end else begin
                    SRAM_address <= IDCT_address; 
                    SRAM_write_data <= {A_data[15:8], B_data[15:8]};
                    ri <= ri + 4'd1;    
                end
            end else begin
                // 8x8 mode
                SRAM_address <= IDCT_address; 
                SRAM_write_data <= {A_data[15:8], B_data[15:8]};
                
                if(ri != 4'd7) begin
                    ri <= ri + 4'd1;    
                end
                // If ri==7, leave it at 7 
            end
            WRITE <= S_COMMON2_WRITE;
       end

        S_COMMON2_WRITE: begin 
            if (!Y_finished) begin
                // 16x16 mode
                SRAM_address <= IDCT_address;
                SRAM_write_data <= {A_data[23:16], B_data[23:16]};
                
                A_data <= Data_out_Sp_a; // Capture new data
                B_data <= Data_out_Sp_b;
                
                if (ri == 4'd15) begin
                    ri <= 4'd0;
                    ci <= ci + 3'd1;
                    col_pair <= col_pair + 8'd1;
                end else begin
                    ri <= ri + 4'd1;
                end
            end else begin
                if (ri == 4'd7) begin
                    // Skip third write for last row group
                    SRAM_we_n <= 1'b1;
                    
                    // Capture new data 
                    A_data <= Data_out_Sp_a;
                    B_data <= Data_out_Sp_b;
                    
                    ri <= 4'd0;
                    ci <= ci + 3'd1;
                end else begin
                    SRAM_address <= IDCT_address;
                    SRAM_write_data <= {A_data[23:16], B_data[23:16]};
                    
                    A_data <= Data_out_Sp_a;
                    B_data <= Data_out_Sp_b;
                    
                    ri <= ri + 4'd1;
                end
            end

            if (end_of_block) begin
                WRITE <= S_LEADOUT0_WRITE;
            end else begin
                WRITE <= S_COMMON0_WRITE;
            end
        end

        S_LEADOUT0_WRITE: begin
            SRAM_we_n <= 1'b1;
            WRITE <= S_LEADOUT1_WRITE;
        end
 
        S_LEADOUT1_WRITE: begin
            done <= 1'b1;
            ri <= 4'd0;
            ci <= 3'd0;
            col_pair <= 8'd0;
            WRITE <= S_END_WRITE;
        end

        S_END_WRITE: begin 
            done <= 1'b0;
            WRITE <= S_IDLE_WRITE;
        end

        endcase
    end 
end
endmodule