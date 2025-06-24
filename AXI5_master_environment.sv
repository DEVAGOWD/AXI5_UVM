class AXI5_environment extends uvm_env;

//====================factory registration =================
	`uvm_component_utils(AXI5_environment)

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//========================instances ===========================
	AXI5_active_agent h_ac_agent;
	AXI5_passive_agent h_pa_agent;
	AXI5_scoreboard h_score;
	AXI5_coverage h_cover;
//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//=======================memory creations===========================
		h_ac_agent = AXI5_active_agent :: type_id :: create("h_ac_agent",this);
		h_pa_agent = AXI5_passive_agent :: type_id :: create("h_pa_agent",this);
		h_score = AXI5_scoreboard :: type_id :: create("h_score",this);
		h_cover = AXI5_coverage :: type_id :: create("h_cover",this);
	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		h_ac_agent.h_aa_export.connect(h_score.h_in_monitor);
		h_pa_agent.h_pa_export.connect(h_score.h_out_monitor);

	endfunction



endclass
