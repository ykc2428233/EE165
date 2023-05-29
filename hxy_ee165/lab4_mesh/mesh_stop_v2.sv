/*
 * The main mesh_stop module. It has code for a single mesh stop.
 */
module mesh_stop import mesh_defs::*; #(parameter MY_Y=0, MY_X=0)
	(input Ring_slot
		data_from_venv,	// data from the "rest of the MS" to us
		vert_ring_in,	// incoming vertical-ring data
		hori_ring_in,	// incoming horizontal-ring data
	 input logic reset, clk,
		venv_taking_data,	// Val env. is taking our data_to_venv
	 output Ring_slot
		data_to_venv,	// data from us to the "rest of the MS"
		vert_ring_out,	// drive vertical ring
		hori_ring_out,	// drive horizontal ring
         output logic data_avail_for_venv, can_accept_data_from_env);

  ////////////////////////////////////////////
  // Parameters for this mesh stop
  ////////////////////////////////////////////
  parameter N_FIFO_ADDR_BITS=2;	// So all FIFOs are 4 deep.

  ////////////////////////////////////////////
  // I/O signals for the three FIFOs.
  ////////////////////////////////////////////

  // FIFO buffering data_from_venv waiting to drive the mesh (Drv Fifo)
  Ring_slot DrvF_out;
  logic DrvF_rd_en, DrvF_wr_en, DrvF_empty, DrvF_full;

  // FIFO buffering incoming data from hori ring (HRx Fifo)
  Ring_slot HRxF_out;
  logic HRxF_rd_en, HRxF_wr_en, HRxF_empty, HRxF_full;
 
  // FIFO buffering incoming data from vert ring (VRx Fifo)
  Ring_slot VRxF_out;
  logic VRxF_rd_en, VRxF_wr_en, VRxF_empty, VRxF_full;

  ////////////////////////////////////////////
  // I/O signals for the mux selects and outputs
  ////////////////////////////////////////////

  // The mux-select lines are all still undriven -- you'll drive them in the
  // control logic.
  Ring_slot vert_mux_out, hori_mux_out;
  logic vert_sel_pass, vert_sel_me;
  logic hori_sel_pass, hori_sel_me, hori_sel_turn;
  logic dtvenv_sel_HRx_FIFO, dtvenv_sel_VRx_FIFO;

  ////////////////////////////////////////////
  // Datapath instantiation
  ////////////////////////////////////////////

   always_comb begin
    // Mux driving the vertical ring.
    unique if (vert_sel_pass)	vert_mux_out = vert_ring_in;
      else if (vert_sel_me)     vert_mux_out = DrvF_out;
      else 			vert_mux_out = EMPTY_RING_SLOT;
  
    // Mux driving the horizontal ring.
    unique if (hori_sel_pass)	hori_mux_out = hori_ring_in;
      else if (hori_sel_turn)   hori_mux_out = VRxF_out;
      else if (hori_sel_me)     hori_mux_out = DrvF_out;
      else 			hori_mux_out = EMPTY_RING_SLOT;
  
    // Mux driving this mesh stop's output to the verification environment
    // from the incoming vertical or horiz rings.
    unique if (dtvenv_sel_VRx_FIFO)	data_to_venv = VRxF_out;
      else if (dtvenv_sel_HRx_FIFO)	data_to_venv = HRxF_out;
      else 				data_to_venv = EMPTY_RING_SLOT;
  end	// always_comb

  // Flop the ring-driver-mux outputs
  always_ff @(posedge clk) begin
    if (reset) begin
	vert_ring_out <= EMPTY_RING_SLOT;
	hori_ring_out <= EMPTY_RING_SLOT;
    end else begin
	vert_ring_out <= vert_mux_out;
	hori_ring_out <= hori_mux_out;
    end
  end	// always_ff

  // Instantiate VRx Fifo
  fifo #(.DATA_TYPE(Ring_slot), .N_ADDR_BITS(N_FIFO_ADDR_BITS))
    VRxF(.reset(reset), .clk(clk),
	.wr_en(VRxF_wr_en), .rd_en(VRxF_rd_en),
	.wr_data(vert_ring_in), .rd_data(VRxF_out),
	.empty(VRxF_empty), .full(VRxF_full));

  // Instantiate HRx Fifo
  fifo #(.DATA_TYPE(Ring_slot), .N_ADDR_BITS(N_FIFO_ADDR_BITS))
    HRxF(.reset(reset), .clk(clk),
	.wr_en(HRxF_wr_en), .rd_en(HRxF_rd_en),
	.wr_data(hori_ring_in), .rd_data(HRxF_out),
	.empty(HRxF_empty), .full(HRxF_full));

  // Instantiate Drv Fifo
  fifo #(.DATA_TYPE(Ring_slot), .N_ADDR_BITS(N_FIFO_ADDR_BITS))
    DRV(.reset(reset), .clk(clk),
	.wr_en(DrvF_wr_en), .rd_en(DrvF_rd_en),
	.wr_data(data_from_venv), .rd_data(DrvF_out),
	.empty(DrvF_empty), .full(DrvF_full));

  ////////////////////////////////////////////
  // Control logic
  ////////////////////////////////////////////
  
  //Drv_FIFO
  always_comb begin
    if (DrvF_full) begin
      DrvF_wr_en = 0;
    end
    else begin
      DrvF_wr_en = 1;
    end
    if (!DrvF_empty) begin
      if ((!vert_sel_pass) || (!hori_sel_pass)) begin
        DrvF_rd_en = 1;
      end
    end
    else begin
      DrvF_rd_en = 0;
    end
  end

  //HR_FIFO
  always_comb begin
    if ((HRxF_full) || (hori_sel_pass)) begin
      HRxF_wr_en = 0;
    end
    else begin
      HRxF_wr_en = 1;
    end
    if (!HRxF_empty) begin
      HRxF_rd_en = 1;
    end
    else begin
      HRxF_rd_en = 0;
    end
  end

  //VR_FIFO
  always_comb begin
    if ((VRxF_full) || (vert_sel_pass)) begin
      VRxF_wr_en = 0;
    end
    else begin
      VRxF_wr_en = 1;
    end
    if ((!dtvenv_sel_HRx_FIFO) || ((!hori_sel_pass) && (!hori_sel_me))) begin
      VRxf_rd_en = 1;
    end
    else begin
      VRxf_rd_en = 0;
    end
  end

  //vert_MUX
  always_comb begin
    if (vert_ring_in.valid) begin
      if (vert_ring_in.dst_y != MY_Y) begin
        vert_sel_pass = 1;
      end
    end
    else if ((!DrvF_empty) && (DrvF_out.valid)) begin
      if (DrvF_out.dst_y != MY_Y) begin
        vert_sel_me = 1;
      end
    end
    else begin
      vert_sel_pass = 0;
      vert_sel_me = 0;
    end
  end
  
  //hori_MUX
  always_comb begin
    if (hori_ring_in.valid) begin
      if (hori_ring_in.dst_x != MY_X) begin
        hori_sel_pass = 1;
      end
    end
    else if (VRxF_out.valid) begin
      if (VRxF_out.dst_x != MY_X) begin
        hori_sel_turn = 1;
      end
    end
    else if (DrvF_out.valid) begin
      if (DrvF_out.dst_x != MY_X) begin
        hori_sel_me = 1;
      end
    end
    else begin
      hori_sel_pass = 0;
      hori_sel_turn = 0;
      hori_sel_me = 0;
    end
  end
  
  //me_MUX
  always_comb begin
    if (HRxF_out.valid) begin
      if ((HRxF_out.dst_x == MY_X) && (HRxF_out.dst_y == MY_Y)) begin
        dtvenv_sel_HRx_FIFO = 1;
      end
    end
    else if (VRxF_out.valid) begin
      if ((VRxF_out.dst_x == MY_X) && (VRxF_out.dst_y == MY_Y)) begin
        dtvenv_sel_VRx_FIFO = 1;
      end
    end
    else begin
      dtvenv_sel_HRx_FIFO = 0;
      dtvenv_sel_VRx_FIFO = 0;
    end
  end
endmodule
