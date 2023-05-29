// Code your design here
module fifo #(parameter type DATA_TYPE=logic[1:0], parameter N_ADDR_BITS=2)
	(input logic reset, rd_en, wr_en, clk,
	 input DATA_TYPE wr_data,
	 output logic empty, full,
	 output DATA_TYPE rd_data);
    parameter FIFO_DEPTH = 1 << N_ADDR_BITS;
    DATA_TYPE fifo_mem[FIFO_DEPTH-1:0];	
    logic [N_ADDR_BITS:0] rd_ptr, wr_ptr;
    parameter max_f = (1 << (N_ADDR_BITS+1))-1;
    parameter min_f = 0 << N_ADDR_BITS;
    always_ff @(posedge clk)
    begin
	  if (reset)
      begin
        rd_ptr <= min_f;
        wr_ptr <= min_f;
      end
      if (wr_en && !full && !reset)
      begin
        fifo_mem[wr_ptr[N_ADDR_BITS-1:0]] <= wr_data;
        if (wr_ptr < max_f)
        begin
          wr_ptr <= wr_ptr + 1;
        end
        else if (wr_ptr == max_f)
        begin
          wr_ptr <= min_f;
        end
      end
      if (rd_en && !empty && !reset) 
      begin
        if (rd_ptr < max_f)
        begin
          rd_ptr <= rd_ptr + 1;
        end
        else if (rd_ptr == max_f)
        begin
          rd_ptr <= min_f;
        end
      end
    end
    always_comb
    begin
      if (!empty) rd_data = fifo_mem[rd_ptr[N_ADDR_BITS-1:0]];
      empty = (rd_ptr[N_ADDR_BITS:0] == wr_ptr[N_ADDR_BITS:0]);
      full = (rd_ptr[N_ADDR_BITS-1:0] == wr_ptr[N_ADDR_BITS-1:0]) && (rd_ptr[N_ADDR_BITS] != wr_ptr[N_ADDR_BITS]);     
    end
endmodule