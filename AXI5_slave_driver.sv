class AXI5_slave_driver extends uvm_driver #(AXI5_sequence_item);

//==============================function registration ================

	`uvm_component_utils(AXI5_slave_driver)

	
//================construction=============================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction
//================virtual interface=================//

	virtual intf h_intf;

//========================event declaration================

//======================config instance==================
	AXI5_config_class h_config;


//===================build phase=========================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

//====================connect phase ===================
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		//========interface getting========================//

		assert(uvm_config_db #(virtual intf) :: get(this , this.get_full_name() , "intf" , h_intf));
		assert(uvm_config_db #(AXI5_config_class)::get(null,this.get_full_name(),"AXI5_config_class",h_config));

	endfunction

//=================================run phase ==========================

//=====================run phase ============//
	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever@(h_intf.cb_driver_slave)begin
			seq_item_port.get_next_item(req);

			fork
					aw_channel_handshake;
					w_channel_handshake;
					
					b_channel_handshake;
					
					ar_channel_handshake;
					r_channel_handshake;
					
			join_any
	//		disable fork;
			seq_item_port.item_done();

		end
		
	endtask




//====================task for aw_channel ====================
	task aw_channel_handshake;
		
			wait(h_intf.cb_driver_slave.AWVALID);

			h_intf.cb_driver_slave.AWREADY<=req.AWREADY;
			@(h_intf.cb_driver_slave);
			h_intf.cb_driver_slave.AWREADY<=0;
			
		
	endtask


//==================task for w channel =================

	task w_channel_handshake;
			wait(h_intf.cb_driver_slave.WVALID);
			h_intf.cb_driver_slave.WREADY<=req.WREADY;
			@(h_intf.cb_driver_slave);
			h_intf.cb_driver_slave.WREADY<=0;
			
		

	endtask

//===================task for b channel====================

	task b_channel_handshake;
		wait(h_config.aw_ch_handshake&&h_config.w_ch_handshake&&h_intf.cb_driver_slave
.WLAST);	
		@(h_intf.cb_driver_slave)
		h_intf.cb_driver_slave.BVALID<=req.BVALID;
		h_intf.cb_driver_slave.BRESP<=req.BRESP;
		h_intf.cb_driver_slave.BID<=req.BID;
	//	h_intf.cb_driver_slave.BUSER<=req.BUSER;
		h_intf.cb_driver_slave.BIDUNQ<=req.BIDUNQ;
		wait(h_intf.cb_driver_slave.BVALID&&h_intf.cb_driver_slave.BREADY);
		h_intf.cb_driver_slave.BVALID<=0;
		h_config.aw_ch_handshake=0;
		h_config.w_ch_handshake=0;
		

	endtask


//====================task for ar channel ======================

	task ar_channel_handshake;
			
			wait(h_intf.cb_driver_slave.ARVALID);
			h_intf.cb_driver_slave.ARREADY<=req.ARREADY;
			@(h_intf.cb_driver_slave);
			h_intf.cb_driver_slave.ARREADY<=0;

	endtask


//==================task for r channel =======================

	task r_channel_handshake;
			wait(h_config.ar_ch_handshake||(h_config.aw_ch_handshake&&h_config.AWATOP>0&&h_config.AWATOP[5:4]!=01));
			h_intf.cb_driver_slave.RVALID<=req.RVALID;

			h_intf.cb_driver_slave.RLAST<=req.RLAST;
			h_intf.cb_driver_slave.RDATA<=req.RDATA;
			h_intf.cb_driver_slave.RID<=req.RID;

			h_intf.cb_driver_slave.RRESP<=req.RRESP;
			h_intf.cb_driver_slave.RIDUNQ<=req.RIDUNQ;
			h_intf.cb_driver_slave.RCHUNKV<=req.RCHUNKV;
			h_intf.cb_driver_slave.RCHUNKNUM<=req.RCHUNKNUM;
			h_intf.cb_driver_slave.RCHUNKSTRB<=req.RCHUNKSTRB;
			h_intf.cb_driver_slave.RPOISON<=req.RPOISON;
			wait(h_intf.cb_driver_slave.RVALID&&h_intf.cb_driver_slave.RREADY);

			 h_intf.cb_driver_slave.RVALID<=0;
			@(h_intf.cb_driver_slave);  //--------------------without this delay ---drop objection --- monitor not written to scoreboard
		
	endtask

	

endclass
