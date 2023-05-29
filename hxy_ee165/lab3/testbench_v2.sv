// Code your testbench here
// or browse Examples
module tn_fifo ();
  parameter N_ADDR_BITS=2, FIFO_WIDTH=2;
  logic reset, rd_en, wr_en, clk, fifo_empty, fifo_full;
  logic[FIFO_WIDTH-1:0] wr_data, fifo_rd_data;
  
  //reference module
  parameter n_flops = 1 << N_ADDR_BITS;
  logic [FIFO_WIDTH-1:0] flops [n_flops-1:0], rm_rd_data;
  logic full, empty;
  //logic [3:0] count;
  int n_items;
  //int n_max=2**N_ADDR_BITS;
  //cover
  int perc, n_bins_cov, n_bins;

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
  
  //covergroup
  covergroup fifo_cov @(posedge clk);
    full_cp: coverpoint F.full;
    empty_cp: coverpoint F.empty;
    rp_cp: coverpoint F.rd_ptr;
    wp_cp: coverpoint F.wr_ptr;
    rp_wp: cross rp_cp, wp_cp;
  endgroup
  fifo_cov cov = new();
  
  //reference
  always_ff @(posedge clk)
  begin
    if (reset)
    begin
      n_items = 0;
    end
    /*
    if (wr_en && rd_en && !full && !empty) begin
      flops[0] <= wr_data;
      flops[1] <= flops[0];
      flops[2] <= flops[1];
      flops[3] <= flops[2];
    end
    else begin
      */
    if (wr_en && !full && !reset)
    begin
      flops[0] <= wr_data;
      flops[1] <= flops[0];
      flops[2] <= flops[1];
      flops[3] <= flops[2];
    end
    if (!full && !empty && wr_en && rd_en && !reset)
    begin
    end
    else if (wr_en && !full && !reset)
      n_items <= n_items + 1;
    else if (rd_en && !empty && !reset)
    begin
      n_items <= n_items - 1;
    end
    /*
    end
  */
  end
  
  always_comb
  begin
    if(!empty && n_items > 0) rm_rd_data = flops[n_items-1];
    else if (rd_en && wr_en && n_items == 0)
      rm_rd_data = flops[0];
    else if (!full && !empty && wr_en && rd_en)
      rm_rd_data = flops[n_items];
    if (n_items == 0) begin
      empty = 1;
    end
    else begin
      empty = 0;
    end
    if (n_items == n_flops) begin
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
    //@(negedge clk);
    reset = 0;
    
    wr_en = 1;
    rd_en = 1;
    repeat (10)
    begin
      wr_data=get_data();
      @(negedge clk);
    end
    
    repeat (10000)
    begin
      wr_en=$urandom_range(1);
      rd_en=$urandom_range(1);
      wr_data=get_data();
      @(negedge clk);
    end
    
    wr_en = 0;
    rd_en = 1;
    repeat (2)
    begin
      //wr_data=get_data();
      @(negedge clk);
    end
    wr_en = 1;
    rd_en = 0;
    repeat (5)
    begin
      wr_data=get_data();
      @(negedge clk);
    end
    wr_en = 1;
    rd_en = 1;
    repeat (2)
    begin
      wr_data=get_data();
      @(negedge clk);
    end
    wr_en = 0;
    rd_en = 1;
    repeat (3)
    begin
      //wr_data=get_data();
      @(negedge clk);
    end
    
    
    /*
    full_cp = full;
    empty_cp = empty;
    */
    cov.sample();
    perc = cov.full_cp.get_inst_coverage(n_bins_cov, n_bins);
    $display ("full signal coverage = %0d%%: %0d / %0d bins", perc,n_bins_cov, n_bins);
    perc = cov.empty_cp.get_inst_coverage(n_bins_cov, n_bins);
    $display ("empty signal coverage = %0d%%: %0d / %0d bins", perc,n_bins_cov, n_bins);
    perc = cov.rp_cp.get_inst_coverage(n_bins_cov, n_bins);
    $display ("read pointer signal coverage = %0d%%: %0d / %0d bins", perc,n_bins_cov, n_bins);
    perc = cov.wp_cp.get_inst_coverage(n_bins_cov, n_bins);
    $display ("write pointer signal coverage = %0d%%: %0d / %0d bins", perc,n_bins_cov, n_bins);
    perc = cov.rp_wp.get_inst_coverage(n_bins_cov, n_bins);
    $display ("write-read cross signal coverage = %0d%%: %0d / %0d bins", perc,n_bins_cov, n_bins); 
  $stop;
  end
  
/*  
  scoreboard_checker: assert property (
    @(negedge clk) rm_rd_data===fifo_rd_data
  ) //$display("T=%0t: correct", $time);
    else $strobe ("T=%0t: SB=%0x, DUT=%0x", $time, rm_rd_data, fifo_rd_data);
  scoreboard_checker1: assert property (
    @(negedge clk) disable iff (reset)(full===fifo_full)
  ) //$display("T=%0t: correct full/empty", $time);
    else $strobe ("T=%0t: SB_full=%0u, DUT_full=%0u", $time, full, fifo_full);
  scoreboard_checker2: assert property (
    @(negedge clk) disable iff (reset)(empty===fifo_empty)
  ) //$display("T=%0t: correct full/empty", $time);
    else $strobe ("T=%0t: SB_empty=%0u, DUT_empty=%0u", $time, empty, fifo_empty);
    */
endmodule