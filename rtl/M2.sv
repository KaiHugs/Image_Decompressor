`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module M2 (
    input logic Clock_50,
    input logic Resetn,
    output logic [17:0] SRAM_address,
    output logic [15:0] SRAM_write_data,
    output logic SRAM_we_n,
    input logic [15:0] SRAM_read_data,
    input logic start,
    output logic done,
    output logic Y_finished_out,
    output logic U_finished_out
);

// INTERNAL DEBUG FLAG
localparam DEBUG_SINGLE_BLOCK = 1'b0;
localparam DISABLE_WRITES = 1'b0;

// State machine
typedef enum logic [3:0] {
    S_IDLE,
    S_LEADIN_M3,
    S_LEADIN_CT,
    S_COMMON_CS_M3,
    S_COMMON_WS_CT,
    S_LEADOUT_CS,
    S_LEADOUT_WS,
    S_DONE
} m2_sm_t;
m2_sm_t M2_S_state;


logic signed [31:0] mult_op1_a, mult_op1_b, mult_op1_c;  // First operands for M0, M1, M2
logic signed [31:0] mult_op2_a, mult_op2_b, mult_op2_c;  // Second operands for M0, M1, M2

logic signed [63:0] mult_result_a, mult_result_b, mult_result_c;

logic signed [31:0] mult_out_a, mult_out_b, mult_out_c;

assign mult_result_a = mult_op1_a * mult_op2_a;
assign mult_result_b = mult_op1_b * mult_op2_b;
assign mult_result_c = mult_op1_c * mult_op2_c;

assign mult_out_a = mult_result_a[31:0];
assign mult_out_b = mult_result_b[31:0];
assign mult_out_c = mult_result_c[31:0];

// ComputeT operands
logic signed [31:0] ct_mult_op1_a, ct_mult_op1_b, ct_mult_op1_c;
logic signed [31:0] ct_mult_op2_a, ct_mult_op2_b, ct_mult_op2_c;

// ComputeS operands
logic signed [31:0] cs_mult_op1_a, cs_mult_op1_b, cs_mult_op1_c;
logic signed [31:0] cs_mult_op2_a, cs_mult_op2_b, cs_mult_op2_c;

always_comb begin
    if (M2_S_state == S_LEADIN_CT || M2_S_state == S_COMMON_WS_CT) begin
        mult_op1_a = ct_mult_op1_a;
        mult_op1_b = ct_mult_op1_b;
        mult_op1_c = ct_mult_op1_c;
        mult_op2_a = ct_mult_op2_a;
        mult_op2_b = ct_mult_op2_b;
        mult_op2_c = ct_mult_op2_c;
    end else if (M2_S_state == S_COMMON_CS_M3 || M2_S_state == S_LEADOUT_CS) begin
        // ComputeS is active
        mult_op1_a = cs_mult_op1_a;
        mult_op1_b = cs_mult_op1_b;
        mult_op1_c = cs_mult_op1_c;
        mult_op2_a = cs_mult_op2_a;
        mult_op2_b = cs_mult_op2_b;
        mult_op2_c = cs_mult_op2_c;
    end else begin
        // Idle state - zero all operands
        mult_op1_a = 32'sd0;
        mult_op1_b = 32'sd0;
        mult_op1_c = 32'sd0;
        mult_op2_a = 32'sd0;
        mult_op2_b = 32'sd0;
        mult_op2_c = 32'sd0;
    end
end

// C dp RAM
logic [7:0] address_a_C, address_b_C;
logic [7:0] address_a_C_local;
logic [7:0] computeT_Address_C_a;
logic [7:0] computeS_Address_C_a, computeS_Address_C_b;
logic [31:0] write_data_a_C, write_data_b_C;
logic write_enable_a_C, write_enable_b_C;
logic [31:0] read_data_a_C, read_data_b_C;

// T dp RAM
logic [7:0] address_a_T, address_b_T;
logic [31:0] write_data_a_T, write_data_b_T;
logic write_enable_a_T, write_enable_b_T;
logic [31:0] read_data_a_T, read_data_b_T;

// ComputeT T RAM interface
logic [7:0] computeT_Address_T_a, computeT_Address_T_b;
logic [31:0] computeT_Write_data_T_a, computeT_Write_data_T_b;
logic computeT_Write_en_T_a, computeT_Write_en_T_b;

// S dp RAM
logic [7:0] address_a_S, address_b_S;
logic [31:0] write_data_a_S, write_data_b_S;
logic write_enable_a_S, write_enable_b_S;
logic [31:0] read_data_a_S, read_data_b_S;

// ComputeT signals
logic compute_T_start, compute_T_finish;
logic [7:0] computeT_Address_Sp_a, computeT_Address_Sp_b;

// M3 signals
logic m3_start, m3_finish;
logic [17:0] m3_SRAM_address;
logic m3_SRAM_we_n;
logic [15:0] m3_SRAM_write_data;

// M3 RAM read interface
logic [7:0] m3_read_address_a, m3_read_address_b;
logic [31:0] m3_read_data_a, m3_read_data_b;

logic Y_finished_W;
logic U_finished_W;

// Export status to top level
assign Y_finished_out = Y_finished_W;
assign U_finished_out = U_finished_W;

// Block mode is INTERNAL
logic block_mode;
assign block_mode = !Y_finished_W;

// reg done signals
logic m3_done_reg;
logic compute_T_done_reg;
logic compute_S_done_reg;
logic write_S_done_reg;

logic leadout_ws_done_waiting_m3;

// ComputeS signals
logic compute_S_start, compute_S_finish;
logic [7:0] computeS_Address_T_a;
logic [7:0] computeS_Address_S_a;
logic computeS_Write_en_S_a;
logic [31:0] computeS_Write_data_S_a;

// WriteS signals
logic write_S_start, write_S_finish;
logic [17:0] writeS_SRAM_address;
logic [15:0] writeS_SRAM_write_data;
logic writeS_SRAM_wen;
logic [7:0] WB_dp_S_address_call_a, WB_dp_S_address_call_b;

logic [4:0] Rblock, Cblock;
logic [4:0] Rblock_WS, Cblock_WS;
logic [4:0] MAX_RBLOCK, MAX_CBLOCK;

// Block limits
always_comb begin
    if (DEBUG_SINGLE_BLOCK) begin
        MAX_RBLOCK = 5'd0;
        MAX_CBLOCK = 5'd0;
    end else if (!Y_finished_W) begin
        MAX_RBLOCK = 5'd8;
        MAX_CBLOCK = 5'd11;
    end else begin
        MAX_RBLOCK = 5'd17;
        MAX_CBLOCK = 5'd11;
    end
end

dual_port_RAMT RAM_instT (
    .address_a ( address_a_T ),
    .address_b ( address_b_T ),
    .clock ( Clock_50 ),
    .data_a ( write_data_a_T),
    .data_b ( write_data_b_T),
    .wren_a ( write_enable_a_T ),
    .wren_b ( write_enable_b_T),
    .q_a ( read_data_a_T ),
    .q_b ( read_data_b_T )
);

dual_port_RAMC RAM_instC (
    .address_a ( address_a_C ),
    .address_b ( address_b_C ),
    .clock ( Clock_50 ),
    .data_a ( write_data_a_C),
    .data_b ( write_data_b_C),
    .wren_a ( write_enable_a_C ),
    .wren_b ( write_enable_b_C),
    .q_a ( read_data_a_C ),
    .q_b ( read_data_b_C )
);

dual_port_RAMW RAM_instS (
    .address_a ( address_a_S ),
    .address_b ( address_b_S ),
    .clock ( Clock_50 ),
    .data_a ( write_data_a_S ),
    .data_b ( write_data_b_S ),
    .wren_a ( write_enable_a_S ),
    .wren_b ( write_enable_b_S ),
    .q_a ( read_data_a_S ),
    .q_b ( read_data_b_S )
);

M3 M3_unit(
    .Clock_50(Clock_50),
    .Resetn(Resetn),
    .start(m3_start),
    .finish(m3_finish),
    .block_mode(block_mode),
    .SRAM_address(m3_SRAM_address),
    .SRAM_read_data(SRAM_read_data),
    .SRAM_we_n(m3_SRAM_we_n),
    .SRAM_write_data(m3_SRAM_write_data),
    .m2_read_address_a(m3_read_address_a),
    .m2_read_address_b(m3_read_address_b),
    .m2_read_data_a(m3_read_data_a),
    .m2_read_data_b(m3_read_data_b)
);

ComputeT ComputeT_unit(
    .Clock_50(Clock_50),
    .Resetn(Resetn),
    .Address_C_a(computeT_Address_C_a),
    .Data_out_C_a(read_data_a_C),
    .Y_finished(Y_finished_W),
    .Address_Sp_a(computeT_Address_Sp_a),
    .Data_out_Sp_a(m3_read_data_a),
    .Address_Sp_b(computeT_Address_Sp_b),
    .Data_out_Sp_b(m3_read_data_b),
    .T_DP_RAM_address_a(computeT_Address_T_a),
    .T_DP_RAM_address_b(computeT_Address_T_b),
    .Write_en_T_a(computeT_Write_en_T_a),
    .Write_en_T_b(computeT_Write_en_T_b),
    .T_DP_RAM_write_data_a(computeT_Write_data_T_a),
    .T_DP_RAM_write_data_b(computeT_Write_data_T_b),
    .start(compute_T_start),    
    .done(compute_T_finish),
    // Shared multiplier interface
    .mult_op1_a(ct_mult_op1_a),
    .mult_op1_b(ct_mult_op1_b),
    .mult_op1_c(ct_mult_op1_c),
    .mult_op2_a(ct_mult_op2_a),
    .mult_op2_b(ct_mult_op2_b),
    .mult_op2_c(ct_mult_op2_c),
    .mult_result_a(mult_out_a),
    .mult_result_b(mult_out_b),
    .mult_result_c(mult_out_c)
); 

ComputeS ComputeS_unit(
    .Clock_50(Clock_50),
    .Resetn(Resetn),
    .Address_C_a(computeS_Address_C_a),
    .Data_out_C_a(read_data_a_C),
    .Address_C_b(computeS_Address_C_b),
    .Data_out_C_b(read_data_b_C),
    .Y_finished(Y_finished_W),
    .Address_T_a(computeS_Address_T_a),
    .Data_out_T_a(read_data_a_T),
    .S_DP_RAM_address_a(computeS_Address_S_a),
    .Write_en_S_a(computeS_Write_en_S_a),
    .S_DP_RAM_write_data_a(computeS_Write_data_S_a),
    .start(compute_S_start),    
    .done(compute_S_finish),
    // Shared multiplier interface
    .mult_op1_a(cs_mult_op1_a),
    .mult_op1_b(cs_mult_op1_b),
    .mult_op1_c(cs_mult_op1_c),
    .mult_op2_a(cs_mult_op2_a),
    .mult_op2_b(cs_mult_op2_b),
    .mult_op2_c(cs_mult_op2_c),
    .mult_result_a(mult_out_a),
    .mult_result_b(mult_out_b),
    .mult_result_c(mult_out_c)
); 

WriteS WS(
    .Clock(Clock_50),
    .Resetn(Resetn),
    .SRAM_address(writeS_SRAM_address),
    .SRAM_write_data(writeS_SRAM_write_data),
    .SRAM_we_n(writeS_SRAM_wen),
    .Rb(Rblock_WS),
    .Cb(Cblock_WS),
    .Address_Sp_a(WB_dp_S_address_call_a),
    .Data_out_Sp_a(read_data_a_S),
    .Address_Sp_b(WB_dp_S_address_call_b),
    .Data_out_Sp_b(read_data_b_S),
    .start(write_S_start),
    .done(write_S_finish),	
    .Y_finished(Y_finished_W),
    .U_finished(U_finished_W)
);

assign m3_read_address_a = computeT_Address_Sp_a;
assign m3_read_address_b = computeT_Address_Sp_b;

always_ff @(posedge Clock_50 or negedge Resetn) begin
    if (!Resetn) begin
        M2_S_state <= S_IDLE;
        m3_start <= 1'b0;
        compute_T_start <= 1'b0;
        compute_S_start <= 1'b0;
        write_S_start <= 1'b0;
        done <= 1'b0;
        Rblock <= 5'd0;
        Cblock <= 5'd0;
        Rblock_WS <= 5'd0;
        Cblock_WS <= 5'd0;
        Y_finished_W <= 1'b0;
        U_finished_W <= 1'b0;
        m3_done_reg <= 1'b0;
        compute_T_done_reg <= 1'b0;
        compute_S_done_reg <= 1'b0;
        write_S_done_reg <= 1'b0;
        leadout_ws_done_waiting_m3 <= 1'b0;
    end else begin
        done <= 1'b0;
        
        if (m3_finish) m3_done_reg <= 1'b1;
        if (compute_T_finish) compute_T_done_reg <= 1'b1;
        if (compute_S_finish) compute_S_done_reg <= 1'b1;
        if (write_S_finish) write_S_done_reg <= 1'b1;
        
        m3_start <= 1'b0;
        compute_T_start <= 1'b0;
        compute_S_start <= 1'b0;
        write_S_start <= 1'b0;

        case (M2_S_state)   
            S_IDLE: begin
                Rblock <= 5'd0;
                Cblock <= 5'd0;
                Rblock_WS <= 5'd0;
                Cblock_WS <= 5'd0;
                Y_finished_W <= 1'b0;
                U_finished_W <= 1'b0;
                if (start) begin
                    M2_S_state <= S_LEADIN_M3;
                    m3_start <= 1'b1;  
                end
            end

            S_LEADIN_M3: begin
                if (m3_finish || m3_done_reg) begin
                    m3_done_reg <= 1'b0;
                    M2_S_state <= S_LEADIN_CT;
                    compute_T_start <= 1'b1;
                end
            end

            S_LEADIN_CT: begin
                if (compute_T_finish || compute_T_done_reg) begin
                    compute_T_done_reg <= 1'b0;
                    if (Rblock == MAX_RBLOCK && Cblock == MAX_CBLOCK) begin
                        M2_S_state <= S_LEADOUT_CS;
                        compute_S_start <= 1'b1;
                    end else begin
                        if (Cblock == MAX_CBLOCK) begin
                            Rblock <= Rblock + 5'd1;
                            Cblock <= 5'd0;
                        end else begin
                            Cblock <= Cblock + 5'd1;
                        end
                        M2_S_state <= S_COMMON_CS_M3;
                        compute_S_start <= 1'b1;
                        m3_start <= 1'b1;
                    end
                end
            end

            S_COMMON_CS_M3: begin
                if ((compute_S_finish || compute_S_done_reg) && (m3_finish || m3_done_reg)) begin
                    compute_S_done_reg <= 1'b0;
                    m3_done_reg <= 1'b0;
                    
                    if (DISABLE_WRITES) begin
                        write_S_done_reg <= 1'b0;
                        if (Cblock_WS == MAX_CBLOCK) begin
                            Rblock_WS <= Rblock_WS + 5'd1;
                            Cblock_WS <= 5'd0;
                        end else begin
                            Cblock_WS <= Cblock_WS + 5'd1;
                        end
                        
                        if (Rblock == MAX_RBLOCK && Cblock == MAX_CBLOCK) begin
                            M2_S_state <= S_DONE;
                        end else begin
                            if (Cblock == MAX_CBLOCK) begin
                                Rblock <= Rblock + 5'd1;
                                Cblock <= 5'd0;
                            end else begin
                                Cblock <= Cblock + 5'd1;
                            end
                            M2_S_state <= S_COMMON_CS_M3;
                            compute_S_start <= 1'b1;
                            m3_start <= 1'b1;
                        end
                    end else begin
                        M2_S_state <= S_COMMON_WS_CT;
                        write_S_start <= 1'b1;
                        compute_T_start <= 1'b1;
                    end
                end
            end

            S_COMMON_WS_CT: begin
                if ((write_S_finish || write_S_done_reg) && (compute_T_finish || compute_T_done_reg)) begin
                    write_S_done_reg <= 1'b0;
                    compute_T_done_reg <= 1'b0;
                    
                    if (Cblock_WS == MAX_CBLOCK) begin
                        Rblock_WS <= Rblock_WS + 5'd1;
                        Cblock_WS <= 5'd0;
                    end else begin
                        Cblock_WS <= Cblock_WS + 5'd1;
                    end
                    
                    if (Rblock == MAX_RBLOCK && Cblock == MAX_CBLOCK) begin
                        M2_S_state <= S_LEADOUT_CS;
                        compute_S_start <= 1'b1;
                    end else begin
                        if (Cblock == MAX_CBLOCK) begin
                            Rblock <= Rblock + 5'd1;
                            Cblock <= 5'd0;
                        end else begin
                            Cblock <= Cblock + 5'd1;
                        end
                        M2_S_state <= S_COMMON_CS_M3;
                        compute_S_start <= 1'b1;
                        m3_start <= 1'b1;
                    end
                end
            end

            S_LEADOUT_CS: begin
                if (compute_S_finish || compute_S_done_reg) begin
                    compute_S_done_reg <= 1'b0;
                    
                    if (DISABLE_WRITES) begin
                        if (Cblock_WS == MAX_CBLOCK) begin
                            Rblock_WS <= Rblock_WS + 5'd1;
                            Cblock_WS <= 5'd0;
                        end else begin
                            Cblock_WS <= Cblock_WS + 5'd1;
                        end
                        
                        if (DEBUG_SINGLE_BLOCK) begin
                            M2_S_state <= S_DONE;
                        end else begin
                            if (!Y_finished_W) begin
                                Rblock <= 5'd0;
                                Cblock <= 5'd0;
                                Rblock_WS <= 5'd0;
                                Cblock_WS <= 5'd0;
                                Y_finished_W <= 1'b1;
                                M2_S_state <= S_LEADIN_M3;
                                m3_start <= 1'b1;
                            end else if (!U_finished_W) begin
                                Rblock <= 5'd0;
                                Cblock <= 5'd0;
                                Rblock_WS <= 5'd0;
                                Cblock_WS <= 5'd0;
                                U_finished_W <= 1'b1;
                                M2_S_state <= S_LEADIN_M3;
                                m3_start <= 1'b1;
                            end else begin
                                M2_S_state <= S_DONE;
                            end
                        end
                    end else begin
                        M2_S_state <= S_LEADOUT_WS;
                        write_S_start <= 1'b1;
                    end
                end
            end

            S_LEADOUT_WS: begin
                if ((write_S_finish || write_S_done_reg) && !leadout_ws_done_waiting_m3) begin
                    write_S_done_reg <= 1'b0;
                    
                    if (Cblock_WS == MAX_CBLOCK) begin
                        Rblock_WS <= Rblock_WS + 5'd1;
                        Cblock_WS <= 5'd0;
                    end else begin
                        Cblock_WS <= Cblock_WS + 5'd1;
                    end
                    
                    if (DEBUG_SINGLE_BLOCK) begin
                        M2_S_state <= S_DONE;
                    end else begin
                        if (!Y_finished_W) begin
                            Rblock <= 5'd0;
                            Cblock <= 5'd0;
                            Rblock_WS <= 5'd0;
                            Cblock_WS <= 5'd0;
                            Y_finished_W <= 1'b1;
                            m3_start <= 1'b1;
                            leadout_ws_done_waiting_m3 <= 1'b1;
                        end else if (!U_finished_W) begin
                            Rblock <= 5'd0;
                            Cblock <= 5'd0;
                            Rblock_WS <= 5'd0;
                            Cblock_WS <= 5'd0;
                            U_finished_W <= 1'b1;
                            m3_start <= 1'b1;
                            leadout_ws_done_waiting_m3 <= 1'b1;
                        end else begin
                            M2_S_state <= S_DONE;
                        end
                    end
                end
                
                if (leadout_ws_done_waiting_m3 && (m3_finish || m3_done_reg)) begin
                    m3_done_reg <= 1'b0;
                    leadout_ws_done_waiting_m3 <= 1'b0;
                    M2_S_state <= S_LEADIN_CT;
                    compute_T_start <= 1'b1;
                end
            end
            
            S_DONE: begin
                done <= 1'b1;
                M2_S_state <= S_IDLE;
            end

            default: M2_S_state <= S_IDLE;
        endcase
    end
end

always_comb begin 
    if (M2_S_state == S_LEADIN_M3 || M2_S_state == S_COMMON_CS_M3) begin 
        SRAM_address = m3_SRAM_address;
        SRAM_write_data = m3_SRAM_write_data;
        SRAM_we_n = 1'b1;
    end else if (M2_S_state == S_LEADOUT_WS && leadout_ws_done_waiting_m3) begin
        SRAM_address = m3_SRAM_address;
        SRAM_write_data = m3_SRAM_write_data;
        SRAM_we_n = 1'b1;
    end else if (!DISABLE_WRITES && (M2_S_state == S_COMMON_WS_CT || M2_S_state == S_LEADOUT_WS)) begin 
        SRAM_address = writeS_SRAM_address;
        SRAM_write_data = writeS_SRAM_write_data;
        SRAM_we_n = writeS_SRAM_wen;
    end else begin
        SRAM_address = 18'd0;
        SRAM_write_data = 16'b0;
        SRAM_we_n = 1'b1;
    end
end

always_comb begin 
    address_a_C_local = 8'd0;
    address_b_C = 8'd0;
    write_data_a_C = 32'd0;
    write_data_b_C = 32'd0;
    write_enable_a_C = 1'b0;
    write_enable_b_C = 1'b0;

    if (M2_S_state == S_LEADIN_CT || M2_S_state == S_COMMON_WS_CT) begin 
        address_a_C_local = computeT_Address_C_a;
    end else if (M2_S_state == S_COMMON_CS_M3 || M2_S_state == S_LEADOUT_CS) begin 
        address_a_C_local = computeS_Address_C_a;
        address_b_C = computeS_Address_C_b;
    end

    address_a_C = address_a_C_local;
end


// T RAM Mapping
always_comb begin 
    if (M2_S_state == S_LEADIN_CT || M2_S_state == S_COMMON_WS_CT) begin 
        // CT writes to T
        address_a_T = computeT_Address_T_a;
        address_b_T = computeT_Address_T_b;
        write_data_a_T = computeT_Write_data_T_a;
        write_data_b_T = computeT_Write_data_T_b;
        write_enable_a_T = computeT_Write_en_T_a;
        write_enable_b_T = computeT_Write_en_T_b;
    end else if (M2_S_state == S_COMMON_CS_M3 || M2_S_state == S_LEADOUT_CS) begin 
        // CS reads from T (port A only)
        address_a_T = computeS_Address_T_a;
        address_b_T = 8'd0;
        write_data_a_T = 32'd0;
        write_data_b_T = 32'd0;
        write_enable_a_T = 1'b0;
        write_enable_b_T = 1'b0;
    end else begin
        address_a_T = 8'd0;
        address_b_T = 8'd0;
        write_data_a_T = 32'd0;
        write_data_b_T = 32'd0;
        write_enable_a_T = 1'b0;
        write_enable_b_T = 1'b0;
    end
end

// S RAM Mapping
always_comb begin 
    if (M2_S_state == S_COMMON_CS_M3 || M2_S_state == S_LEADOUT_CS) begin 
        address_a_S = computeS_Address_S_a;
        address_b_S = 8'd0;
        write_data_a_S = computeS_Write_data_S_a;
        write_data_b_S = 32'd0;
        write_enable_a_S = computeS_Write_en_S_a;
        write_enable_b_S = 1'b0;
    end else if (M2_S_state == S_COMMON_WS_CT || M2_S_state == S_LEADOUT_WS) begin 
        address_a_S = WB_dp_S_address_call_a;
        address_b_S = WB_dp_S_address_call_b;
        write_data_a_S = 32'd0;
        write_data_b_S = 32'd0;
        write_enable_a_S = 1'b0;
        write_enable_b_S = 1'b0;
    end else begin
        address_a_S = 8'd0;
        address_b_S = 8'd0;
        write_data_a_S = 32'd0;
        write_data_b_S = 32'd0;
        write_enable_a_S = 1'b0;
        write_enable_b_S = 1'b0;
    end
end

endmodule
