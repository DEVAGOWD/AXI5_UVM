class AXI5_slave_sequencer extends uvm_sequencer #(AXI5_sequence_item);

//=====================factory registration ============================

	`uvm_component_utils(AXI5_slave_sequencer)

//============================construction========================

	function new(string name="",uvm_component parent);
		super.new(name,parent);
	endfunction

//==============build phase===========================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		`uvm_info("   IN SLAVE SEQUENCER  ",$sformatf("  IN SLAVE SEQUENCER BUILD PHASE  "),UVM_LOW);

	endfunction


endclass
