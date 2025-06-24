

`define MAX_AXI5_DATA_WIDTH 16
`define MAX_AXI5_ADDRESS_WIDTH 64
`define MAX_AXI5_ID_WIDTH 8





interface intf(input clk,AWAKEUP,ARESETn);

//=======================signal declaration ============================//

//===================================write address channel =================================

	 logic AWVALID;			// ---------- used to tell coming data is valid 
	 logic AWREADY;				// ---------- slave ack 
	 logic [(`MAX_AXI5_ADDRESS_WIDTH - 1):0]AWADDR;  	// ---------- used to define_address_pointer 
	 logic [2:0]AWSIZE;		// ---------- defines size of transfer ------- in bytes 
	 logic [1:0]AWBURST;	//----------- type of acces---- fixed --- incriment --- wrap 
	 logic [3:0]AWCACHE;	// ---------- cache storage 
	 logic [2:0]AWPROT;		// ---------- protection specification signal 
	 logic [(`MAX_AXI5_ID_WIDTH - 1):0]AWID;		// ---------- id for the address location 
	 logic [7:0]AWLEN;		// ---- ------ specifies the length of the transfer 
	 logic AWLOCK;			// ---------- specifies locked transfer or not 
	 logic [3:0]AWQOS;			// ---------- specifies the quality of the signal
	 logic AWREGION;			
	 logic AWUSER;
	 logic [5:0]AWATOP;
	 logic AWIDUNQ;
	 logic [3:0]VAWQOSACCEPT;

  // ========================= write data signalls ================== //

	 logic WVALID;			// ----------- specifies the coming data is valid 
	 logic WREADY;				// ----------- data ack signal
	 logic WLAST;			// ----------- to specify the indication that sending last byte in transfer
	 logic [(`MAX_AXI5_DATA_WIDTH - 1):0]WDATA;		// ----------- data that had to be wriiten to the slave
	 logic [((`MAX_AXI5_DATA_WIDTH / 8)-1):0]WSTRB;		// ----------- specify which byte of the data line is valid 
	 logic WUSER;
	logic [(`MAX_AXI5_DATA_WIDTH/64)-1:0] WPOISON;

  // ===================== write response channel ================ //

	logic BVALID;				// ----------- specify that getting valid response
	logic BREADY;			// ----------- resp ack signal
	logic [1:0]BRESP;			// ----------- to specify that the transaction is completed with or with out errors
	logic [(`MAX_AXI5_ID_WIDTH - 1):0]BID;			// ----------- to tell for which address the resp is coming
	logic BUSER;
	logic BIDUNQ;



  // ==================== read address chanells ================ //
	
	 logic ARVALID;			// ---------- used to tell coming data is valid 
	 logic ARREADY;				// ---------- slave ack 
	 logic [(`MAX_AXI5_ADDRESS_WIDTH - 1):0]ARADDR;  	// ---------- used to define_addressointer 
	 logic [2:0]ARSIZE;		// ---------- defines size of transfer ------- in bytes 
	 logic [1:0]ARBURST;	//----------- type of acces---- fixed --- incriment --- wrap 
	 logic [3:0]ARCACHE;	// ---------- cache storage 
	 logic [2:0]ARPROT;		// ---------- protection specification signal 
	 logic [(`MAX_AXI5_ID_WIDTH - 1):0]ARID;		// ---------- id for the address location 
	 logic [7:0]ARLEN;		// ---------- specifies the length of the transfer 
	 logic ARLOCK;			// ---------- specifies locked transfer or not 
	 logic [3:0]ARQOS;			// ---------- specifies the quality of the signal
	 logic ARREGION;			
	 logic ARUSER;
	 logic ARIDUNQ;
	 logic ARCHUNCKEN;
	 logic [3:0]VARQOSACCEPT;

  // ================== read data channel ========================//

	logic RVALID;				// ----------- specifies the coming data is valid 
	logic RREADY;			// ----------- data ack signal
	logic RLAST;				// ----------- to specify the indication that sending last byte in transfer
	logic [(`MAX_AXI5_DATA_WIDTH - 1):0]RDATA;			// ----------- data that had to be wriiten to the slave
	logic [1:0]RRESP;			// ----------- to specify that the transaction is completed with or with out errors 
	logic [(`MAX_AXI5_ID_WIDTH - 1):0]RID;			// ----------- for address identification purpose
	logic RUSER;
	logic RIDUNQ;
	logic RCHUNKV;
	logic [$clog2(4096/(`MAX_AXI5_DATA_WIDTH/8))-1:0]RCHUNKNUM;
	logic [(`MAX_AXI5_DATA_WIDTH/128)-1:0]RCHUNKSTRB;
	logic [(`MAX_AXI5_DATA_WIDTH/64)-1:0] RPOISON;


