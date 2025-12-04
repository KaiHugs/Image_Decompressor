`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module ZZ_counter (
    input logic Clock_50,
    input logic Resetn,
    input logic enable,
    input logic mode,
    output logic [7:0] ZZ_address
);

logic Dir;
logic [3:0] ri, ci;
logic [3:0] max;

// Max value based on mode
always_comb begin
    if (mode == 1'b1) begin
        max = 4'd15;
    end else begin
        max = 4'd7;
    end
end

// Sequential logic - update on enable
always_ff @(posedge Clock_50 or negedge Resetn) begin
    if (~Resetn) begin
        ri <= 4'd0;
        ci <= 4'd0;
        Dir <= 1'b0;
    end else if (enable) begin
        // 16x16 mode
        if (mode == 1'b1) begin  
            if (Dir == 1'b0) begin
                if (ri == 4'd0 && ci != max) begin
                    ci <= ci + 4'd1;
                    Dir <= 1'b1;
                end else if (ci == max) begin
                    ri <= ri + 4'd1;
                    Dir <= 1'b1;
                end else begin
                    ri <= ri - 4'd1;
                    ci <= ci + 4'd1;
                end
            end else begin
                if (ci == 4'd0 && ri != max) begin
                    ri <= ri + 4'd1;
                    Dir <= 1'b0;
                end else if (ri == max) begin
                    ci <= ci + 4'd1;
                    Dir <= 1'b0;
                end else begin
                    ri <= ri + 4'd1;
                    ci <= ci - 4'd1;
                end
            end
        // 8x8 mode
        end else begin  
            if (Dir == 1'b0) begin
                if (ci == 4'd0 && ri != max) begin
                    ri <= ri + 4'd1;
                    Dir <= 1'b1;
                end else if (ri == max) begin
                    ci <= ci + 4'd1;
                    Dir <= 1'b1;
                end else begin
                    ri <= ri + 4'd1;
                    ci <= ci - 4'd1;
                end
            end else begin
                if (ri == 4'd0 && ci != max) begin
                    ci <= ci + 4'd1;
                    Dir <= 1'b0;
                end else if (ci == max) begin
                    ri <= ri + 4'd1;
                    Dir <= 1'b0;
                end else begin
                    ri <= ri - 4'd1;
                    ci <= ci + 4'd1;
                end
            end
        end
    end
end

// Output is sequential - current position
assign ZZ_address = mode ? {ri, ci} : {2'b0, ri[2:0], ci[2:0]};

endmodule

