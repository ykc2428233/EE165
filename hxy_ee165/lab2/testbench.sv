module tn_fifo ();
  parameter N_ADDR_BITS=2, FIFO_WIDTH=2;
  logic reset, rd_en, wr_en, clk, fifo_empty, fifo_full;
  logic[FIFO_WIDTH-1:0] wr_data, fifo_rd_data;
  
  //reference module
  parameter n_flops = 1 << N_ADDR_BITS;
  logic [FIFO_WIDTH-1:0] flops [n_flops-1:0], rm_rd_data, full, empty;
  //logic [3:0] count;
  int n_items;

  
  fifo F (
    .reset(reset),
    .rd_en(rd_en),
    .wr_en(wr_en),
    .clk(clk),
    .empty(fifo_empty),
    .full(fifo_full),
    .rd_data(fifo_rd_data),
    .wr_data(wr_data)
  );
  
  //reference
  always_ff @(posedge clk)
  begin
    if (reset)
    begin
      flops[0] <= 2'b00;
      flops[1] <= 2'b00;
      flops[2] <= 2'b00;
      flops[3] <= 2'b00;
      n_items = 0;
    end
    else if (wr_en && !full)
    begin
      flops[0] <= wr_data;
      flops[1] <= flops[0];
      flops[2] <= flops[1];
      flops[3] <= flops[2];
      n_items <= n_items + 1;
    end
    else if (rd_en && !empty)
    begin
      n_items <= n_items - 1;
    end
  end
  
  always_comb
  begin
    if(!empty) rm_rd_data = flops[n_items-1];
    if (n_items == 0) begin
      empty = 1;
    end
    else begin
      empty = 0;
    end
    if (n_items == 4) begin
      full = 1;
    end
    else begin
      full = 0;
    end
  end
  
  initial
  begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  
  initial forever #10 clk = ~clk;
  
  function logic[FIFO_WIDTH-1:0] get_data();
    return $random;
  endfunction: get_data
  
  initial
  begin
    clk = 0;
    reset = 1;
    rd_en = 0;
    wr_en = 0;
    @(negedge clk);
    @(negedge clk);
    reset = 0;
    
    repeat (6)
    begin
      wr_en = 1;
      repeat (3)
      begin
        wr_data=get_data();
        @(negedge clk);
      end
      wr_en = 0;
      rd_en = 1;
      repeat (2)
      begin
        wr_data=get_data();
        @(negedge clk);
      end
      rd_en = 0;
    end
    $stop;
  end
  scoreboard_checker: assert property (
    @(posedge clk) rm_rd_data===fifo_rd_data
  ) //$display("T=%0t: correct", $time);
    else $strobe ("T=%0t: SB=%0x, DUT=%0x", $time, rm_rd_data, fifo_rd_data);
  scoreboard_checker1: assert property (
    @(posedge clk) empty===fifo_empty
  ) //$display("T=%0t: correct full/empty", $time);
    else $strobe ("T=%0t: SB_full=%0u, DUT_full=%0u", $time, full, fifo_full);
  scoreboard_checker2: assert property (
    @(posedge clk) empty===fifo_empty
  ) //$display("T=%0t: correct full/empty", $time);
    else $strobe ("T=%0t: SB_empty=%0u, DUT_empty=%0u", $time, empty, fifo_empty);
endmodule