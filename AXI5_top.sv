

module AXI5_top_module;

	import uvm_pkg::*;
	import AXI5_package::*;


//============clock declaration==============//

	bit clk ;

//===========clock generation===================//

	always #2 clk++;

	bit ARESETn=1;
	bit AWAKEUP=1;

//=============interface instance=================//

	intf h_intf(clk,AWAKEUP,ARESETn);


	AXI5_config_class h_config;

//==========================slave instance =============================

//	slave ins(h_intf.clk,h_intf.AWVALID,h_intf.WVALID,h_intf.BREADY,h_intf.WLAST,h_intf.ARVALID,h_intf.RREADY,h_intf.AWREADY,h_intf.WREADY,h_intf.BVALID,h_intf.ARREADY,h_intf.RVALID);


	initial begin

		h_config = new();
//=======interface setting===================//

		uvm_config_db #(virtual intf) :: set(null , "*" , "intf", h_intf);
		uvm_config_db #(AXI5_config_class) :: set(null , "*" , "AXI5_config_class", h_config);

		run_test();
	end



endmodule
