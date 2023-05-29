module tn_fifo ();
  parameter N_ADDR_BITS=2, FIFO_WIDTH=2;
  logic reset, rd_en, wr_en, clk, fifo_empty, fifo_full;
  logic[FIFO_WIDTH-1:0] wr_data, rd_data;
  
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
    .rd_data(rd_data),
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
    rm_rd_data = flops[n_items];
    if (n_items == 0)
      empty = 1;
    else
      empty = 0;
    if (n_items == 4)
      full = 1;
    else
      full = 0;
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
  
endmodule