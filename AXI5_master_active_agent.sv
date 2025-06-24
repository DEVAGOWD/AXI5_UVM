class AXI5_active_agent extends uvm_agent;

//====================factory registration =================
	`uvm_component_utils(AXI5_active_agent)

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//========================instances ===========================

	AXI5_sequencer h_sequencer;
	AXI5_driver h_driver;
	AXI5_input_monitor h_in_mon;
	uvm_analysis_export #(AXI5_sequence_item) h_aa_export;

//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//=======================memory creations===========================
		h_sequencer = AXI5_sequencer :: type_id :: create("h_sequencer",this);
		h_driver = AXI5_driver :: type_id :: create("h_driver",this);
		h_in_mon = AXI5_input_monitor :: type_id :: create("h_in_mon",this);
		h_aa_export=new("h_aa_export",this);

	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		h_driver.seq_item_port.connect(h_sequencer.seq_item_export);
		h_in_mon.h_in_mon_analysis.connect(this.h_aa_export);

	endfunction



endclass
