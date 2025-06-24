class AXI5_slave_environment extends uvm_env;

//====================factory registration =================
	`uvm_component_utils(AXI5_slave_environment)

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//========================instances ===========================
	AXI5_slave_active_agent h_slave_ac_agent;
//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//=======================memory creations===========================
		h_slave_ac_agent = AXI5_slave_active_agent :: type_id :: create("h_slave_ac_agent",this);
		endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

	
	endfunction



endclass
