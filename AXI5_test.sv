class AXI5_test extends uvm_test;

//====================factory registration =================
	`uvm_component_utils(AXI5_test)

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//========================instances ===========================
	AXI5_environment h_env;  //--------------master environment
	AXI5_slave_environment h_slave_env;	//-------------slave environment
	AXI5_sequence h_sequence;	//-------------master sequence
	AXI5_slave_sequence h_slave_sequence;	//-----------slave sequence
	AXI5_config_class h_config;	//-------------config class instance
	virtual intf h_intf;	//------------virtual interface instance

//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//=======================memory creations===========================
		h_env = AXI5_environment :: type_id :: create("h_env",this);
		h_slave_env = AXI5_slave_environment :: type_id :: create("h_slave_env",this);
		
		h_sequence = AXI5_sequence :: type_id :: create("h_sequence");
		h_slave_sequence=AXI5_slave_sequence::type_id::create("h_slave_sequence");

	endfunction

//============================end_of_elaboration_phase =======================

	function void end_of_elaboration_phase(uvm_phase phase);
	//	uvm_top.print_topology();//  to print the topology to verify how the connetions is going on
		print();
	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		assert (uvm_config_db #(virtual intf)::get(null,this.get_full_name(),"intf",h_intf));

		assert(uvm_config_db #(AXI5_config_class)::get(null,this.get_full_name(),"AXI5_config_class",h_config));

	endfunction

//=====================================run phase=======================
	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		phase.raise_objection(this,"objection raised");


		fork

			begin

			h_sequence.start(h_env.h_ac_agent.h_sequencer);
			end

			forever begin 
				h_slave_sequence.start(h_slave_env.h_slave_ac_agent.h_slave_sequencer);
			end

		join_any
		disable fork;
		#3;         
		phase.drop_objection(this,"objection dropped");
		`uvm_info("test ",$sformatf("***run phase is completed***"),UVM_LOW);
	endtask

endclass


