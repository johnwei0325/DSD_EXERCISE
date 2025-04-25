`timescale 1ns/10ps
module GSIM ( clk, reset, in_en, b_in, out_valid, x_out);
input   clk ;
input   reset;    // Active-high reset
input   in_en;
output  out_valid;
input   [15:0]  b_in;
output  [31:0]  x_out;

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
reg signed [50:0] x_buffer [0:15];
reg out_valid_r, out_valid_w;
assign out_valid = out_valid_r;
reg [31:0] x_out_r, x_out_w;
reg signed [50:0] x_buffer_tmp_r, x_buffer_tmp_w;
assign x_out = x_out_r;

function signed [47:0] divide_20; //0.05 ≈ 0.000011001100110011001100110011
    input signed [47:0] in;
    reg signed [47:0] temp;
    begin
        temp = in;
        divide_20 = (temp >>> 5) + (temp >>> 6) + (temp >>> 9) + (temp >>> 10) + 
                   (temp >>> 13) + (temp >>> 14) + (temp >>> 17) + (temp >>> 18) + 
                   (temp >>> 21) + (temp >>> 22) + (temp >>> 25) + (temp >>> 26) + 
                   (temp >>> 29) + (temp >>> 30);
        // $display("divide_20: in=%d, result=%d", in, divide_20);
    end
endfunction

function signed [47:0] calculate_theta;
    input signed [47:0] a, b, c; // calculate a * 1 + b * -6 + c * 13
    reg signed [47:0] part_a, part_b, part_c;
    begin
        // $display("a: %d, b: %d, c: %d", a, b, c);
        part_a = a;
        part_b = (b <<< 1) + (b <<< 2);
        part_c = (c <<< 3) + (c <<< 2) + c;
        calculate_theta = (-part_a + part_b - part_c);
        // $display("calculate_theta: %d", calculate_theta);
    end
endfunction
// Declare A as a 2D array
reg signed [7:0] A [0:15][0:15];

reg [4:0] i_r, i_w, j_r, j_w, out_idx_r, out_idx_w, flag_r, flag_w;
reg [7:0] k_r, k_w;
reg signed [47:0] theta_r, theta_w, theta_w_tmp;
wire [47:0] mult_result;
assign mult_result = A[i_r][j_r] * x_buffer[j_r];
wire signed [47:0] numerator = (b_buffer[i_r] <<< 16) - theta_r;

// Integer variables for loops
integer i, j;

// Initialize matrix A during reset
always @(posedge clk) begin
    if (reset) begin
        // Zero all entries first
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                A[i][j] <= 0;

        // Fill the banded values
        for (i = 0; i < 16; i = i + 1) begin
            if (i >= 3) A[i][i-3] <= -1;
            if (i >= 2) A[i][i-2] <= 6;
            if (i >= 1) A[i][i-1] <= -13;
            A[i][i]   <= 20;
            if (i <= 14) A[i][i+1] <= -13;
            if (i <= 13) A[i][i+2] <= 6;
            if (i <= 12) A[i][i+3] <= -1;
        end
        
        // // Print matrix A in a nice format
        // $display("\nMatrix A:");
        // $display("--------------------------------------------------");
        // for (i = 0; i < 16; i = i + 1) begin
        //     $write("|");
        //     for (j = 0; j < 16; j = j + 1) begin
        //         if (A[i][j] >= 0) $write(" %2d ", A[i][j]);
        //         else $write("%3d ", A[i][j]);
        //     end
        //     $display("|");
        // end
        // $display("--------------------------------------------------\n");
    end
end

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
        flag_r <= 0;
        x_buffer_tmp_r <= 0;
    end else begin
        current_state <= next_state;
        counter <= next_counter;
        b_buffer[counter] <= current_state == I_RECEIVE ? b_in : b_buffer[counter];
        i_r <= i_w;
        j_r <= j_w;
        k_r <= k_w;
        theta_r <= theta_w;
        out_valid_r <= out_valid_w;
        // b_buffer_tmp <= b_in;
        x_buffer[out_idx_w] <= flag_r ? x_buffer_tmp_w : x_buffer[out_idx_w];
        x_out_r <= x_out_w;
        out_idx_r <= out_idx_w;
        flag_r <= flag_w;
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
    flag_w = flag_r;
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
                x_buffer_tmp_w = divide_20(($signed((b_buffer[counter] <<< 16) - theta_r)));
                flag_w = 1;
                next_counter = counter - 1;
                next_state = I_INIT;
            end else begin
                // x_buffer[0] = (b_buffer[0] <<< 16) / A[0][0];
                out_idx_w = 0;
                // x_buffer_tmp_w = (b_buffer[0] <<< 16) / A[0][0];
                x_buffer_tmp_w = divide_20((b_buffer[0] <<< 16));
                flag_w = 1;
                next_state = I_ITER;
            end
        end

        I_ITER: begin
            flag_w = 0;
            if (k_r < 50) begin
                next_state = I_COMPUTE_SUM;
                i_w = 0;
            end else begin
                next_state = I_SEND;
            end
        end

        I_COMPUTE_SUM: begin
            flag_w = 0;
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
            // if (j_r < 16) begin
            //     flag_w = 0;
            //     if (i_r != j_r) begin
            //         theta_w = theta_r + $signed(A[i_r][j_r]) * $signed(x_buffer[j_r]);
            //     end else begin
            //         theta_w = theta_r;
            //     end
            //     j_w = j_r + 16'b1;
            //     next_state = I_COMPUTE_X;
            // end else begin
            //     next_state = I_COMPUTE_SUM;
            //     i_w = i_r + 16'b1;
            //     flag_w = 1;
            //     // x_buffer[i_r] = $signed((b_buffer[i_r] <<< 16) - theta_r) / $signed(A[i_r][i_r]);
            //     out_idx_w = i_r;
            //     // x_buffer_tmp_w = $signed((b_buffer[i_r] <<< 16) - theta_r) / $signed(A[i_r][i_r]);
            //     if (i_r < 13 && i_r > 2) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r - 3])+$signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r - 2] + $signed(x_buffer[i_r + 2]))), ($signed(x_buffer[i_r - 1] + $signed(x_buffer[i_r + 1]))));
            //     end else if (i_r == 2) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r + 2])+$signed(x_buffer[i_r - 2])), ($signed(x_buffer[i_r + 1])+$signed(x_buffer[i_r - 1])));
            //     end else if (i_r == 1) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r + 2])), ($signed(x_buffer[i_r + 1])+$signed(x_buffer[i_r - 1])));
            //     end else if (i_r == 0) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r + 2])), ($signed(x_buffer[i_r + 1])));
            //     end else if (i_r == 13) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r - 3])), ($signed(x_buffer[i_r - 2])+$signed(x_buffer[i_r + 2])), ($signed(x_buffer[i_r - 1])+$signed(x_buffer[i_r + 1])));
            //     end else if (i_r == 14) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r - 3])), ($signed(x_buffer[i_r - 2])), ($signed(x_buffer[i_r - 1])+$signed(x_buffer[i_r + 1])));
            //     end else if (i_r == 15) begin
            //         theta_w_tmp = calculate_theta(($signed(x_buffer[i_r - 3])), ($signed(x_buffer[i_r - 2])), ($signed(x_buffer[i_r - 1])));
            //     end
            //     if (theta_w_tmp != theta_r) begin
            //         $display("i_r: %d, theta_w_tmp: %d, theta_r: %d", i_r, theta_w_tmp, theta_r);
            //     end
            //     x_buffer_tmp_w = divide_20($signed((b_buffer[i_r] <<< 16) - theta_w_tmp));
            // end
            if (j_r == 0) begin
                flag_w = 0;
                if (i_r < 13 && i_r > 2) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r - 3])+$signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r - 2] + $signed(x_buffer[i_r + 2]))), ($signed(x_buffer[i_r - 1] + $signed(x_buffer[i_r + 1]))));
                end else if (i_r == 2) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r + 2])+$signed(x_buffer[i_r - 2])), ($signed(x_buffer[i_r + 1])+$signed(x_buffer[i_r - 1])));
                end else if (i_r == 1) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r + 2])), ($signed(x_buffer[i_r + 1])+$signed(x_buffer[i_r - 1])));
                end else if (i_r == 0) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r + 3])), ($signed(x_buffer[i_r + 2])), ($signed(x_buffer[i_r + 1])));
                end else if (i_r == 13) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r - 3])), ($signed(x_buffer[i_r - 2])+$signed(x_buffer[i_r + 2])), ($signed(x_buffer[i_r - 1])+$signed(x_buffer[i_r + 1])));
                end else if (i_r == 14) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r - 3])), ($signed(x_buffer[i_r - 2])), ($signed(x_buffer[i_r - 1])+$signed(x_buffer[i_r + 1])));
                end else if (i_r == 15) begin
                    theta_w = calculate_theta(($signed(x_buffer[i_r - 3])), ($signed(x_buffer[i_r - 2])), ($signed(x_buffer[i_r - 1])));
                end
                next_state = I_COMPUTE_X;
                j_w = j_r + 16'b1;
            end else begin
                x_buffer_tmp_w = divide_20($signed((b_buffer[i_r] <<< 16) - theta_r));
                flag_w = 1;
                next_state = I_COMPUTE_SUM;
                i_w = i_r +16'b1;
                out_idx_w = i_r;
            end
        end
        
        I_SEND: begin
            x_out_w = x_buffer[counter][31:0];
            // $display("x_out_w: %d, counter: %d", x_out_w, counter);
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