//===============================clking blocks===========================================

	clocking cb_driver @(posedge clk);

//-----------------------AW channel signals--------------------------------------------------
	 output AWVALID;			
	 input AWREADY;			
	 output AWADDR;  	 
	 output AWSIZE;		
	 output AWBURST;
	 output AWCACHE;	
	 output AWPROT;	
	 output AWID;		
	 output AWLEN;	
	 output AWLOCK;			
	 output AWQOS;			
	 output AWREGION;			
	 output AWUSER;
	 output AWATOP;
	 output AWIDUNQ;
	 output VAWQOSACCEPT;

//-----------------------W channel signals--------------------------------------------------

	 output WVALID;		
	 input WREADY;				
	 output WLAST;			
	 output WDATA;		
	 output WSTRB;	
	 output WUSER;
	output WPOISON;

//-----------------------B channel signals--------------------------------------------------

	input BVALID;				
	output BREADY;			
	input BRESP;			// ----------- to specify that the transaction is completed with or with out errors
	input BID;			// ----------- to tell for which address the resp is coming
	input BUSER;
	input BIDUNQ;
//-----------------------AR channel signals--------------------------------------------------
	
	 output ARVALID;			
	 input ARREADY;				// ---------- slave ack 
	 output ARADDR;  	// ---------- used to define_addressointer 
	 output ARSIZE;		// ---------- defines size of transfer ------- in bytes 
	 output ARBURST;	//----------- type of acces---- fixed --- incriment --- wrap 
	 output ARCACHE;	// ---------- cache storage 
	 output ARPROT;		// ---------- protection specification signal 
	 output ARID;		// ---------- id for the address location 
	 output ARLEN;		// ---------- specifies the length of the transfer 
	 output ARLOCK;			// ---------- specifies locked transfer or not 
	 output ARQOS;			// ---------- specifies the quality of the signal
	 output ARREGION;			
	 output ARUSER;
	 output ARIDUNQ;
	 output ARCHUNCKEN;
	 output VARQOSACCEPT;

//-----------------------R channel signals--------------------------------------------------
	input RVALID;				// ----------- specifies the coming data is valid 
	output RREADY;			// ----------- data ack signal
	input RLAST;				// ----------- to specify the indication that sending last byte in transfer
	input RDATA;			// ----------- data that had to be wriiten to the slave
	input RRESP;			// ----------- to specify that the transaction is completed with or with out errors 
	input RID;			// ----------- for address identification purpose
	input RUSER;
	input RIDUNQ;
	input RCHUNKV;
	input RCHUNKNUM;
	input RCHUNKSTRB;
	input RPOISON;

	endclocking


//====================clocking block monitor=======================================

	clocking cb_monitor @(posedge clk);

//-----------------------AW channel signals--------------------------------------------------
	 input AWVALID;			
	 input AWREADY;			
	 input AWADDR;  	 
	 input AWSIZE;		
	 input AWBURST;
	 input AWCACHE;	
	 input AWPROT;	
	 input AWID;		
	 input AWLEN;	
	 input AWLOCK;			
	 input AWQOS;			
	 input AWREGION;			
	 input AWUSER;
	 input AWATOP;
	 input AWIDUNQ;
	 input VAWQOSACCEPT;

//-----------------------W channel signals--------------------------------------------------

	 input WVALID;		
	 input WREADY;				
	 input WLAST;			
	 input WDATA;		
	 input WSTRB;	
	 input WUSER;
	input  WPOISON;

//-----------------------B channel signals--------------------------------------------------

	input BVALID;				
	input BREADY;			
	input BRESP;			// ----------- to specify that the transaction is completed with or with out errors
	input BID;			// ----------- to tell for which address the resp is coming
	input BUSER;
	input BIDUNQ;
