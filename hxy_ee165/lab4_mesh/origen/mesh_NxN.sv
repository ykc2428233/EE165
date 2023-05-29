import mesh_defs::*;

module mesh_NxN #(parameter N=2)
    (input Ring_slot
	data_from_venv[N][N],// data from the "rest of the MS" to us
     input logic reset, clk,
	venv_taking_data[N][N],// Val env. is taking our data_to_venv
     output Ring_slot
	data_to_venv[N][N],	// data from us to the "rest of the MS"
     output logic data_avail_for_venv[N][N], can_accept_data_from_env[N][N]);

  // ALL INDICES IN THIS FILE ARE TREATED AS Y,X LOCATIONS (I.E., ROW,COLUMN),
  // WHICH IS HOW MATRICES AND 2D ARRAYS USUALLY WORK.
  // BUT IT IS NOT HOW COORDINATES ARE USUALLY GIVEN IN GEOMETRY.

  ////////////////////////////////////////////
  // Declare the ring signals.
  ////////////////////////////////////////////
  Ring_slot vert_ring[N][N],
	    hori_ring[N][N];

  ////////////////////////////////////////////
  // Instantiantiate the NxN array of mesh stops
  ////////////////////////////////////////////

  // See https://stackoverflow.com/questions/12504837/
  // verilog-generate-genvar-in-an-always-block
  generate
    genvar x, y;
    for (y=0; y<N; ++y) begin : yloop
	for (x=0; x<N; ++x) begin: xloop
	    // We're building the instance, e.g., yloop[2].xloop[1].MS
	    mesh_stop #(.MY_Y(y), .MY_X(x)) MS (
		.reset(reset), .clk(clk),
		.data_from_venv(data_from_venv[y][x]),
		.data_to_venv(data_to_venv[y][x]),
		.data_avail_for_venv(data_avail_for_venv[y][x]),
		.venv_taking_data(venv_taking_data[y][x]),
		.can_accept_data_from_env(can_accept_data_from_env[y][x]),
		.vert_ring_in (vert_ring[y][x]),
		.vert_ring_out(vert_ring[(y+1)%N][x]),
		.hori_ring_in (hori_ring[y][x]),
		.hori_ring_out(hori_ring[y][(x+1)%N]));
	end // for x
    end // for y
  endgenerate
endmodule
