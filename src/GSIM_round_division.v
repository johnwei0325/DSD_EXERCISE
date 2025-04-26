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

function signed [31:0] divide_20; //0.05 ≈ 0.000011001100110011001100110011
    input signed [36:0] in;
    reg signed [36:0] temp;
    reg signed [36:0] temp2;
    begin
        temp = in;
        temp2 = temp + (temp >>> 1) + (temp >>> 4) + (temp >>> 5) + (temp >>> 8) + 
                   (temp >>> 9) + (temp >>> 12) + (temp >>> 13) + (temp >>> 16) + 
                   (temp >>> 17) + (temp >>> 20) + (temp >>> 21) + (temp >>> 24) + 
                   (temp >>> 25) + (temp >>> 28) + (temp >>> 29);
        // divide_20 = temp2[36:5] + temp2[4];
        divide_20 = (temp2 + 5'd16) >>> 5;
        // $display("temp2: %b, %b, %b", ((temp2 + 5'd16) >>> 5), temp2>>>5, temp2[36:5]);
    end
endfunction

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
                // x_buffer[counter] = $signed((b_buffer[counter] <<< 16) - theta_r) / $signed(A[counter][counter]);
                out_idx_w = counter;
                if (counter < 16) begin
                    x_buffer_tmp_w = divide_20(($signed((b_buffer[counter] <<< 16) - theta_r)));
                end else begin
                    x_buffer_tmp_w = 0;
                end
                next_counter = counter - 1;
                next_state = I_INIT;
            end else begin
                // x_buffer[0] = (b_buffer[0] <<< 16) / A[0][0];
                out_idx_w = 0;
                // x_buffer_tmp_w = (b_buffer[0] <<< 16) / A[0][0];
                x_buffer_tmp_w = divide_20((b_buffer[0] <<< 16));
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
                // $display("i_r: %d, %d, %d, %d, %d, %d, %d", i_r, x_buffer[i_r], x_buffer[i_r + 1], x_buffer[i_r + 2], x_buffer[i_r + 4], x_buffer[i_r + 5], x_buffer[i_r + 6]);
                theta_w = calculate_theta(($signed(x_buffer[i_r])+$signed(x_buffer[i_r + 6])), ($signed(x_buffer[i_r +1] + $signed(x_buffer[i_r + 5]))), ($signed(x_buffer[i_r + 2] + $signed(x_buffer[i_r + 4]))));
                next_state = I_COMPUTE_X;
                j_w = j_r + 16'b1;
            end else begin
                x_buffer_tmp_w = divide_20($signed((b_buffer[i_r] <<< 16) + theta_r));
                next_state = I_COMPUTE_SUM;
                i_w = i_r +16'b1;
                out_idx_w = i_r;
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
