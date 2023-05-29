module fifo #(parameter type DATA_TYPE=logic[1:0], parameter N_ADDR_BITS=2)
	(input logic reset, rd_en, wr_en, clk,
	 input DATA_TYPE wr_data,
	 output logic empty, full,
	 output DATA_TYPE rd_data);
    parameter FIFO_DEPTH = 1 << N_ADDR_BITS;
    DATA_TYPE fifo_mem[FIFO_DEPTH-1:0];	
    logic [N_ADDR_BITS:0] rd_ptr, wr_ptr;

    always_ff @(posedge clk)
    begin
	  if (reset)
      begin
        rd_ptr <= 0;
        wr_ptr <= 0;
        fifo_mem[0] <= 2'b00;
        fifo_mem[1] <= 2'b00;
        fifo_mem[2] <= 2'b00;
        fifo_mem[3] <= 2'b00;
        fifo_mem[4] <= 2'b00;
        fifo_mem[5] <= 2'b00;
        fifo_mem[6] <= 2'b00;
        fifo_mem[7] <= 2'b00;
      end
      else if (wr_en && !full)
      begin
        fifo_mem[wr_ptr[1:0]] <= wr_data;
        if (wr_ptr < 3'b111)
        begin
          wr_ptr <= wr_ptr + 1;
        end
        else if (wr_ptr == 3'b111)
        begin
          wr_ptr <= 3'b000;
        end
      end
      else if (rd_en && !empty) 
      begin
        rd_data <= fifo_mem[rd_ptr[1:0]];
        if (rd_ptr < 3'b111)
        begin
          rd_ptr <= rd_ptr + 1;
        end
        else if (rd_ptr == 3'b111)
        begin
          rd_ptr <= 3'b000;
        end
      end
    end
    always_comb
    begin
      empty = (rd_ptr[2:0] == wr_ptr[2:0]);
      full = (rd_ptr[1:0] == wr_ptr[1:0]) && (rd_ptr[2] != wr_ptr[2]);     
    end
endmodule