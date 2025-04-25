`timescale 1ns/1ps
module tb;
parameter N_PAT = 16;

reg   clk;
reg   reset;
reg   in_en;
reg   [15:0]  b_in;
wire  out_valid;
wire  [31:0]  x_out;

reg   [15:0]  pat_mem   [0:N_PAT-1];
reg   [31:0]  x         [0:N_PAT-1];
reg   [15:0]  b         [0:N_PAT-1];
reg   [15:0]  b_tmp;
integer       loop, i, j, out_f;
reg           stop;
real  Mb [0:15];
real  x_f[0:15];
real  SquareError, error, temp;

// Instantiate the design
GSIM u_GSIM(
    .clk(clk),
    .reset(reset),
    .in_en(in_en),
    .b_in(b_in),
    .out_valid(out_valid),
    .x_out(x_out)
);

// Clock generation
always #5 clk = ~clk;

// Initialize
initial begin
    clk = 0;
    reset = 0;
    in_en = 0;
    b_in = 'hz;
    stop = 0;
    loop = 0;
    
    // Load pattern from file
    $readmemh("pattern1.dat", pat_mem);
    
    // Display loaded pattern
    // $display("Loaded pattern:");
    // for (i = 0; i < N_PAT; i = i + 1) begin
    //     $display("pat_mem[%0d] = %h", i, pat_mem[i]);
    // end
end

// Test sequence
initial begin
    // Create waveform file
    $dumpfile("GSIM.vcd");
    $dumpvars;
    
    // Reset sequence
    #10 reset = 1;
    #20 reset = 0;
    
    // Wait for a few cycles
    #30;
    
    // Start sending data
    in_en = 1;
    for (i = 0; i < N_PAT; i = i + 1) begin
        b_in = pat_mem[i];
        #10;
    end
    in_en = 0;  
    b_in = 'hz;
end   
    
// Start receiving data
always @(negedge clk) begin
    if(loop <16) begin
        if(out_valid) begin
            x[loop]=x_out;
            $display("receiving data x[%0d] = %d", loop, x[loop]);
            loop=loop+1;
        end
    end
    else begin
        stop=1;
    end
end
    
// Convert to floating point and display results
initial begin
    @(posedge stop) begin
        for (j = 0; j < N_PAT; j = j + 1) begin
            if (x[j][31] == 1) begin
                x_f[j] = ~x[j] + 1'b1;
                x_f[j] = -x_f[j]/65536;
            end else begin
                x_f[j] = x[j];
                x_f[j] = x_f[j]/65536;
            end
            $display("x[%0d] = %f", j, x_f[j]);
        end
    end
    #1000;
    $finish;
end

endmodule 