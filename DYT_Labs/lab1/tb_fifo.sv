module tb_fifo;
  parameter N_ADDR_BITS=2, FIFO_WIDTH=4;
  logic reset, rd_en, wr_en, clk, fifo_empty, fifo_full;
  logic[1:0] wr_data, fifo_rd_data;
  logic[2:0] wr_ptr, rd_ptr;

  // Instantiate the FIFO.
  fifo F(
    .reset(reset),
    .rd_en(rd_en),
    .wr_en(wr_en),
    .clk(clk),
    .empty(fifo_empty),
    .full(fifo_full),
    .rd_data(fifo_rd_data),
    .wr_data(wr_data),
    .wr_ptr(wr_ptr),
    .rd_ptr(rd_ptr)
  );

  // Drive the main clock
  initial begin
      $dumpfile("dump.vcd");
      $dumpvars();

      // The clock starts at 0 and toggles every 10 time units.
      clk = 0;
      forever begin	// eventually "tester" will call $stop to end the sim.
	   #10 clk = ~clk;
      end
  end

  // A function to choose & return random FIFO-input data.
  function logic[1:0] get_data();
      return $random;
  endfunction: get_data

  // The top-level tester routine.
  //	- Drive reset on & off.
  //	- Many loops of (pick operands; drive them; check results).
  initial begin : tester
      // Reset the system
      $display ("Starting the sim!");
      reset = 1'b1;
      @(negedge clk);
      reset = 1'b0;
      // Drive the simulation with 10 cycles of driving wr_data with new
      // random data. This simple testbench both reads and writes every cycle.
    repeat (10) begin
        wr_en = 1;
        rd_en = 1;
        wr_data = get_data();
        @(negedge clk);
      end

    repeat (3) begin
        wr_en = 0;
        rd_en = 1;
        wr_data = get_data();
        @(negedge clk);
      end
    
    repeat (5) begin
        wr_en = 1;
        rd_en = 0;
        wr_data = get_data();
        @(negedge clk);
      end
      // The $stop is not to stop *this* block (which would just run to its end
      // and finish), but rather to stop the "always" blocks above.
      $stop;
  end : tester
endmodule : tb_fifo