//-----------------------AR channel signals--------------------------------------------------
	
	 input ARVALID;			
	 input ARREADY;				// ---------- slave ack 
	 input ARADDR;  	// ---------- used to define_addressointer 
	 input ARSIZE;		// ---------- defines size of transfer ------- in bytes 
	 input ARBURST;	//----------- type of acces---- fixed --- incriment --- wrap 
	 input ARCACHE;	// ---------- cache storage 
	 input ARPROT;		// ---------- protection specification signal 
	 input ARID;		// ---------- id for the address location 
	 input ARLEN;		// ---------- specifies the length of the transfer 
	 input ARLOCK;			// ---------- specifies locked transfer or not 
	 input ARQOS;			// ---------- specifies the quality of the signal
	 input ARREGION;			
	 input ARUSER;
	 input ARIDUNQ;
	 input ARCHUNCKEN;
	 input VARQOSACCEPT;

//-----------------------R channel signals--------------------------------------------------
	input RVALID;				// ----------- specifies the coming data is valid 
	input RREADY;			// ----------- data ack signal
	input RLAST;				// ----------- to specify the indication that sending last byte in transfer
	input RDATA;			// ----------- data that had to be wriiten to the slave
	input RRESP;			// ----------- to specify that the transaction is completed with or with out errors 
	input RID;			// ----------- for address identification purpose
	input RUSER;
	input RIDUNQ;
	input RCHUNKV;
	input RCHUNKNUM;
	input RCHUNKSTRB;
	input  RPOISON;

	endclocking





	clocking cb_driver_slave @(posedge clk);

//-----------------------AW channel signals--------------------------------------------------
	 input AWVALID;			
	 output AWREADY;			
	 input AWADDR;  	 
	 input AWSIZE;		
	 input AWBURST;
	 input AWCACHE;	
	 input AWPROT;	
	 input AWID;		
	 input AWLEN;	
	 input AWLOCK;			
	 input AWQOS;			
	 input AWREGION;			
	 input AWUSER;
	 input AWATOP;
	 input AWIDUNQ;
	 input VAWQOSACCEPT;

//-----------------------W channel signals--------------------------------------------------

	 input WVALID;		
	 output WREADY;				
	 input WLAST;			
	 input WDATA;		
	 input WSTRB;	
	 input WUSER;
	input WPOISON;

//-----------------------B channel signals--------------------------------------------------

	output BVALID;				
	input BREADY;			
	output BRESP;			// ----------- to specify that the transaction is completed with or with out errors
	output BID;			// ----------- to tell for which address the resp is coming
	output BUSER;
	output BIDUNQ;
//-----------------------AR channel signals--------------------------------------------------
	
	 input ARVALID;			
	 output ARREADY;				// ---------- slave ack 
	 input ARADDR;  	// ---------- used to define_addressointer 
	 input ARSIZE;		// ---------- defines size of transfer ------- in bytes 
	 input ARBURST;	//----------- type of acces---- fixed --- incriment --- wrap 
	 input ARCACHE;	// ---------- cache storage 
	 input ARPROT;		// ---------- protection specification signal 
	 input ARID;		// ---------- id for the address location 
	 input ARLEN;		// ---------- specifies the length of the transfer 
	 input ARLOCK;			// ---------- specifies locked transfer or not 
	 input ARQOS;			// ---------- specifies the quality of the signal
	 input ARREGION;			
	 input ARUSER;
	 input ARIDUNQ;
	 input ARCHUNCKEN;
	 input VARQOSACCEPT;

//-----------------------R channel signals--------------------------------------------------
	output RVALID;				// ----------- specifies the coming data is valid 
	input RREADY;			// ----------- data ack signal
	output RLAST;				// ----------- to specify the indication that sending last byte in transfer
	output RDATA;			// ----------- data that had to be wriiten to the slave
	output RRESP;			// ----------- to specify that the transaction is completed with or with out errors 
	output RID;			// ----------- for address identification purpose
	output RUSER;
	output RIDUNQ;
	output RCHUNKV;
	output RCHUNKNUM;
	output RCHUNKSTRB;
	output RPOISON;

	endclocking
/*
	always@(posedge clk)begin
		$display($time,"awvalid=%d==awready=%d=wvalid=%d=wready=%d=bvalid=%d=bready=%d==arvalid=%d==arready=%d==rvalid=%d=rready=%d==arlen=%d",AWVALID,AWREADY,WVALID,WREADY,BVALID,BREADY,ARVALID,ARREADY,RVALID,RREADY,ARLEN);

	end

*/
endinterface
