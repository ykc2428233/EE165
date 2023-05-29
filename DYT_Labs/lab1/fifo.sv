module fifo #(parameter type DATA_TYPE=logic[1:0], parameter N_ADDR_BITS=2)
	(input logic reset, rd_en, wr_en, clk,
	 input DATA_TYPE wr_data,
	 output logic empty, full,
     output logic[2:0] rd_ptr, wr_ptr,
	 output DATA_TYPE rd_data);
    parameter FIFO_DEPTH = 1 << N_ADDR_BITS;

    DATA_TYPE fifo_mem[FIFO_DEPTH-1:0];	


    always_ff @(posedge clk) begin	
      if(reset)
        begin
        rd_ptr <= 0;
        wr_ptr <= 0;
        fifo_mem[0] <= 0;
        fifo_mem[1] <= 0;
        fifo_mem[2] <= 0;
        fifo_mem[3] <= 0;
        end
      else if (wr_en && !full)
        begin
          fifo_mem[wr_ptr[1:0]] <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end
    end
        
    always_ff @(posedge clk) begin
      if (!reset && rd_en && !empty)
        begin
          rd_ptr <= rd_ptr + 1;
        end
    end
   
    always_comb begin
      empty = (wr_ptr==rd_ptr);
      full = ((wr_ptr[1:0]==rd_ptr[1:0])&&(wr_ptr[2]!=rd_ptr[2]));
      rd_data = fifo_mem[rd_ptr[1:0]];

    end
  
endmodule