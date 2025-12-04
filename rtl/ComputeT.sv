`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif
 
 
module ComputeT (
  input  logic Clock_50,
  input  logic Resetn,
 
  // C dpram
  output logic [7:0] Address_C_a,
  input  logic [31:0] Data_out_C_a,
  input logic Y_finished,
 
  // Sp dpram - primary port
  output logic [7:0] Address_Sp_a,
  input  logic [31:0] Data_out_Sp_a,
  // Sp dpram - second port access
  output logic [7:0] Address_Sp_b,
  input  logic [31:0] Data_out_Sp_b,
 
  // T dpram
  output logic [7:0] T_DP_RAM_address_a,
  output logic [7:0] T_DP_RAM_address_b,
  output logic Write_en_T_a,
  output logic Write_en_T_b,
  output logic [31:0] T_DP_RAM_write_data_a,
  output logic [31:0] T_DP_RAM_write_data_b,
 
  input  logic start,
  output logic done,
  output logic signed [31:0] mult_op1_a,
  output logic signed [31:0] mult_op1_b,
  output logic signed [31:0] mult_op1_c,
  output logic signed [31:0] mult_op2_a,
  output logic signed [31:0] mult_op2_b,
  output logic signed [31:0] mult_op2_c,
  input logic signed [31:0] mult_result_a,
  input logic signed [31:0] mult_result_b,
  input logic signed [31:0] mult_result_c
);
 
  logic [4:0] Addressing_counter;
  logic [3:0] column_counter;
  logic [2:0] row_set_counter;
  logic [3:0] k;
  logic [7:0] Sp_Address_a, Sp_Address_b, C_Address;
  logic [4:0] max_counter;
  logic [2:0] max_row_set;
  logic use_upper_C, use_upper_Sp_a, use_upper_Sp_b;
  logic last_row_set;
  logic enable_M2;  
  logic first_cycle;
  logic signed [31:0] Acc_T0, Acc_T1, Acc_T2;
  // Write buffers for completed computations
  logic signed [31:0] Writebuff0, Writebuff1, Writebuff2;
  logic signed [31:0] Writebuff0_div32, Writebuff1_div32, Writebuff2_div32;
  // Buffered row_set and column for delayed write addressing
  logic [2:0] write_row_set_counter;
  logic [3:0] write_column_counter;
  logic write_last_row_set;
  logic write_Y_finished;
 
  logic [7:0] T_base_address;
  logic [7:0] T_addr_offset;
  logic [7:0] write_T_base_address;
  logic [7:0] write_T_addr_offset;
 
  typedef enum logic [4:0] { 
    S_IDLE, 
    S_LEAD_IN,
    S_CC0, S_CC1, S_CC2, S_CC3, S_CC4, S_CC5, S_CC6, S_CC7,
    S_CC8, S_CC9, S_CC10, S_CC11, S_CC12, S_CC13, S_CC14, S_CC15,
    S_END 
  } state_t;
  state_t state;
  // Arithmetic right shift by 5 to divide by 32 (preserves sign)
  assign Writebuff0_div32 = Writebuff0 >>> 5;
  assign Writebuff1_div32 = Writebuff1 >>> 5;
  assign Writebuff2_div32 = Writebuff2 >>> 5;
  // Counter interpretation based on Y_finished
  always_comb begin
    if (!Y_finished) begin
      // 16x16 block
      k            = Addressing_counter[3:0];
      max_counter  = 5'd15;
      max_row_set  = 3'd5;
      enable_M2    = 1'b1;
    end else begin
      // 8x8 block
      k            = {1'b0, Addressing_counter[2:0]};
      max_counter  = 5'd7;
      max_row_set  = 3'd2;
      enable_M2 = (row_set_counter != 3'd2);
    end
  end
 
  // Multiplier operand generation (combinatorial)
  always_comb begin
    // C operand selection
    if (use_upper_C) begin
      mult_op1_a = {{16{Data_out_C_a[31]}}, Data_out_C_a[31:16]};
      mult_op1_b = {{16{Data_out_C_a[31]}}, Data_out_C_a[31:16]};
      mult_op1_c = {{16{Data_out_C_a[31]}}, Data_out_C_a[31:16]};
    end else begin
      mult_op1_a = {{16{Data_out_C_a[15]}}, Data_out_C_a[15:0]};
      mult_op1_b = {{16{Data_out_C_a[15]}}, Data_out_C_a[15:0]};
      mult_op1_c = {{16{Data_out_C_a[15]}}, Data_out_C_a[15:0]};
    end
 
    // Sp operand selection
    if (use_upper_Sp_a) begin
      mult_op2_a = {{16{Data_out_Sp_a[31]}}, Data_out_Sp_a[31:16]};
    end else begin
      mult_op2_a = {{16{Data_out_Sp_a[15]}}, Data_out_Sp_a[15:0]};
    end
 
    if (use_upper_Sp_a) begin
      mult_op2_b = {{16{Data_out_Sp_a[15]}}, Data_out_Sp_a[15:0]};
    end else begin
      mult_op2_b = {{16{Data_out_Sp_b[31]}}, Data_out_Sp_b[31:16]};
    end
    if (use_upper_Sp_b) begin
      mult_op2_c = {{16{Data_out_Sp_b[31]}}, Data_out_Sp_b[31:16]};
    end else begin
      mult_op2_c = {{16{Data_out_Sp_b[15]}}, Data_out_Sp_b[15:0]};
    end
    if (!enable_M2) begin
      mult_op1_c = 32'sd0;
      mult_op2_c = 32'sd0;
    end
  end
 
  always_comb begin
    if (!Y_finished) begin
        Sp_Address_a = 8'({3'b0, k[3:0], 3'b0} + (({6'b0, row_set_counter, 1'b0} + {6'b0, row_set_counter}) >> 1));
        Sp_Address_b = Sp_Address_a + 8'd1;
        C_Address = {k[3:0], 3'b0} + {4'b0, column_counter[3:1]};
    end else begin
        Sp_Address_a = 8'({4'b0, k[2:0], 2'b0} + (({6'b0, row_set_counter, 1'b0} + {6'b0, row_set_counter}) >> 1));
        Sp_Address_b = Sp_Address_a + 8'd1;
        C_Address = 8'h80 + {k[2:0], 2'b0} + {5'b0, column_counter[2:1]};
    end
  end
  assign Address_Sp_a = Sp_Address_a;
  assign Address_Sp_b = Sp_Address_b;
  assign Address_C_a  = C_Address;
 
  always_comb begin
    use_upper_C = ~column_counter[0];   
    if (!Y_finished) begin
      if (row_set_counter[0] == 1'b0) begin
        use_upper_Sp_a = 1'b1;
        use_upper_Sp_b = 1'b1;
      end else begin
        use_upper_Sp_a = 1'b0;
        use_upper_Sp_b = 1'b0;
      end
    end else begin
      case (row_set_counter)
        3'd0: begin
          use_upper_Sp_a = 1'b1;
          use_upper_Sp_b = 1'b1;
        end
        3'd1: begin
          use_upper_Sp_a = 1'b0;
          use_upper_Sp_b = 1'b0;
        end
        3'd2: begin
          use_upper_Sp_a = 1'b1;
          use_upper_Sp_b = 1'b1;
        end
        default: begin
          use_upper_Sp_a = 1'b1;
          use_upper_Sp_b = 1'b1;
        end
      endcase
    end
  end
 
  // Current T address calculation
  always_comb begin
    last_row_set = (row_set_counter == max_row_set);
    if (!Y_finished) begin
        T_addr_offset = 8'({5'b0, row_set_counter, 1'b0} + {6'b0, row_set_counter});
        T_base_address = {column_counter[3:0], 4'b0} + T_addr_offset;
    end else begin
        T_addr_offset = 8'({5'b0, row_set_counter, 1'b0} + {6'b0, row_set_counter});
        T_base_address = {1'b0, column_counter[2:0], 3'b0} + T_addr_offset;
    end
  end
 
  // Buffered T address calculation for writes
  always_comb begin
    write_last_row_set = (write_row_set_counter == (write_Y_finished ? 3'd2 : 3'd5));
    if (!write_Y_finished) begin
        write_T_addr_offset = 8'({5'b0, write_row_set_counter, 1'b0} + {6'b0, write_row_set_counter});
        write_T_base_address = {write_column_counter[3:0], 4'b0} + write_T_addr_offset;
    end else begin
        write_T_addr_offset = 8'({5'b0, write_row_set_counter, 1'b0} + {6'b0, write_row_set_counter});
        write_T_base_address = {1'b0, write_column_counter[2:0], 3'b0} + write_T_addr_offset;
    end
  end


  always_ff @(posedge Clock_50 or negedge Resetn) begin

    if (!Resetn) begin

      state <= S_IDLE;

      Addressing_counter <= 5'd0;

      column_counter <= 4'd0;

      row_set_counter <= 3'd0;

      Acc_T0 <= 32'sd0;

      Acc_T1 <= 32'sd0;

      Acc_T2 <= 32'sd0;

      Writebuff0 <= 32'sd0;

      Writebuff1 <= 32'sd0;

      Writebuff2 <= 32'sd0;

      write_row_set_counter <= 3'd0;

      write_column_counter <= 4'd0;

      write_Y_finished <= 1'b0;

      Write_en_T_a <= 1'b0;

      Write_en_T_b <= 1'b0;

      T_DP_RAM_address_a <= 8'd0;

      T_DP_RAM_address_b <= 8'd1;

      T_DP_RAM_write_data_a <= 32'sd0;

      T_DP_RAM_write_data_b <= 32'sd0;

      done <= 1'b0;

      first_cycle <= 1'b1;

    end else begin

      case (state)

        S_IDLE: begin

          if (start) begin

            Write_en_T_a <= 1'b0; 

            Write_en_T_b <= 1'b0;

            done <= 1'b0;

            Addressing_counter <= 5'd0;

            column_counter <= 4'd0;

            row_set_counter <= 3'd0;

            Acc_T0 <= 32'sd0;

            Acc_T1 <= 32'sd0;

            Acc_T2 <= 32'sd0;

            Writebuff0 <= 32'sd0;

            Writebuff1 <= 32'sd0;

            Writebuff2 <= 32'sd0;

            write_row_set_counter <= 3'd0;

            write_column_counter <= 4'd0;

            write_Y_finished <= Y_finished;

            first_cycle <= 1'b1;

            state <= S_LEAD_IN;

          end

        end
 
        S_LEAD_IN: begin

          Addressing_counter <= Addressing_counter + 5'd1;

          state <= S_CC0;

        end
 
        S_CC0: begin

          // Accumulate first result

          Acc_T0 <= mult_result_a;

          Acc_T1 <= mult_result_b;

          Acc_T2 <= mult_result_c;
 
          // Write from previous cycle's buffered results

          if (!first_cycle) begin

            T_DP_RAM_write_data_a <= Writebuff0_div32;

            Write_en_T_a <= 1'b1;

            T_DP_RAM_address_a <= write_T_base_address;

            if (write_Y_finished) begin

              // 8x8 mode

              T_DP_RAM_write_data_b <= Writebuff1_div32;

              T_DP_RAM_address_b <= write_T_base_address + 8'd1;

              Write_en_T_b <= 1'b1;

            end else begin

              // 16x16 mode

              if (!write_last_row_set) begin

                T_DP_RAM_write_data_b <= Writebuff1_div32;

                T_DP_RAM_address_b <= write_T_base_address + 8'd1;

                Write_en_T_b <= 1'b1;

              end else begin

                Write_en_T_b <= 1'b0;

              end

            end

          end else begin

            Write_en_T_a <= 1'b0;

            Write_en_T_b <= 1'b0;

          end
 
          Addressing_counter <= Addressing_counter + 5'd1;

          state <= S_CC1;

        end
 
        S_CC1: begin

          Acc_T0 <= Acc_T0 + mult_result_a;

          Acc_T1 <= Acc_T1 + mult_result_b;

          Acc_T2 <= Acc_T2 + mult_result_c;

          // Write third row from previous cycle's buffered results

          if (!first_cycle && !write_last_row_set) begin

            T_DP_RAM_write_data_a <= Writebuff2_div32;

            T_DP_RAM_address_a <= write_T_base_address + 8'd2;

            Write_en_T_a <= 1'b1;

          end else begin

            Write_en_T_a <= 1'b0;

          end

          Write_en_T_b <= 1'b0;
 
          Addressing_counter <= Addressing_counter + 5'd1;

          state <= S_CC2;

        end
 
        S_CC2, S_CC3, S_CC4, S_CC5, S_CC6: begin

          Acc_T0 <= Acc_T0 + mult_result_a;

          Acc_T1 <= Acc_T1 + mult_result_b;

          Acc_T2 <= Acc_T2 + mult_result_c;

          Write_en_T_a <= 1'b0;

          Write_en_T_b <= 1'b0;

          Addressing_counter <= Addressing_counter + 5'd1;

          state <= state_t'(state + 1);

        end
 
        S_CC7: begin

          Acc_T0 <= Acc_T0 + mult_result_a;

          Acc_T1 <= Acc_T1 + mult_result_b;

          Acc_T2 <= Acc_T2 + mult_result_c;

          Write_en_T_a <= 1'b0;

          Write_en_T_b <= 1'b0;

          if (Y_finished) begin

            // 8x8 mode - capture results and update state

            Writebuff0 <= Acc_T0 + mult_result_a;

            Writebuff1 <= Acc_T1 + mult_result_b;

            Writebuff2 <= Acc_T2 + mult_result_c;

            // Buffer current addressing info for next cycle's write

            write_row_set_counter <= row_set_counter;

            write_column_counter <= column_counter;

            write_Y_finished <= Y_finished;

            // Clear first_cycle flag

            if (first_cycle) first_cycle <= 1'b0;

            // Update counters for next computation

            if (row_set_counter == max_row_set) begin

              row_set_counter <= 3'd0;

              if (column_counter == max_counter[3:0]) begin

                // Last computation done, will write in next CC0 then end

                Addressing_counter <= 5'd0;

                state <= S_CC0;

              end else begin

                column_counter <= column_counter + 4'd1;

                Addressing_counter <= 5'd0;

                state <= S_LEAD_IN;

              end

            end else begin

              row_set_counter <= row_set_counter + 3'd1;

              Addressing_counter <= 5'd0;

              state <= S_LEAD_IN;

            end

          end else begin

            // 16x16 mode - continue

            Addressing_counter <= Addressing_counter + 5'd1;

            state <= S_CC8;

          end

        end
 
        S_CC8, S_CC9, S_CC10, S_CC11, S_CC12, S_CC13, S_CC14: begin

          Acc_T0 <= Acc_T0 + mult_result_a;

          Acc_T1 <= Acc_T1 + mult_result_b;

          Acc_T2 <= Acc_T2 + mult_result_c;

          Write_en_T_a <= 1'b0;

          Write_en_T_b <= 1'b0;

          Addressing_counter <= Addressing_counter + 5'd1;

          state <= state_t'(state + 1);

        end
 
        S_CC15: begin

          Acc_T0 <= Acc_T0 + mult_result_a;

          Acc_T1 <= Acc_T1 + mult_result_b;

          Acc_T2 <= Acc_T2 + mult_result_c;

          Write_en_T_a <= 1'b0;

          Write_en_T_b <= 1'b0;

          // 16x16 mode - capture results and update state

          Writebuff0 <= Acc_T0 + mult_result_a;

          Writebuff1 <= Acc_T1 + mult_result_b;

          Writebuff2 <= Acc_T2 + mult_result_c;

          // Buffer current addressing info for next cycle's write

          write_row_set_counter <= row_set_counter;

          write_column_counter <= column_counter;

          write_Y_finished <= Y_finished;

          // Clear first_cycle flag

          if (first_cycle) first_cycle <= 1'b0;

          // Update counters for next computation

          if (row_set_counter == max_row_set) begin

            row_set_counter <= 3'd0;

            if (column_counter == max_counter[3:0]) begin

              // Last computation done, will write in next CC0 then end

              Addressing_counter <= 5'd0;

              state <= S_CC0;

            end else begin

              column_counter <= column_counter + 4'd1;

              Addressing_counter <= 5'd0;

              state <= S_LEAD_IN;

            end

          end else begin

            row_set_counter <= row_set_counter + 3'd1;

            Addressing_counter <= 5'd0;

            state <= S_LEAD_IN;

          end

        end
 
        S_END: begin

          done <= 1'b0;

          Write_en_T_a <= 1'b0;

          Write_en_T_b <= 1'b0;

          state <= S_IDLE;

        end
 
        default: state <= S_IDLE;

      endcase

      // Check for completion after write completes in CC1

      if (state == S_CC1 && !first_cycle) begin

        if (write_row_set_counter == (write_Y_finished ? 3'd2 : 3'd5) && 

            write_column_counter == (write_Y_finished ? 4'd7 : 4'd15)) begin

          state <= S_END;

          done <= 1'b1;

        end

      end

    end

  end
 
endmodule
 