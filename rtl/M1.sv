
`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module M1 (
   input  logic		Clock,
   input  logic		Resetn, 

   input  logic		start,
   output logic		done,
	
   input  logic   [15:0]   SRAM_read_data,
   
   output logic [17:0]	SRAM_address,
   output logic [15:0]	SRAM_write_data,
   output logic		SRAM_we_n
);

typedef enum logic [4:0] {
	S_IDLE,
	
	S_LEAD_IN0,
	S_LEAD_IN1,
	S_LEAD_IN2,
	S_LEAD_IN3,
	S_LEAD_IN4,
	S_LEAD_IN5,
	S_LEAD_IN6,
	S_LEAD_IN7,
	S_LEAD_IN8,
	

	S_COMMON_0,
	S_COMMON_1,
	S_COMMON_2,
	S_COMMON_3,
	S_COMMON_4,
	S_COMMON_5,
	S_COMMON_6,
	S_COMMON_7,
	
	
	S_LEAD_OUT0,
	S_LEAD_OUT1,
	S_LEAD_OUT2,
	S_LEAD_OUT3,
	S_LEAD_OUT4
	
} M1_state;

M1_state M1_S_state;

localparam [13:0] base_memory_Y = 14'd0;
localparam [15:0]base_memory_U = 16'd13824;
localparam [15:0]base_memory_V = 16'd20736;
localparam [17:0]base_memory_RGB = 18'd220672;

logic [13:0] memory_Y;
logic [15:0] memory_U;
logic [15:0] memory_V;
logic [17:0] memory_RGB;

logic [13:0] memory_offset_Y;
logic [15:0] memory_offset_UV;
logic [17:0] memory_offset_RGB;



logic [7:0] U9_m, U7_m, U5_m, U3_m, U1_m;
logic [7:0] U9_p, U7_p, U5_p, U3_p, U1_p;
logic [7:0] V9_m, V7_m, V5_m, V3_m, V1_m;
logic [7:0] V9_p, V7_p, V5_p, V3_p, V1_p;

logic [7:0] Uodd;
logic [7:0] Vodd;

logic [7:0] U_prime_even, V_prime_even;

logic [7:0] Ye, Yo;

logic [31:0] M0, M1, M2, M3;
logic [31:0] M0_buff, M1_buff, M2_buff, M3_buff;
logic [31:0] M0_op_1, M0_op_2, M1_op_1, M1_op_2, M2_op_1, M2_op_2, M3_op_1, M3_op_2;

logic [31:0] accU_prime, accV_prime; //prime_odd on third partial
logic [7:0] U_prime_odd, V_prime_odd;

logic [31:0] Re, Ro;
logic [31:0] Ge, Go;
logic [31:0] Be, Bo;


logic [7:0] Re_write, Ro_write;
logic [7:0] Ge_write, Go_write;
logic [7:0] Be_write, Bo_write;



logic even_cycle, new_row;
logic [7:0] pixel_compute_counter;
logic [7:0] pixel_column_counter;


// Receive data 
always_ff @ (posedge Clock or negedge Resetn) begin
	if (~Resetn) begin
		SRAM_we_n <= 1'b1;			
		done <= 1'd0;
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		
		M1_S_state <= S_IDLE;

		U9_m <= 8'h0; U7_m <= 8'h0; U5_m <= 8'h0; U3_m <= 8'h0; U1_m <= 8'h0;
		U1_p <= 8'h0; U3_p <= 8'h0; U5_p <= 8'h0; U7_p <= 8'h0; U9_p <= 8'h0;

		V9_m <= 8'h0; V7_m <= 8'h0; V5_m <= 8'h0; V3_m <= 8'h0; V1_m <= 8'h0; 
		V1_p <= 8'h0; V3_p <= 8'h0; V5_p <= 8'h0; V7_p <= 8'h0; V9_p <= 8'h0;

		Ye <= 8'h0;
		Yo <= 8'h0;


		Uodd <= 8'h0;
		Vodd <= 8'h0;

		U_prime_even <= 8'h0;
		V_prime_even <= 8'h0;
		accU_prime <= 32'h0; 
		accV_prime <= 32'h0;

		new_row <= 1'b1;

		M0_op_1 <= 32'h0; M0_op_2 <= 32'h0; M1_op_1 <= 32'h0; M1_op_2 <= 32'h0; M2_op_1 <= 32'h0;
		M2_op_2 <= 32'h0; M3_op_1 <= 32'h0; M3_op_2<= 32'h0;
	
		Re <= 8'h0;
		Ro <= 8'h0;
		Ge <= 8'h0;
		Go <= 8'h0;
		Be <= 8'h0;	
		Bo <= 8'h0;
		
		M0_buff <= 32'h0;
		M1_buff <= 32'h0;
		M2_buff <= 32'h0;
		M3_buff <= 32'h0;

		memory_Y <= base_memory_Y;
		memory_U <= base_memory_U;
		memory_V <= base_memory_V;
		memory_RGB <= base_memory_RGB;
		
		
		memory_offset_Y <= 14'd0;
		memory_offset_UV <= 15'd0;
		memory_offset_RGB <= 17'd0;


		even_cycle <= 1'b1;
		pixel_compute_counter <= 8'h0;
		pixel_column_counter <= 8'h0;
		
	end else begin
			case (M1_S_state)


			S_IDLE: begin
					memory_Y <= base_memory_Y;
					memory_U <= base_memory_U;
					memory_V <= base_memory_V;
					memory_RGB <= base_memory_RGB;
					if (start == 1'b1) begin
						done <= 1'd0;
						M1_S_state <= S_LEAD_IN0;
						SRAM_address <= memory_U + memory_offset_UV; //U0U1
					end 
			end
 

			S_LEAD_IN0: begin
					SRAM_address <= memory_V + memory_offset_UV; //V0V1
					memory_offset_UV <= memory_offset_UV + 1'b1;  //Always read U and V same time can be one offset reg
					SRAM_we_n <= 1'b1;
					M1_S_state <= S_LEAD_IN1;
					new_row <= 1'b1;
					pixel_compute_counter <= 7'b0;
			end
			
			S_LEAD_IN1: begin
					SRAM_address <= memory_U + memory_offset_UV;  //U2U3
					
					M1_S_state <= S_LEAD_IN2;          					
			end
			
			S_LEAD_IN2: begin
					SRAM_address <= memory_V + memory_offset_UV;  //V2V3
					
					U9_m <= SRAM_read_data[15:8]; 	
					U7_m <= SRAM_read_data[15:8]; 
					U5_m <= SRAM_read_data[15:8];  
					U3_m <= SRAM_read_data[15:8]; 
					U1_m <= SRAM_read_data[15:8];
					U1_p <= SRAM_read_data[7:0];
					
					memory_offset_UV <= memory_offset_UV + 1'b1;


					M1_S_state <= S_LEAD_IN3;			
			end

			S_LEAD_IN3: begin
					SRAM_address <= memory_U + memory_offset_UV;  //U4U5
					
					V9_m <= SRAM_read_data[15:8]; 
					V7_m <= SRAM_read_data[15:8]; 
					V5_m <= SRAM_read_data[15:8];  
					V3_m <= SRAM_read_data[15:8]; 
					V1_m <= SRAM_read_data[15:8];
					V1_p <= SRAM_read_data[7:0];
					
					M1_S_state <= S_LEAD_IN4;				
			end
			
			S_LEAD_IN4: begin
					SRAM_address <= memory_V + memory_offset_UV; //V4V5
					memory_offset_UV <= memory_offset_UV + 1'b1;

					U3_p <= SRAM_read_data[15:8];
					U5_p <= SRAM_read_data[7:0];  

					M1_S_state <= S_LEAD_IN5;				
			end
			
			S_LEAD_IN5: begin
					SRAM_address <= memory_Y + memory_offset_Y; //Y0Y1
					
					V3_p <= SRAM_read_data[15:8];
					V5_p <= SRAM_read_data[7:0];  
					
					memory_offset_Y <= memory_offset_Y + 1'b1;
					
					M1_S_state <= S_LEAD_IN6;				
			end
			
			S_LEAD_IN6: begin 
					
					U7_p <= SRAM_read_data[15:8];
					U9_p <= SRAM_read_data[7:0];  
						
					M1_S_state <= S_LEAD_IN7;				
			end
			
			S_LEAD_IN7: begin

					V7_p <= SRAM_read_data[15:8];
					V9_p <= SRAM_read_data[7:0];  
					
					M1_S_state <= S_LEAD_IN8;				
			end
			
			S_LEAD_IN8: begin
				
					Ye <= SRAM_read_data[15:8];
					Yo <= SRAM_read_data[7:0];

					SRAM_address <= memory_RGB + memory_offset_RGB;

					U_prime_even <= U1_m;	
					V_prime_even <= V1_m;

					M0_op_1 <= 32'd36;   M0_op_2 <= {24'd0, U9_m};
					M1_op_1 <= 32'd98;   M1_op_2 <= {24'd0, U7_m};
					M2_op_1 <= 32'd233;  M2_op_2 <= {24'd0, U5_m};
					M3_op_1 <= 32'd528;  M3_op_2 <= {24'd0, U3_m};

					M1_S_state <= S_COMMON_0;				
			end
		
///////////////End of lead in state3s//////////////////////		

		
			S_COMMON_7: begin
					SRAM_address <= memory_RGB + memory_offset_RGB;

					Ye <= SRAM_read_data[15:8];
					Yo <= SRAM_read_data[7:0];
					
					Go <= (M1_buff - M3_buff - M0 + 32'd16384);
					Bo <= (M1_buff + M1 + 32'd16384);

					U_prime_even <= U1_m;	

					SRAM_write_data <= {Re_write, Ge_write}; //writing ReGe

					V_prime_even <= V1_m;

					if(!new_row) begin 
					SRAM_we_n <= 1'b0;
					memory_offset_RGB <= memory_offset_RGB + 1'b1;
					end
					
					
					M0_op_1 <= 32'd36;   M0_op_2 <= {24'd0, U9_m};
					M1_op_1 <= 32'd98;   M1_op_2 <= {24'd0, U7_m};
					M2_op_1 <= 32'd233;  M2_op_2 <= {24'd0, U5_m};
					M3_op_1 <= 32'd528;  M3_op_2 <= {24'd0, U3_m};




					even_cycle <= !even_cycle;
					if(pixel_compute_counter < 190)
					M1_S_state <= S_COMMON_0;		
					else 
					M1_S_state <= S_LEAD_OUT0;
			end
			
			S_COMMON_0: begin
					SRAM_address <= memory_RGB + memory_offset_RGB;
					
					if(!new_row) begin 
					SRAM_we_n <= 1'b0;
					memory_offset_RGB <= memory_offset_RGB + 1'b1;
					end
					
					///Mipliers
					M0_op_1 <= 32'd1815; M0_op_2 <= {24'd0, U1_m};
					M1_op_1 <= 32'd1815; M1_op_2 <= {24'd0, U1_p};
					M2_op_1 <= 32'd528;  M2_op_2 <= {24'd0, U3_p};
					M3_op_1 <= 32'd233;  M3_op_2 <= {24'd0, U5_p};

					accU_prime <= M0 - M1 - M2 + M3;
					
					SRAM_write_data <= {Be_write, Ro_write}; //writing BeRo
					
					M1_S_state <= S_COMMON_1; 
					
					         					
			end
			
			S_COMMON_1: begin
					SRAM_address <= memory_RGB + memory_offset_RGB;

					SRAM_write_data <= {Go_write, Bo_write}; //writing GoBo
					
					if(!new_row) begin 
					SRAM_we_n <= 1'b0;
					memory_offset_RGB <= memory_offset_RGB + 1'b1;
					pixel_compute_counter <= pixel_compute_counter + 2'd2;
					end
					///Mipliers

					M0_op_1 <= 32'd98;   M0_op_2 <= {24'd0, U7_p};
					M1_op_1 <= 32'd36;   M1_op_2 <= {24'd0, U9_p};
					M2_op_1 <= 32'd36;   M2_op_2 <= {24'd0, V9_m};
					M3_op_1 <= 32'd98;   M3_op_2 <= {24'd0, V7_m};

				    accU_prime <= M0 + M1 + M2 - M3 + accU_prime;

					new_row <= 1'b0;
					
					M1_S_state <= S_COMMON_2;			
			end

			S_COMMON_2: begin
					if(even_cycle && pixel_compute_counter < 180) begin
						SRAM_address <= memory_U + memory_offset_UV;  //UeUo
					end 

					
					M0_op_1 <= 32'd233;  M0_op_2 <= {24'd0, V5_m};
					M1_op_1 <= 32'd528;  M1_op_2 <= {24'd0, V3_m};
					M2_op_1 <= 32'd1815; M2_op_2 <= {24'd0, V1_m};
					M3_op_1 <= 32'd1815; M3_op_2 <= {24'd0, V1_p};

					SRAM_we_n <= 1'b1;
					
					accU_prime <= accU_prime - M0 + M1 + 32'd2048; //This is U'odd and need to clip
					accV_prime <= M2 - M3;

					
					M1_S_state <= S_COMMON_3;				
			end
			
			S_COMMON_3: begin
					if(even_cycle && pixel_compute_counter < 180) begin //Stop reading from U and V
					SRAM_address <= memory_V + memory_offset_UV;  //VeVo
					memory_offset_UV <= memory_offset_UV + 1'b1;
					end 
					

					M0_op_1 <= 32'd528;  M0_op_2 <= {24'd0, V3_p};
					M1_op_1 <= 32'd233;  M1_op_2 <= {24'd0, V5_p};
					M2_op_1 <= 32'd98;   M2_op_2 <= {24'd0, V7_p};
					M3_op_1 <= 32'd36;   M3_op_2 <= {24'd0, V9_p};

					accV_prime <= -M0 + M1 + M2 + M3 + accV_prime;
					
					M1_S_state <= S_COMMON_4;				
			end
			
			S_COMMON_4: begin
				if(pixel_compute_counter < 190) begin //Stop reading from U and V
					SRAM_address <= memory_Y + memory_offset_Y;  //YeYo
					memory_offset_Y <= memory_offset_Y + 1'b1;	
				end 
					
					
					M0_op_1 <= 32'sd38142; M0_op_2 <= ({24'd0, Ye} - 32'sd16);             
					M1_op_1 <= 32'sd38142; M1_op_2 <= ({24'd0, Yo} - 32'sd16);             
					M2_op_1 <= 32'sd12845; M2_op_2 <= ({24'd0, U_prime_even} - 32'sd128); 
					M3_op_1 <= 32'sd12845; M3_op_2 <= ({24'd0, U_prime_odd}  - 32'sd128);


				
					accV_prime <= M0 - M1 - M2 + M3 + accV_prime + 32'd2048;  //This is V'odd
					M1_S_state <= S_COMMON_5;				
			end
			
			S_COMMON_5: begin 
					

					U9_m <= U7_m;	
					U7_m <= U5_m;
					U5_m <= U3_m; 
					U3_m <= U1_m;
					U1_m <= U1_p;
					U1_p <= U3_p;
					U3_p <= U5_p;
					U5_p <= U7_p;  
					U7_p <= U9_p;  

					if(even_cycle && pixel_compute_counter < 180) begin
						U9_p <= SRAM_read_data[15:8];
						Uodd <= SRAM_read_data[7:0]; 
					end else if(!even_cycle && pixel_compute_counter < 180) begin
						U9_p <= Uodd;
					end

					M0_op_1 <= 32'sd66093; M0_op_2 <= ({24'd0, U_prime_even} - 32'sd128);
					M1_op_1 <= 32'sd52298; M1_op_2 <= ({24'd0, V_prime_even} - 32'sd128);  
					M2_op_1 <= 32'sd52298; M2_op_2 <= ({24'd0, V_prime_odd} - 32'sd128);  
					M3_op_1 <= 32'sd26640; M3_op_2 <= ({24'd0, V_prime_even} - 32'sd128);




					M0_buff <= M0;
					M1_buff <= M1;
					M2_buff <= M2;
					M3_buff <= M3;
					
					M1_S_state <= S_COMMON_6;				
			end   
			
			S_COMMON_6: begin
		
					V9_m <= V7_m;	
					V7_m <= V5_m;
					V5_m <= V3_m; 
					V3_m <= V1_m;
					V1_m <= V1_p;
					V1_p <= V3_p;
					V3_p <= V5_p;
					V5_p <= V7_p;  
					V7_p <= V9_p;  

					Re <= (M0_buff + M1 + 32'd16384);
					Ro <= (M1_buff + M2 + 32'd16384);
					Ge <= (M0_buff - M2_buff - M3 + 32'd16384);
					Be <= (M0_buff + M0 + 32'd16384);
					

					M0_op_1 <= 32'sd26640; M0_op_2 <= ({24'd0, V_prime_odd} - 32'sd128);
					M1_op_1 <= 32'sd66093; M1_op_2 <= ({24'd0, U_prime_odd} - 32'sd128);



					if(even_cycle && pixel_compute_counter < 180) begin
						V9_p <= SRAM_read_data[15:8];
						Vodd <= SRAM_read_data[7:0]; 
					end else if(!even_cycle && pixel_compute_counter < 180) begin
						V9_p <= Vodd;					
					end

					M1_S_state <= S_COMMON_7;
			end
			
			
/////////////////////End of common cases///////////////////////


			S_LEAD_OUT0: begin
					SRAM_address <= memory_RGB + memory_offset_RGB;

					SRAM_write_data <= {Be_write, Ro_write}; 

					memory_offset_RGB <= memory_offset_RGB + 1'b1;
					
					M1_S_state <= S_LEAD_OUT1;				
			end

			S_LEAD_OUT1: begin
				    SRAM_address <= memory_RGB + memory_offset_RGB;


					SRAM_write_data <= {Go_write, Bo_write}; 

					memory_offset_RGB <= memory_offset_RGB + 1'b1;
					
					M1_S_state <= S_LEAD_OUT2;
			end

			S_LEAD_OUT2: begin
					
			if(pixel_column_counter < 8'd143) begin
					M1_S_state <= S_LEAD_IN0;		
					new_row <= 1'b1;
					SRAM_address <= memory_U + memory_offset_UV;
					pixel_column_counter <= pixel_column_counter + 8'h1;	
					SRAM_we_n <= 1'b1;
			end else begin
					SRAM_we_n <= 1'b1;
					M1_S_state <= S_IDLE;
					done <= 1'b1;
					end
			end 

			

			default: M1_S_state <= S_IDLE;
			endcase

	end


	
	end


////////////////// Multipler logic //////////////

assign Re_write = Re[31] ? 8'h00 : |Re[30:23] ? 8'hFF : Re[22:15]; //Without arithmetic division
assign Ro_write = Ro[31] ? 8'h00 : |Ro[30:23] ? 8'hFF : Ro[22:15];
assign Ge_write = Ge[31] ? 8'h00 : |Ge[30:23] ? 8'hFF : Ge[22:15];
assign Go_write = Go[31] ? 8'h00 : |Go[30:23] ? 8'hFF : Go[22:15];
assign Be_write = Be[31] ? 8'h00 : |Be[30:23] ? 8'hFF : Be[22:15];
assign Bo_write = Bo[31] ? 8'h00 : |Bo[30:23] ? 8'hFF : Bo[22:15];

assign U_prime_odd = accU_prime[31] ? 8'h00 : |accU_prime[30:20] ? 8'hFF : accU_prime[19:12];
assign V_prime_odd = accV_prime[31] ? 8'h00 : |accV_prime[30:20] ? 8'hFF : accV_prime[19:12];

logic [63:0] M0_result, M1_result, M2_result, M3_result;

assign M0 = M0_result[31:0];
assign M1 = M1_result[31:0];
assign M2 = M2_result[31:0];
assign M3 = M3_result[31:0];

assign M0_result = M0_op_1 * M0_op_2;
assign M1_result = M1_op_1 * M1_op_2;
assign M2_result = M2_op_1 * M2_op_2;
assign M3_result = M3_op_1 * M3_op_2;




endmodule