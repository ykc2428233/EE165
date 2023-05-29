/* This is the testbench for the final debug challenge.
 */

parameter MESH_SIZE=4;		// For a 4x4 mesh.

parameter N_PACKETS_TO_SEND=40;	// How long the test will be
parameter MAX_PACKETS_PER_CYCLE=10;
parameter HOW_OFTEN_TO_TARGET=10;//0-10; x/10 is the prob any packet is targeted
parameter TAKE_RES_FREQ=10;	// 0-10; x/10 is the prob/cycle the env. accepts
parameter LAUNCH_FREQ=20;	// x/10 is the # of packets launched/cycle
parameter DEAD_LINK_FREQ=0;	// 0-10; x/10 is the prob that any link is dead.

import mesh_defs::*;		// Some common functions & definitions

/* The Sim_control class contains all of the knobs that control our RCG. It has
 * various knobs to target (or not target) the destination of the packets. When
 * we are targeting (e.g.,) a particular row of the mesh, it remembers which
 * row we're targeting. When we instantiate a Sim_control, we give it all of
 * these knob values.
 * Sim_control is also our runtime random-packet generator. It has the smarts to
 * generate lots of packets, over and over, that fit the distribution that the
 * knobs tell it to.
 */
class Sim_control;
  // Modes:
  //	1. purely random with no targeting
  //	2. target a single row (and with lots of packets traveling along that
  //	   row, any MS trying to launch from that row will likely be starved).
  //	3. target a single MS (so that MS likely has to bounce incoming packets)
  typedef enum int { NO_TARGET=0, TARGET_ROW=1, TARGET_MS=2 } Main_mode;
  Main_mode mode;

  // When we target (e.g.,) a single MS, that doesn't mean *all* of the packets
  // aim for that MS. Some should still go elsewhere. This variable says how
  // often to target -- if, e.g., how_often_to_target=9 then 9/10 of packets
  // will be targeted and 1/10 will not be.
  int how_often_to_target;	// must be in [0,10]

  // How often to launch new packets. See n_packets_to_launch() for details.
  int launch_freq;		// must be in [0,10*MAX_PACKETS_PER_CYCLE]

  // Once the fabric has a result ready for us, (take_results_frac/10) is the
  // odds we take that result in any given cycle. So 10 -> take it immediately.
  int take_results_frac;	// must be in [0,10]

  // The actual targets for the modes TARGET_ROW and TARGET_MS.
  int tgt_y, tgt_x;		// must be in [0,MESH_SIZE)

  // 0=>links never dead, and 10=>"all" links dead
  int dead_link_freq;		// must be in [0,10]

  // Get set up (i.e., pick the main mode & the main parameters) for packets for
  // the remainder of the test. This function gets called once at the beginning
  // of the test.
  function new (Main_mode main_md, int how_oft, tak_res_f,launch_f,dead_link_f);
    assert ((how_oft>=0) && (how_oft<=10));
    assert ((tak_res_f>=0) && (tak_res_f<=10));
    assert (launch_f>=0);
    mode = main_md;
    how_often_to_target = how_oft;
    take_results_frac = tak_res_f;
    launch_freq = launch_f;
    dead_link_freq = dead_link_f;

    // Pick target row & column (though we may not use them).
    this.srandom(1);
    tgt_x = $urandom_range(MESH_SIZE-1);
    tgt_y = $urandom_range(MESH_SIZE-1);
    $display ("Targets are row=%0d, col=%0d", tgt_y, tgt_x);
  endfunction : new

  // Decide how many packets to launch this cycle, as per the knob launch_freq.
  // Some examples of how the knob works:
  //	launch_freq=20 -> launch 2 packets. And 30 -> 3 packets, 40 -> 4, etc.
  //	launch_freq=27 -> 70% odds for 3, 30% odds for 2.
  // So for LF in [20,30), odds of (LF-20)/10 for 3 and (1-that) for 2.
  function int n_packets_to_launch();
    int launch_floor, remainder, do_higher, how_many;
    launch_floor = launch_freq/10;	// these are integers, so it's a floor.
    remainder = launch_freq - (launch_floor*10);
    do_higher = ($urandom_range(10) < remainder);
    how_many = launch_floor + do_higher;
    assert (how_many <= MAX_PACKETS_PER_CYCLE);
    return (how_many);
  endfunction : n_packets_to_launch

  // Build one random packet.
  function Ring_slot random_packet();
    Ring_slot RS;

    // Pick the source and destination mesh stops (not worrying about targets)
    RS = EMPTY_RING_SLOT;
    RS.src_x = $urandom_range(MESH_SIZE-1);
    RS.src_y = $urandom_range(MESH_SIZE-1);
    RS.dst_x = $urandom_range(MESH_SIZE-1);
    RS.dst_y = $urandom_range(MESH_SIZE-1);
    RS.data  = $urandom_range((1<<RING_DATA_WIDTH)-1);
    RS.valid = 1'b1;

    // Now take targets into account.
    if ((mode != NO_TARGET) && ($urandom_range(9)<how_often_to_target))
	RS.dst_y = tgt_y;
    if ((mode == TARGET_MS) && ($urandom_range(9)<how_often_to_target))
	RS.dst_x = tgt_x;

    // Don't allow routing to yourself!
    if ((RS.src_x==RS.dst_x) && (RS.src_y==RS.dst_y))
	RS.dst_y = (RS.dst_y + 1) % MESH_SIZE;

    //$display ("T=%0t: made random packet %s", $time, print_RS(RS));
    return (RS);
  endfunction : random_packet

  function int make_packets (ref Ring_slot RS_array[MAX_PACKETS_PER_CYCLE]);
    int n_packets, i;
    bit dup;
    Ring_slot RS;
    n_packets = n_packets_to_launch();
    for (i=0; i< n_packets; i=i+0) begin
	RS_array[i] = random_packet();

	// It's not possible to launch multiple packets from one MS in a cycle.
	dup=0;
	for (int f=0; (f<i) && !dup; ++f)
	    if ((RS_array[f].src_x==RS_array[i].src_x)
			&& (RS_array[f].src_y==RS_array[i].src_y))
		dup = 1;
	if (!dup) ++i;
    end

    return (n_packets);
  endfunction : make_packets

  // NEW CODE to set dead links.
  // * Look at dead_link_freq to control how often we randomly kill a link.
  // * Never kill all the vertical links leaving any row (that would break the
  //   mesh)
  // * Don't return any value, but instead set tb_mesh.M_NxN.vert_link_dead[]
  //   appropriately.
  function set_dead_links ();
      bit dead;
      int n_dead;
      for (int y=0; y<MESH_SIZE; ++y) begin
          n_dead = 0;
	  for (int x=0; x<MESH_SIZE; ++x) begin
	      // dead_link_freq=0 => none dead. And 10 => all dead.
	      dead = ($urandom_range(9)<dead_link_freq) && (n_dead+1<MESH_SIZE);
	      tb_mesh.M_NxN.vert_link_dead[y][x] = dead;
	      n_dead += dead;
	  end
      end
  endfunction : set_dead_links

  // Once the fabric has a result ready for us, (take_results_frac/10) is the
  // odds we take that result in any given cycle.
  function bit take_results();
    return ($urandom_range(9) < take_results_frac);
  endfunction : take_results
