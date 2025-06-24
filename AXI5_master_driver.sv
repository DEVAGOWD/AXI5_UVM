class AXI5_driver extends uvm_driver #(AXI5_sequence_item);

//==============================function registration ================

	`uvm_component_utils(AXI5_driver)

	
//================construction=============================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction
//================virtual interface=================//

	virtual intf h_intf;

//========================event declaration================
	event wr_addr_ev,wr_data_ev,wr_resp_ev,rd_addr_ev,rd_data_ev;

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
		forever@(h_intf.cb_driver)begin
			seq_item_port.get_next_item(req);

			fork

					aw_channel_handshake;

					w_channel_handshake;

					b_channel_handshake;

					ar_channel_handshake;

					r_channel_handshake;

			join_any
			seq_item_port.item_done();

		end
		
	endtask




//====================task for aw_channel ====================
	task aw_channel_handshake;

			h_intf.cb_driver.AWVALID<=req.AWVALID;
			h_intf.cb_driver.AWADDR<=req.AWADDR;
			h_intf.cb_driver.AWSIZE<=req.AWSIZE;
			h_intf.cb_driver.AWBURST<=req.AWBURST;
			h_intf.cb_driver.AWCACHE<=req.AWCACHE;
			h_intf.cb_driver.AWPROT<=req.AWPROT;
			h_intf.cb_driver.AWID<=req.AWID;
			h_intf.cb_driver.AWLEN<=req.AWLEN;
			h_intf.cb_driver.AWLOCK<=req.AWLOCK;
			h_intf.cb_driver.AWQOS<=req.AWQOS;
			h_intf.cb_driver.AWATOP<=req.AWATOP;
			h_intf.cb_driver.AWIDUNQ<=req.AWIDUNQ;
			wait(h_intf.cb_driver.AWVALID&&h_intf.cb_driver.AWREADY);
			
//---------------indication that aw channel handshake is completed-----------
			h_config.aw_ch_handshake=1;
//--------------------------calling the get address phase ------------
			h_config.get_write_addr_phase;

			 h_intf.cb_driver.AWVALID<=0;


	endtask


//==================task for w channel =================

	task w_channel_handshake;

			h_intf.cb_driver.WVALID<=req.WVALID;
			h_intf.cb_driver.WLAST<=req.WLAST;
			h_intf.cb_driver.WSTRB<=req.WSTRB;
			h_intf.cb_driver.WDATA<=req.WDATA;
			h_intf.cb_driver.WPOISON<=req.WPOISON;

			wait(h_intf.cb_driver.WVALID&&h_intf.cb_driver.WREADY);

//---------------------indication that the w channel handshake is completed --------------
			h_config.w_ch_handshake=1;

//-----------------------calling the write data phase ----------------------
        	h_config.get_write_data_phase();

			h_intf.cb_driver.WVALID<=0;


	endtask

//===================task for b channel====================

	task b_channel_handshake;

			wait(h_intf.cb_driver.BVALID)
			h_intf.cb_driver.BREADY<=req.BREADY;
			wait(h_intf.cb_driver.BVALID&&h_intf.cb_driver.BREADY);
			@(h_intf.cb_driver); h_intf.cb_driver.BREADY<=0;

	endtask


//====================task for ar channel ======================

	task ar_channel_handshake;

			h_intf.cb_driver.ARVALID<=req.ARVALID;
			h_intf.cb_driver.ARADDR<=req.ARADDR;
			h_intf.cb_driver.ARSIZE<=req.ARSIZE;

			h_intf.cb_driver.ARBURST<=req.ARBURST;
			h_intf.cb_driver.ARCACHE<=req.ARCACHE;
			h_intf.cb_driver.ARPROT<=req.ARPROT;
			h_intf.cb_driver.ARID<=req.ARID;
			h_intf.cb_driver.ARLEN<=req.ARLEN;
			h_intf.cb_driver.ARLOCK<=req.ARLOCK;
			h_intf.cb_driver.ARQOS<=req.ARQOS;
			h_intf.cb_driver.ARIDUNQ<=req.ARIDUNQ;
			h_intf.cb_driver.ARCHUNCKEN<=req.ARCHUNKEN;

			wait(h_intf.cb_driver.ARVALID&&h_intf.cb_driver.ARREADY);

//---------------------indication that the ar channel signal -----------------
			h_config.ar_ch_handshake=1;

//-----------------------calling the read data phase ---------------
			h_config.get_read_addr_phase();

//--------------------------task for creating the memory's for dynamic arrays based on configured length -----------
			h_config.strobe_memory_creation(h_intf.cb_driver.ARLEN);

			h_intf.cb_driver.ARVALID<=0;
	endtask


//==================task for r channel =======================

	task r_channel_handshake;

			wait(h_intf.cb_driver.RVALID);
			h_intf.cb_driver.RREADY<=req.RREADY;
			wait(h_intf.cb_driver.RVALID&&h_intf.cb_driver.RREADY);
			@(h_intf.cb_driver);
		 	h_intf.cb_driver.RREADY<=0;
	endtask

	

endclass
