class AXI5_passive_agent extends uvm_agent;

//====================factory registration =================
	`uvm_component_utils(AXI5_passive_agent)

//===============analysis export=======================

	uvm_analysis_export #(AXI5_sequence_item) h_pa_export;

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//========================instances ===========================

	AXI5_output_monitor h_out_mon;
//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//=======================memory creations===========================
		h_out_mon = AXI5_output_monitor :: type_id :: create("h_out_mon",this);
		h_pa_export=new("h_pa_export",this);

	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		h_out_mon.h_out_mon_analysis.connect(this.h_pa_export);

	endfunction



endclass
