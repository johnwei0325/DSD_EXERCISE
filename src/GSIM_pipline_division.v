`timescale 1ns/10ps
module GSIM ( clk, reset, in_en, b_in, out_valid, x_out);
input   clk ;
input   reset;    // Active-high reset
input   in_en;
output  out_valid;
input   [15:0]  b_in;
output  [31:0]  x_out;

parameter RUN = 70;
// State definitions
parameter I_IDLE = 3'b000;      // Initial idle state
parameter I_RECEIVE = 3'b001;   // Receive input data state
parameter I_INIT = 3'b010;   // Computation state
parameter I_ITER = 3'b011;   // Iteration state
parameter I_COMPUTE_SUM = 3'b100;   // Compute sum state    
parameter I_COMPUTE_X = 3'b101;   // Compute x state
parameter I_SEND = 3'b110;      // Send output data state
parameter I_WAIT = 3'b111;      // Wait state
// State registers
reg [2:0] current_state, next_state;
reg [5:0] counter, next_counter;
reg signed [15:0] b_buffer [0:15];
reg signed [36:0] x_buffer [0:22];
reg out_valid_r, out_valid_w;
assign out_valid = out_valid_r;
reg [31:0] x_out_r, x_out_w;
reg signed [36:0] x_buffer_tmp_r, x_buffer_tmp_w;
assign x_out = x_out_r;
reg signed [36:0] divide_20_in_r, divide_20_in_w;
wire signed [31:0] divide_20_out;

divide_20 divide_20_inst(.clk(clk), .in(divide_20_in_r), .out(divide_20_out));

function signed [36:0] calculate_theta;
    input signed [36:0] a, b, c; // calculate a * 1 + b * -6 + c * 13
    reg signed [36:0] part_a, part_b, part_c;
    begin
        part_a = a;
        part_b = (b <<< 1) + (b <<< 2);
        part_c = (c <<< 3) + (c <<< 2) + c;
        calculate_theta = part_a - part_b + part_c;
    end
endfunction

reg [4:0] i_r, i_w, j_r, j_w, out_idx_r, out_idx_w;
reg [7:0] k_r, k_w;
reg signed [36:0] theta_r, theta_w;
reg wait_r, wait_w;
// Integer variables for loops
integer i;

// State machine
always @(posedge clk) begin
    if (reset) begin
        current_state <= I_IDLE;
        counter <= 0;
        out_valid_r <= 0;
        i_r <= 0;
        j_r <= 0;
        k_r <= 0;
        theta_r <= 0;
        x_out_r <= 0;
        out_idx_r <= 0;
        x_buffer_tmp_r <= 0;
        for (i = 0; i < 22; i = i + 1) begin
            x_buffer[i] <= 0;
        end
        divide_20_in_r <= 0;
        wait_r <= 1;
    end else begin
        current_state <= next_state;
        counter <= next_counter;
        b_buffer[counter] <= current_state == I_RECEIVE ? b_in : b_buffer[counter];
        i_r <= i_w;
        j_r <= j_w;
        k_r <= k_w;
        theta_r <= theta_w;
        out_valid_r <= out_valid_w;
        x_buffer[out_idx_w + 3] <= x_buffer_tmp_w;
        x_out_r <= x_out_w;
        out_idx_r <= out_idx_w;
        x_buffer_tmp_r <= x_buffer_tmp_w;
        divide_20_in_r <= divide_20_in_w;
        wait_r <= wait_w;
    end
end

// Next state logic
always @(*) begin
    next_counter = counter;
    next_state = current_state;
    i_w = i_r;
    j_w = j_r;
    k_w = k_r;
    theta_w = theta_r;
    out_valid_w = out_valid_r;
    x_out_w = x_out_r;
    out_idx_w = out_idx_r;
    x_buffer_tmp_w = x_buffer_tmp_r;
    divide_20_in_w = divide_20_in_r;
    wait_w = wait_r;

    case (current_state)
        I_IDLE: begin
            next_state = I_RECEIVE;
        end
        
        I_RECEIVE: begin
            if(in_en) begin
                // b_buffer_tmp = b_in;
                next_counter = counter + 1;
                if (counter == 15) begin 
                    next_state = I_INIT;
                end else begin
                    next_state = I_RECEIVE;
                end
            end
        end
        
        I_INIT: begin
            if (counter > 0) begin
                out_idx_w = counter;
                if (counter < 16) begin
                    if (wait_r) begin
                        divide_20_in_w = $signed((b_buffer[counter] <<< 16) - theta_r);
                        wait_w = 0;
                    end else begin
                        x_buffer_tmp_w = divide_20_out;
                        wait_w = 1;
                        next_counter = counter - 1;
                    end
                end else begin
                    x_buffer_tmp_w = 0;
                    next_counter = counter - 1;
                end
                next_state = I_INIT;
            end else begin
                out_idx_w = 0;
                if (wait_r) begin
                    wait_w = 0;
                    divide_20_in_w = (b_buffer[0] <<< 16);
                end else begin
                    x_buffer_tmp_w = divide_20_out;
                    wait_w = 1;
                end
                next_state = I_ITER;
            end
        end

        I_ITER: begin
            if (k_r < RUN) begin
                next_state = I_COMPUTE_SUM;
                i_w = 0;
            end else begin
                next_state = I_SEND;
            end
        end

        I_COMPUTE_SUM: begin
            if (i_r < 16) begin
                next_state = I_COMPUTE_X;
                theta_w = 0;
                j_w = 0;
            end else begin
                next_state = I_ITER;
                k_w = k_r + 16'b1;
            end
        end

        I_COMPUTE_X: begin
            if (j_r == 0) begin
                theta_w = calculate_theta(($signed(x_buffer[i_r])+$signed(x_buffer[i_r + 6])), ($signed(x_buffer[i_r +1] + $signed(x_buffer[i_r + 5]))), ($signed(x_buffer[i_r + 2] + $signed(x_buffer[i_r + 4]))));
                next_state = I_COMPUTE_X;
                j_w = j_r + 16'b1;
            end else begin
                if (wait_r) begin
                    divide_20_in_w = $signed((b_buffer[i_r] <<< 16) + theta_r);
                    wait_w = 0;
                end else begin
                    x_buffer_tmp_w = divide_20_out;
                    wait_w = 1;
                    i_w = i_r +16'b1;
                    out_idx_w = i_r;
                end
                next_state = I_COMPUTE_SUM;
            end
        end
        
        I_SEND: begin
            x_out_w = x_buffer[counter + 3][31:0];
            out_valid_w = 1;
            next_counter = counter + 1;
            if (counter == 17) begin
                next_state = I_IDLE;
                out_valid_w = 0;
            end else begin
                next_state = I_SEND;
            end
        end
        
        default: next_state = I_IDLE;
    endcase
end
endmodule

module divide_20(clk, in, out);
    input clk;
    input signed [36:0] in;
    output signed [31:0] out;
    wire signed [36:0] divide_20;
    wire signed [36:0] x_5, x_6, x_9, x_10, x_13, x_14, x_17, x_18, x_21, x_22, x_25, x_26, x_29, x_30, x_33, x_34;
    wire signed [36:0] x_5_6, x_9_10, x_13_14, x_17_18, x_21_22, x_25_26, x_29_30, x_33_34;
    reg signed [36:0] x_5_6_9_10_r, x_13_14_17_18_r, x_21_22_25_26_r, x_29_30_33_34_r;
    wire signed [36:0] x_5_6_9_10_w, x_13_14_17_18_w, x_21_22_25_26_w, x_29_30_33_34_w;
    wire signed [36:0] x_5_6_9_10_13_14_17_18, x_21_22_25_26_29_30_33_34;
    wire signed [36:0] x_total;

    assign x_5 = in;
    assign x_6 = in >>> 1;
    assign x_9 = in >>> 4;
    assign x_10 = in >>> 5;
    assign x_13 = in >>> 8;
    assign x_14 = in >>> 9;
    assign x_17 = in >>> 12;
    assign x_18 = in >>> 13;
    assign x_21 = in >>> 16;
    assign x_22 = in >>> 17;
    assign x_25 = in >>> 20;
    assign x_26 = in >>> 21;
    assign x_29 = in >>> 24;
    assign x_30 = in >>> 25;
    assign x_33 = in >>> 28;
    assign x_34 = in >>> 29;
    assign x_5_6 = x_5 + x_6;
    assign x_9_10 = x_9 + x_10;
    assign x_13_14 = x_13 + x_14;
    assign x_17_18 = x_17 + x_18;
    assign x_21_22 = x_21 + x_22;
    assign x_25_26 = x_25 + x_26;
    assign x_29_30 = x_29 + x_30;
    assign x_33_34 = x_33 + x_34;
    assign x_5_6_9_10_w = x_5_6 + x_9_10;
    assign x_13_14_17_18_w = x_13_14 + x_17_18;
    assign x_21_22_25_26_w = x_21_22 + x_25_26;
    assign x_29_30_33_34_w = x_29_30 + x_33_34;
    assign x_5_6_9_10_13_14_17_18 = x_5_6_9_10_r + x_13_14_17_18_r;
    assign x_21_22_25_26_29_30_33_34 = x_21_22_25_26_r + x_29_30_33_34_r;
    assign x_total = x_5_6_9_10_13_14_17_18 + x_21_22_25_26_29_30_33_34;
    assign out = x_total[36:5] + x_total[4];

    always @(posedge clk) begin
        x_5_6_9_10_r <= x_5_6_9_10_w;
        x_13_14_17_18_r <= x_13_14_17_18_w;
        x_21_22_25_26_r <= x_21_22_25_26_w;
        x_29_30_33_34_r <= x_29_30_33_34_w;
    end
endmodule
