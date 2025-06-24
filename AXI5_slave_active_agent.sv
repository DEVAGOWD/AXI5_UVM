class AXI5_slave_active_agent extends uvm_agent;

//====================factory registration =================
	`uvm_component_utils(AXI5_slave_active_agent)

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//========================instances ===========================

	AXI5_slave_sequencer h_slave_sequencer;
	AXI5_slave_driver h_slave_driver;

//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//=======================memory creations===========================
		h_slave_sequencer = AXI5_slave_sequencer :: type_id :: create("h_slave_sequencer",this);
		h_slave_driver = AXI5_slave_driver :: type_id :: create("h_slave_driver",this);

	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		h_slave_driver.seq_item_port.connect(h_slave_sequencer.seq_item_export);
	endfunction



endclass