endclass : Sim_control

// Begin the top-level module for the testbench.
module automatic tb_mesh;

  // Declare the interface signals to the mesh.
  logic reset, clk;
  logic venv_taking_data[MESH_SIZE][MESH_SIZE],
	data_avail_for_venv[MESH_SIZE][MESH_SIZE],
	can_accept_data_from_env[MESH_SIZE][MESH_SIZE];

  Ring_slot data_from_venv [MESH_SIZE][MESH_SIZE],
	    data_to_venv[MESH_SIZE][MESH_SIZE];

  // As we launch packets, we'll save them here so we can check them later.
  Ring_slot packet_history [N_PACKETS_TO_SEND];

  // Instantiate the top-level simulation-control object. Parameters are at
  // the top of the file
  Sim_control SC = new(.main_md(Sim_control::TARGET_MS), // type of targeting
		.how_oft(HOW_OFTEN_TO_TARGET),
		.tak_res_f(TAKE_RES_FREQ),	// how often to take results
		.launch_f(LAUNCH_FREQ),	// how often to launch a new packet
		.dead_link_f(DEAD_LINK_FREQ));	// odds of any link being dead.

  // Instantiate the NxN mesh
  mesh_NxN #(.N(MESH_SIZE)) M_NxN (.*);

  // Drive the main clock and set up waveform dumping.
  initial begin
      $dumpfile("dump.vcd");
      $dumpvars();
      clk = 0;
      forever begin	// eventually "tester" will call $stop to end the sim.
          #10;
          clk = ~clk;
      end
  end

  // The "tester" block, which is in charge of generating stimuli and driving
  // them into the DUT.
  //	- First initialize DUT-interface signals and some of our own internals.
  //	- Then pulse reset on for a few cycles to reset the DUT.
  //	- Then just keep driving packets into the mesh. Don't check them --
  //	  that's for the "mesh_checker" block.
  initial begin : tester
    int perc, good, n_bins;	// For coverage stats
    Ring_slot RS;
    automatic int
	n_pack_sent=0,	// number ever sent, so we know when to stop sending.
	n_pack_now=0;	// number to send in the current cycle
    Ring_slot RS_this_cycle[MAX_PACKETS_PER_CYCLE];	// to send right now

    // Clear the packet history before we start filling it.
    for (int i=0; i<N_PACKETS_TO_SEND; ++i)
	packet_history[i] = EMPTY_RING_SLOT;
      
    // Clear out the signals that we drive into the mesh, to avoid Xes.
    for (int y=0; y<MESH_SIZE; ++y)
	for (int x=0; x<MESH_SIZE; ++x) begin
	    venv_taking_data[y][x]=1'b0;
	    data_from_venv[y][x] = EMPTY_RING_SLOT;
	end

    // Start the sim by doing a reset.
    $display ("Starting the sim!");
    reset = 1'b1;
    repeat (8) @(negedge clk);
    reset = 1'b0;

    // Main loop -- send the packets.
    forever begin	// Not an infinite loop; there's a 'break' inside.
	@(negedge clk);

	// First stop sending the packets we sent last cycle. The mesh keys off
	// our packet having .valid=1, so set .valid to 0.
	for (int i=0; i<n_pack_now; ++i) begin
	    RS = RS_this_cycle[i];
	    RS.valid=0;
	    data_from_venv[RS.src_y][RS.src_x] = RS;
	end

	// Exit from the "forever" loop here (rather than at the top of the
	// loop) to ensure that the final packets we send do get their
	// data_from_venv.valid signals cleared.
	if (n_pack_sent>=N_PACKETS_TO_SEND) break;

	// Get new packets for this cycle, and ensure there's not too many.
	n_pack_now = SC.make_packets (RS_this_cycle);
	if (n_pack_sent+n_pack_now > N_PACKETS_TO_SEND)
	    n_pack_now = N_PACKETS_TO_SEND-n_pack_sent;

	// Send the new packets
	for (int i=0; i<n_pack_now; ++i) begin
	    // Inject this packet.
	    RS = RS_this_cycle[i];
	    // If any the DUT cannot take any packet, then just throw that
	    // packet away (some other packet will get sent eventually).
	    if (can_accept_data_from_env[RS.src_y][RS.src_x]) begin
		$display ("T=%0t: launching packet #%0d, %s",
			$time, n_pack_sent, print_RS(RS));
		packet_history[n_pack_sent] = RS; // Save it for later checking.
		data_from_venv[RS.src_y][RS.src_x] = RS;
		n_pack_sent++;
	    end
	end
    end; // while not all packets sent

    $display ("Done launching packets!");

    // Allow a few cycles for the sim to finish after we stop sending packets,
    // and then kill it. This ensures that we don't hang if the checker fails
    // to stop the sim (e.g., if we lose a packet).
    repeat (500) @(negedge clk);
    $display ("Stopping simulation due to timeout; not all packets received");
    $stop;
  end : tester

  // Now, the checker block. It's responsible for receiving packets from the
  // mesh (which does involve a handshake), and then checking that the packets
  // were sent correctly.
  initial begin : mesh_checker
    int x, y; // to loop through each MS and look for outgoing packets
    automatic int n_pack_recvd=0; // Track how many packets we've received.
    int match;		// Which packet we received
    bit take;
    string suffix;
    Ring_slot RS;

    // Weird stuff can happen during reset, so don't start looking for packets
    // until that's done.
    while (reset == 1'b1)
	@(negedge clk);

    // This is our hopefully-improved (vs. the first mesh lab) version of the
    // mesh checker.
    while (n_pack_recvd<N_PACKETS_TO_SEND) begin
	@(negedge clk);

	// Check every mesh stop to see if a new packet has arrived this cycle.
	for (y=0; y<MESH_SIZE; ++y) begin
	    for (x=0; x<MESH_SIZE; ++x) begin
		// We only take a packet if one is actually ready, and if we
		// decide to take it (rather than to let it wait to increase
		// congestion).
		take = data_avail_for_venv[y][x] && SC.take_results();
		if (!take) begin
		    // Turn off any handshakes from last cycle.
		    venv_taking_data[y][x]=0;
		    continue;
		end

		// OK, there's a packet here and we're taking it.
		n_pack_recvd++;	// So we know when we're done.

		// Again -- we're taking the packet. So start the handshake.
		venv_taking_data[y][x]=1;

		// Print & check if it's correct
		RS = data_to_venv[y][x];
		match=-1; suffix = "NOT found";
		for (int i=0; (i<N_PACKETS_TO_SEND)&& (match<0); ++i) begin
		    if (packet_history[i].valid	&&(packet_history[i]==RS)) begin
			packet_history[i].valid = 1'b0;	// Mark as found.
			match=i;
			suffix = $sformatf("packet #%0d", match);
		    end
		end	// checking if found
		if ((RS.dst_y != y) || (RS.dst_x != x)) begin
		    suffix = {suffix, " wrong destination"};
		    match = -1;
		end
		$display("%0d. T=%0T: data_avail_for_venv[%0d][%0d]; %s, %s",
		      n_pack_recvd, $time, y, x, print_RS(RS),suffix);
		if (match<0) $stop;
	    end // for x
	end // for y
    end // while all packets not received yet.
    $display ("Received all %0d packets!", n_pack_recvd);
    $stop;
  end : mesh_checker

  // This module is to help you debug your mesh stop and/or RCG. It just dumps
  // out all valid packets on the vertical or horizontal rings every cycle.
  // Hopefully the code is fairly self-explanatory; feel free to modify it for
  // your use. You could change the printing format, add some "if" statements
  // to restrict what data gets printed, etc.
  // Note that all printing happens on the *falling* clock edge.
  initial begin : debugger
    Ring_slot RS;
    int y, x;

    // Weird stuff can happen during reset, so don't start looking for packets
    // until that's done.
    while (reset == 1'b1)
	@(negedge clk);

    forever begin
	@(negedge clk);
        for (y=0; y<MESH_SIZE; ++y) begin
	  for (x=0; x<MESH_SIZE; ++x) begin
	    RS = tb_mesh.M_NxN.vert_ring[y][x];
	    if (RS.valid)
	      $display("\tdbg T=%0t: vert[%0d][%0d]=%s",$time,y,x,print_RS(RS));
	    RS = tb_mesh.M_NxN.hori_ring[y][x];
	    if (RS.valid)
	      $display("\tdbg T=%0t: hori[%0d][%0d]=%s",$time,y,x,print_RS(RS));
	  end
	end
    end
  end : debugger

  // NEW CODE to manage dead links.
  initial begin : dead_links
    // Set up any broken links.
    SC.set_dead_links ();

    // Display what's dead, to help with debugging.
    for (int y=0; y<MESH_SIZE; ++y)
	for (int x=0; x<MESH_SIZE; ++x)
	    if (tb_mesh.M_NxN.vert_link_dead[y][x] == 1)
		$display ("Set dead link %0d,%0d", y, x);

    // As usual, wait until reset is done.
    while (reset == 1'b1)
	@(negedge clk);

    // At every falling edge for the entire sim, ensure that the dead links are
    // being respected -- i.e., that the MSs aren't actually driving on them.
    forever begin
	@(negedge clk);
        for (int y=0; y<MESH_SIZE; ++y) begin
	    for (int x=0; x<MESH_SIZE; ++x) begin
		if (tb_mesh.M_NxN.vert_link_dead[y][x])
		    assert (tb_mesh.M_NxN.vert_ring[y][x].valid==0);
	    end
	end
    end
  end : dead_links

endmodule : tb_mesh
