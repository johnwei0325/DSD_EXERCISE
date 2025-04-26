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
        b[i]  = pat_mem[i];
        in_en = 1'b1;
        #10;
    end
    in_en = 0;  
    b_in = 'hz;
end   
    
// Start receiving data
always @(negedge clk)begin
   if(loop <16)begin
      if(out_valid)begin
         x[loop]=x_out;
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

initial begin
   @(posedge stop) 
     for (j=0;j<=15;j=j+1)begin
        if(x[j][31]==1) begin   x_f[j]=~x[j] +1'b1;    x_f[j] =-x_f[j]/65536;  end
        else            begin   x_f[j]= x[j];          x_f[j] = x_f[j]/65536;  end
     end
                          
     Mb[0 ]= 20*x_f[0 ]-13*x_f[1 ]+ 6*x_f[2 ]-   x_f[3 ];
     Mb[1 ]=-13*x_f[0 ]+20*x_f[1 ]-13*x_f[2 ]+ 6*x_f[3 ]-   x_f[4 ];
     Mb[2 ]=  6*x_f[0 ]-13*x_f[1 ]+20*x_f[2 ]-13*x_f[3 ]+ 6*x_f[4 ]-  x_f[5 ];      
     Mb[3 ]=   -x_f[0 ]+ 6*x_f[1 ]-13*x_f[2 ]+20*x_f[3 ]-13*x_f[4 ]+6*x_f[5 ]-x_f[6 ];      
     Mb[4 ]=   -x_f[1 ]+ 6*x_f[2 ]-13*x_f[3 ]+20*x_f[4 ]-13*x_f[5 ]+6*x_f[6 ]-x_f[7 ];
     Mb[5 ]=   -x_f[2 ]+ 6*x_f[3 ]-13*x_f[4 ]+20*x_f[5 ]-13*x_f[6 ]+6*x_f[7 ]-x_f[8 ];                    
     Mb[6 ]=   -x_f[3 ]+ 6*x_f[4 ]-13*x_f[5 ]+20*x_f[6 ]-13*x_f[7 ]+6*x_f[8 ]-x_f[9 ];
     Mb[7 ]=   -x_f[4 ]+ 6*x_f[5 ]-13*x_f[6 ]+20*x_f[7 ]-13*x_f[8 ]+6*x_f[9 ]-x_f[10];
     Mb[8 ]=   -x_f[5 ]+ 6*x_f[6 ]-13*x_f[7 ]+20*x_f[8 ]-13*x_f[9 ]+6*x_f[10]-x_f[11];
     Mb[9 ]=   -x_f[6 ]+ 6*x_f[7 ]-13*x_f[8 ]+20*x_f[9 ]-13*x_f[10]+6*x_f[11]-x_f[12];
     Mb[10]=   -x_f[7 ]+ 6*x_f[8 ]-13*x_f[9 ]+20*x_f[10]-13*x_f[11]+6*x_f[12]-x_f[13];
     Mb[11]=   -x_f[8 ]+ 6*x_f[9 ]-13*x_f[10]+20*x_f[11]-13*x_f[12]+6*x_f[13]-x_f[14];
     Mb[12]=   -x_f[9 ]+ 6*x_f[10]-13*x_f[11]+20*x_f[12]-13*x_f[13]+6*x_f[14]-x_f[15];     
     Mb[13]=   -x_f[10]+ 6*x_f[11]-13*x_f[12]+20*x_f[13]-13*x_f[14]+6*x_f[15];
     Mb[14]=   -x_f[11]+ 6*x_f[12]-13*x_f[13]+20*x_f[14]-13*x_f[15];
     Mb[15]=   -x_f[12]+ 6*x_f[13]-13*x_f[14]+20*x_f[15];   
        
     SquareError = 0;        
     
     for(j=0; j<=15; j=j+1)begin     	  
       	if(b[j][15]==1)begin 
       		b_tmp= ~b[j]+1;
       		temp = b_tmp;
       		error= temp + Mb[j];
       	end
       	else begin
       		error = Mb[j] - b[j];
       	end
       	//$display(" Loop=%d    error= %.15f  \n", j, error);
     	  SquareError = SquareError + error*error;
     end
                   
     $display("-----------------------------------------------------\n");
     $display("            Your Output              Golden X\n");
     $display("  X1:     %.10f            402.1120217501   \n", x_f[0 ]);
     $display("  X2:     %.10f           1689.5336804421   \n", x_f[1 ]);
     $display("  X3:     %.10f           2455.4774264763   \n", x_f[2 ]);
     $display("  X4:     %.10f            563.1671481130   \n", x_f[3 ]);
     $display("  X5:     %.10f            703.0136705772   \n", x_f[4 ]);
     $display("  X6:     %.10f           1745.1919122734   \n", x_f[5 ]);
     $display("  X7:     %.10f             33.2002351074   \n", x_f[6 ]);
     $display("  X8:     %.10f            607.1379155812   \n", x_f[7 ]);
     $display("  X9:     %.10f           -477.5895727426   \n", x_f[8 ]);
     $display(" X10:     %.10f            869.0943789319   \n", x_f[9 ]);
     $display(" X11:     %.10f           1907.5237775384   \n", x_f[10]);
     $display(" X12:     %.10f           1524.3408800767   \n", x_f[11]);
     $display(" X13:     %.10f            596.4154551345   \n", x_f[12]);
     $display(" X14:     %.10f           1476.6345624265   \n", x_f[13]);
     $display(" X15:     %.10f           1011.5707976786   \n", x_f[14]);
     $display(" X16:     %.10f          -1330.8985774801   \n", x_f[15]);          
     $display("-----------------------------------------------------\n");
     $display("So Your Error Ratio=  %.15f\n", SquareError);
     $display("-----------------------------------------------------\n");   
     
     error=SquareError;
     if(error<0.000001 && error!='hx && error!='hz)begin                           
         $display("Your Score Level: A \n");  
         $display("Congratulations! GSIM's Function Successfully!\n");
         $display("-------------------------PASS------------------------\n");
     end    
         
     else if(error>=0.000001 && error <0.000005 && error!='hx && error!='hz)begin
        $display("Your Score Level: B \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end
     else if(error>=0.000005 && error <0.000010 && error!='hx && error!='hz)begin
        $display("Your Score Level: C \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
     else if(error>=0.000010 && error <0.000050 && error!='hx && error!='hz)begin
        $display("Your Score Level: D \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
        
     else if(error>=0.000050 && error <0.000100 && error!='hx && error!='hz)begin
        $display("Your Score Level: E \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end     
     else if(error>=0.000100 && error <0.001000 && error!='hx && error!='hz)begin
        $display("Your Score Level: F \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
     else if(error>=0.001000 && error <0.005000 && error!='hx && error!='hz)begin
        $display("Your Score Level: G \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
     else if(error>=0.005000 && error <0.010000 && error!='hx && error!='hz)begin
        $display("Your Score Level: H \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
     else if(error>=0.010000 && error <0.100000 && error!='hx && error!='hz)begin
        $display("Your Score Level: I \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
     else if(error>=0.100000 && error <0.300000 && error!='hx && error!='hz)begin
        $display("Your Score Level: J \n");
        $display("Congratulations! GSIM's Function Successfully!\n");
        $display("-------------------------PASS------------------------\n");
     end 
     else begin
        $display("Your Score Level: K \n");                  
        $display("-------------   GSIM's Function Fail   -------------\n");
        $display("-------------------------Fail------------------------\n");
     end
      
      #5; $finish;
                       
end
endmodule 
