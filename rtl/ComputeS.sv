`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module ComputeS (
  input  logic Clock_50,
  input  logic Resetn,
  
  // C dpram 
  output logic [7:0] Address_C_a,
  input  logic [31:0] Data_out_C_a,
  output logic [7:0] Address_C_b,
  input  logic [31:0] Data_out_C_b,
  input Y_finished,

  // T dpram
  output logic [7:0] Address_T_a,
  input  logic [31:0] Data_out_T_a,

  // S dpram
  output logic [7:0] S_DP_RAM_address_a,
  output logic Write_en_S_a,
  output logic [31:0] S_DP_RAM_write_data_a,

  input  logic start,
  output logic done,
  
  // Shared multiplier interface - outputs (operands to M2)
  output logic signed [31:0] mult_op1_a,
  output logic signed [31:0] mult_op1_b,
  output logic signed [31:0] mult_op1_c,
  output logic signed [31:0] mult_op2_a,
  output logic signed [31:0] mult_op2_b,
  output logic signed [31:0] mult_op2_c,
  
  // Shared multiplier interface - inputs (results from M2)
  input logic signed [31:0] mult_result_a,
  input logic signed [31:0] mult_result_b,
  input logic signed [31:0] mult_result_c
);


  logic [4:0] Addressing_counter;  
  logic [3:0] column_counter;    
  logic [2:0] row_set_counter;    
  logic first_cycle;
  
 
  logic [3:0] i;
  logic [7:0] C_Address_a, C_Address_b, T_Address;
  logic [4:0] max_counter;
  logic [2:0] max_row_set;
  
  logic signed [31:0] Acc_S0, Acc_S1, Acc_S2;
  logic signed [31:0] Adj_S0, Adj_S1, Adj_S2;
  logic [7:0] S0_clipped, S1_clipped, S2_clipped;

  typedef enum logic [4:0] { 
    S_IDLE, 
    S_LEAD_IN,
    S_CC0, S_CC1, S_CC2, S_CC3, S_CC4, S_CC5, S_CC6, S_CC7,
    S_CC8, S_CC9, S_CC10, S_CC11, S_CC12, S_CC13, S_CC14, S_CC15,
    S_WRITE,
    S_END 
  } state_t;
  
  state_t state;
  
  logic [31:0] div_S0, div_S1, div_S2;  
  always_comb begin
    div_S0 = (Acc_S0 + 32'sd4096) >>> 13; 
    div_S1 = (Acc_S1 + 32'sd4096) >>> 13;
    div_S2 = (Acc_S2 + 32'sd4096) >>> 13;
    
    Adj_S0 = div_S0;
    Adj_S1 = div_S1;
    Adj_S2 = div_S2;
  end
  
  // Clipping logic for 8-bit unsigned output
  always_comb begin
    // S0 clipping
    if (Adj_S0[31]) begin
      S0_clipped = 8'd0;
    end else if (Adj_S0 > 32'd255) begin
      S0_clipped = 8'd255;
    end else begin
      S0_clipped = Adj_S0[7:0];
    end
    
    // S1 clipping
    if (Adj_S1[31]) begin
      S1_clipped = 8'd0;
    end else if (Adj_S1 > 32'd255) begin
      S1_clipped = 8'd255;
    end else begin
      S1_clipped = Adj_S1[7:0];
    end
    
    // S2 clipping
    if (Adj_S2[31]) begin
      S2_clipped = 8'd0;
    end else if (Adj_S2 > 32'd255) begin
      S2_clipped = 8'd255;
    end else begin
      S2_clipped = Adj_S2[7:0];
    end
  end
  
  always_comb begin

    logic [3:0] row_set_times3;
    row_set_times3 = ({1'b0, row_set_counter} << 1) + {1'b0, row_set_counter};

    if (!Y_finished) begin

      i = row_set_times3;  // replaces multiply
      max_counter = 5'd15;
      max_row_set = 3'd5;

    end else begin

      i = row_set_times3;  // same logic
      max_counter = 5'd7;
      max_row_set = 3'd2;
    end
  end

  always_comb begin

    
    if (i[0] == 1'b0) begin
      mult_op1_a = {{16{Data_out_C_a[31]}}, Data_out_C_a[31:16]};
    end else begin
      mult_op1_a = {{16{Data_out_C_a[15]}}, Data_out_C_a[15:0]};
    end

    if (i[0] == 1'b0) begin
      mult_op1_b = {{16{Data_out_C_a[15]}}, Data_out_C_a[15:0]};
    end else begin
      mult_op1_b = {{16{Data_out_C_b[31]}}, Data_out_C_b[31:16]};
    end
    
    if (i[0] == 1'b0) begin
      mult_op1_c = {{16{Data_out_C_b[31]}}, Data_out_C_b[31:16]};
    end else begin
      mult_op1_c = {{16{Data_out_C_b[15]}}, Data_out_C_b[15:0]};
    end

    mult_op2_a = Data_out_T_a;
    mult_op2_b = Data_out_T_a;
    mult_op2_c = Data_out_T_a;
  end

  always_comb begin
    if (!Y_finished) begin
      // 16x16 mode
      C_Address_a = {Addressing_counter[3:0], 3'b0} + ({4'b0, i[3:0]} >> 1);
      C_Address_b = C_Address_a + 8'd1;

      T_Address = {column_counter[3:0], 4'b0} + {4'b0, Addressing_counter[3:0]};
    end else begin
      C_Address_a = 8'h80 + {Addressing_counter[2:0], 2'b0} + ({5'b0, i[2:0]} >> 1);
      C_Address_b = C_Address_a + 8'd1;

      T_Address = {column_counter[2:0], 3'b0} + {5'b0, Addressing_counter[2:0]};
    end
  end
  
  assign Address_C_a = C_Address_a;
  assign Address_C_b = C_Address_b;
  assign Address_T_a = T_Address;

  always_ff @(posedge Clock_50 or negedge Resetn) begin
    if (!Resetn) begin
      state <= S_IDLE;
      Addressing_counter <= 5'd0;
      column_counter <= 4'd0;
      first_cycle <= 1'b0;
      row_set_counter <= 3'd0;
      Acc_S0 <= 32'sd0;
      Acc_S1 <= 32'sd0;
      Acc_S2 <= 32'sd0;
      Write_en_S_a <= 1'b0;
      S_DP_RAM_address_a <= 8'd0;
      S_DP_RAM_write_data_a <= 32'd0;
      done <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          column_counter <= 4'd0;
          if (start) begin
            Write_en_S_a <= 1'b0; 
            done <= 1'b0;
            Addressing_counter <= 5'd0;
            column_counter <= 4'd0;
            row_set_counter <= 3'd0;
            Acc_S0 <= 32'sd0;
            Acc_S1 <= 32'sd0;
            Acc_S2 <= 32'sd0;
            S_DP_RAM_address_a <= 8'd0;
            first_cycle <= 1'b1;
            state <= S_LEAD_IN;
          end
        end

        S_LEAD_IN: begin
          Addressing_counter <= Addressing_counter + 5'd1;
          state <= S_CC0;
        end

        S_CC0: begin
          Acc_S0 <= mult_result_a;
          Acc_S1 <= mult_result_b;
          Acc_S2 <= mult_result_c;
          Write_en_S_a <= 1'b0;
          Addressing_counter <= Addressing_counter + 5'd1;
          state <= S_CC1;
        end

        S_CC1: begin
          Acc_S0 <= Acc_S0 + mult_result_a;
          Acc_S1 <= Acc_S1 + mult_result_b;
          Acc_S2 <= Acc_S2 + mult_result_c;
          Write_en_S_a <= 1'b0;
          Addressing_counter <= Addressing_counter + 5'd1;
          state <= S_CC2;
        end

        S_CC2, S_CC3, S_CC4, S_CC5, S_CC6: begin
          Acc_S0 <= Acc_S0 + mult_result_a;
          Acc_S1 <= Acc_S1 + mult_result_b;
          Acc_S2 <= Acc_S2 + mult_result_c;
          Write_en_S_a <= 1'b0;
          Addressing_counter <= Addressing_counter + 5'd1;
          state <= state_t'(state + 1);
        end

        S_CC7: begin
          Acc_S0 <= Acc_S0 + mult_result_a;
          Acc_S1 <= Acc_S1 + mult_result_b;
          Acc_S2 <= Acc_S2 + mult_result_c;
          Write_en_S_a <= 1'b0;
          
          if (Y_finished) begin
            Addressing_counter <= 5'd0;
            state <= S_WRITE;
          end else begin
            Addressing_counter <= Addressing_counter + 5'd1;
            state <= S_CC8;
          end
        end

        S_CC8, S_CC9, S_CC10, S_CC11, S_CC12, S_CC13, S_CC14: begin
          Acc_S0 <= Acc_S0 + mult_result_a;
          Acc_S1 <= Acc_S1 + mult_result_b;
          Acc_S2 <= Acc_S2 + mult_result_c;
          Write_en_S_a <= 1'b0;
          Addressing_counter <= Addressing_counter + 5'd1;
          state <= state_t'(state + 1);
        end

        S_CC15: begin
          Acc_S0 <= Acc_S0 + mult_result_a;
          Acc_S1 <= Acc_S1 + mult_result_b;
          Acc_S2 <= Acc_S2 + mult_result_c;
          Write_en_S_a <= 1'b0;
          Addressing_counter <= 5'd0;
          state <= S_WRITE;
        end

        S_WRITE: begin
          Write_en_S_a <= 1'b1;
          
          if (row_set_counter == max_row_set) begin
            if (!Y_finished) begin
              // 16x16: column 15 alone
              S_DP_RAM_write_data_a <= {24'h0, S0_clipped};
            end else begin
              // 8x8: columns 6-7
              S_DP_RAM_write_data_a <= {16'h0, S1_clipped, S0_clipped};
            end
          end else begin
            S_DP_RAM_write_data_a <= {8'h0, S2_clipped, S1_clipped, S0_clipped};
          end
          
          // Skip first write
          if (!first_cycle) begin
            S_DP_RAM_address_a <= S_DP_RAM_address_a + 8'd1;
          end
          first_cycle <= 1'b0;
          
          if (row_set_counter == max_row_set) begin
            row_set_counter <= 3'd0;
            
            if (column_counter == max_counter[3:0]) begin
              state <= S_END;
              done <= 1'b1;
            end else begin
              column_counter <= column_counter + 4'd1;
              Acc_S0 <= 32'sd0;
              Acc_S1 <= 32'sd0;  
              Acc_S2 <= 32'sd0;
              // Reset counter stays at 0, i updates to new row_set
              // This generates addr(0, new_i) during S_WRITE
              Addressing_counter <= 5'd0;
              state <= S_LEAD_IN;  // Still need initial lead-in for new column
            end
          end else begin
            row_set_counter <= row_set_counter + 3'd1;
            Acc_S0 <= 32'sd0;
            Acc_S1 <= 32'sd0;  
            Acc_S2 <= 32'sd0;
            // Counter stays at 0, but row_set_counter increments (so i updates)
            // This generates addr(0, new_i) during S_WRITE
            // Then prime counter to 1 at end of cycle for next address
            Addressing_counter <= 5'd1;
            state <= S_CC0;  // Skip S_LEAD_IN!
          end
        end

        S_END: begin
          done <= 1'b0;
          Write_en_S_a <= 1'b0;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule