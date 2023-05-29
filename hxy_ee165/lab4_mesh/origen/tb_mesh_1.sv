parameter MESH_SIZE=2;		// For a 2x2 mesh.
parameter N_PACKETS_TO_SEND=20;	// How long the test will be

import mesh_defs::*;		// Some common functions & definitions

// This class decides which packets to launch and when to launch them.
// For now, it just launches a very simple directed test. Later we will modify
// it to create a full-fledged RCG.
class Sim_control;
  Ring_slot slots[16];	// The 16 predetermined packets we will launch.
  int index=0;		// Index into slots[], to send them out cyclically.

  function new ();
    // We will cycle through just launching these packets.
    // Format is data, valid, reserved, src_y, src_x, dst_y, dst_x
    slots[0]  = '{0, 1,0, 0,0, 0,0};	// 0,0 -> 0,0, data=0
    slots[1]  = '{1, 1,0, 0,0, 0,1};	// 0,0 -> 0,1, data=1
    slots[2]  = '{2, 1,0, 0,0, 1,0};	// 0,0 -> 1,0, data=2
    slots[3]  = '{3, 1,0, 0,0, 1,1};	// 0,0 -> 1,1, data=3
    slots[4]  = '{4, 1,0, 0,1, 0,0};	// 0,1 -> 0,0, data=4
    slots[5]  = '{5, 1,0, 0,1, 0,1};	// 0,1 -> 0,1, data=5
    slots[6]  = '{6, 1,0, 0,1, 1,0};	// 0,1 -> 1,0, data=6
    slots[7]  = '{7, 1,0, 0,1, 1,1};	// 0,1 -> 1,1, data=7
    slots[8]  = '{8, 1,0, 1,0, 0,0};	// 1,0 -> 0,0, data=8
    slots[9]  = '{9, 1,0, 1,0, 0,1};	// 1,0 -> 0,1, data=9
    slots[10] = '{10,1,0, 1,0, 1,0};	// 1,0 -> 1,0, data=10
    slots[11] = '{11,1,0, 1,0, 1,1};	// 1,0 -> 1,1, data=11
    slots[12] = '{12,1,0, 1,1, 0,0};	// 1,1 -> 0,0, data=12
    slots[13] = '{13,1,0, 1,1, 0,1};	// 1,1 -> 0,1, data=13
    slots[14] = '{14,1,0, 1,1, 1,0};	// 1,1 -> 1,0, data=14
    slots[15] = '{15,1,0, 1,1, 1,1};	// 1,1 -> 1,1, data=15
  endfunction : new

  // Launch a packet every 10 cycles.
  function int make_packets (ref Ring_slot RS_array[1]);
    int cycle;
    cycle = $time / 20;		// Because our clock period is 20.

    if (cycle % 10 != 0)	// Launch a new packet every 10 cycles.
	return (0);		// So return 0 packets most of the time.

    RS_array[0] = slots[index % 16];	// Cycle through the 16 packet choices.
    index++;
    return (1);				// Returning one packet
  endfunction : make_packets
endclass : Sim_control

// This is the top-level module for the testbench.
module tb_mesh;

  // Declare top-level wires. The other wires are all inside of mesh_NxN.
  logic reset, clk;
  logic venv_taking_data[MESH_SIZE][MESH_SIZE],
	data_avail_for_venv[MESH_SIZE][MESH_SIZE],
	can_accept_data_from_env[MESH_SIZE][MESH_SIZE];

  Ring_slot data_from_venv [MESH_SIZE][MESH_SIZE],
	    data_to_venv[MESH_SIZE][MESH_SIZE];

  // As we launch packets, we'll save them here so we can check them later.
  Ring_slot packet_history [N_PACKETS_TO_SEND];

  // Instantiate the top-level simulation-control object.
  Sim_control SC = new();

  // Instantiate the NxN mesh
  mesh_NxN #(.N(MESH_SIZE)) M_NxN (.*);

  // Drive the main clock
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
  //	- First drive reset on & off.
  //	- Then just keep driving packets into the mesh. Don't check them --
  //	  that's for the "mesh_checker" block.
  initial begin : tester
    int perc, good, n_bins;	// For coverage stats
    Ring_slot RS;
    automatic int
	n_pack_sent=0,	// number ever sent, so we know when to stop sending.
	n_pack_now=0;	// number to send in the current cycle
    Ring_slot RS_this_cycle[1];	// to send right now

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
    forever begin
	@(negedge clk);

	// First stop sending the packets we sent last cycle. The mesh keys off
	// our packet having .valid=1, so set .valid to 0.
	for (int i=0; i<n_pack_now; ++i) begin
	    RS = RS_this_cycle[i];
	    RS.valid=0;
	    data_from_venv[RS.src_y][RS.src_x] = RS;
	end

	// Exit from the "forever" loop here to ensure that the final packets
	// we send do get their data_from_venv.valid signals cleared.
	if (n_pack_sent>=N_PACKETS_TO_SEND) break;

	// Get new packets for this cycle, and ensure there's not too many.
	n_pack_now = SC.make_packets (RS_this_cycle);
	if (n_pack_sent+n_pack_now > N_PACKETS_TO_SEND)
	    n_pack_now = N_PACKETS_TO_SEND-n_pack_sent;

	// Send the new packets
	for (int i=0; i<n_pack_now; ++i) begin
	    // Inject this packet.
	    RS = RS_this_cycle[i];
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

    // Allow 15 cycles for the sim to finish after we stop sending packets, and
    // then kill it. This ensures that we don't hang if the checker fails to
    // stop the sim (e.g., if we lose a packet).
    repeat (100) @(negedge clk);
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

    // Weird stuff can hapen during reset, so don't start looking for packets
    // until that's done.
    while (reset == 1'b1)
	@(negedge clk);

    while (n_pack_recvd<N_PACKETS_TO_SEND) begin	//loops forever for now!
	@(negedge clk);

	// Check every mesh stop to see if a new packet has arrived this cycle.
	for (y=0; y<MESH_SIZE; ++y) begin
	    for (x=0; x<MESH_SIZE; ++x) begin
		if (!data_avail_for_venv[y][x]) begin
		    // Turn off any handshakes from last cycle.
		    venv_taking_data[y][x]=0;
		    continue;
		end

		// Start handshake to take the packet.
		venv_taking_data[y][x]=1;

		// Print & check if it's correct
		RS = data_to_venv[y][x];
		match=-1;
		for (int i=0; (i<N_PACKETS_TO_SEND)&& (match<0); ++i) begin
		    if (packet_history[i].valid	&&(packet_history[i]==RS)) begin
			packet_history[i].valid = 1'b0;	// Mark as found.
			match=i;
		    end
		end	// checking if found

		$display("T=%0T: data_avail_for_venv[%0d][%0d]; %s",
		      $time, y, x, print_RS(RS));
		if (match<0) begin
		    $display("Packet not found failure -- ending simulation");
		    $stop;
		end
	    end // for x
	end // for y
    end // while all packets not received yet.
    $display ("Received all packets!");
    $stop;
  end : mesh_checker

endmodule : tb_mesh
