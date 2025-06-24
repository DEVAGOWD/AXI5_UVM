class AXI5_sequence_item extends uvm_sequence_item;

//==============factory registration ======================

	`uvm_object_utils(AXI5_sequence_item)

//===================construction====================

	function new(string name="");
		super.new(name);
	endfunction

//=================signal declaration==========================
	
//------------------- global signal for all channels -----------
//---------------------------------write address channel signals-----------------------//
		
	randc bit [((`MAX_AXI5_ID_WIDTH) - 1):0] AWID;
	rand bit [1:0]AWBURST;
	rand bit AWLOCK;
	rand bit [5:0]AWATOP;
	rand bit [3:0]AWCACHE;
	rand bit [2:0]AWPROT;
	rand bit AWVALID;
	rand bit AWREADY;
	rand  bit [7:0] AWLEN;
	rand bit [2:0]AWSIZE;
	rand bit [((`MAX_AXI5_ADDRESS_WIDTH) - 1):0] AWADDR;
	rand bit [3:0]AWQOS;
    rand bit AWIDUNQ;
//----------------------------------write data channel signals---------------------------//
	rand bit [((`MAX_AXI5_ID_WIDTH) - 1):0] WID;
	rand bit [(`MAX_AXI5_DATA_WIDTH-1):0]WDATA;
	rand bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0]WSTRB;
	 bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0]WSTRB_arr[];

	bit[((`MAX_AXI5_DATA_WIDTH/8)-1):0]RSTRB[];
	rand bit WLAST;
	rand bit WVALID;
	rand bit WREADY;
	rand bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0]WPOISON;
//---------------------------------write response channel---------------------------------//
	rand bit BREADY;
	rand bit [((`MAX_AXI5_ID_WIDTH) - 1):0]BID;
	rand bit [1:0]BRESP;
	rand bit BVALID;
	rand bit BIDUNQ;	
//-------------------------------------read addres  channel --------------------------------//
	rand bit [((`MAX_AXI5_ADDRESS_WIDTH) - 1):0] ARADDR;
	rand bit [((`MAX_AXI5_ID_WIDTH) - 1):0] ARID;
	rand bit[7:0] ARLEN;
	rand bit[7:0]ARSIZE;
	rand bit[1:0]ARBURST;
	rand bit [3:0]ARQOS;
	rand bit ARLOCK;
	rand bit [3:0]ARCACHE;
	rand bit [2:0]ARPROT;
	rand bit ARVALID;
	rand bit ARREADY;
	rand bit ARIDUNQ;
	rand bit ARCHUNKEN;
//----------------------------------------read data channel siganls------------------------//
	rand bit RREADY;
	rand bit [((`MAX_AXI5_ID_WIDTH) - 1):0] RID;
	rand bit [((`MAX_AXI5_DATA_WIDTH)-1):0]RDATA;
	rand bit [1:0]RRESP;
	rand bit RLAST;
	rand bit RVALID;
	rand bit RIDUNQ;
	rand bit RCHUNKV;
	rand bit [(`MAX_AXI5_DATA_WIDTH/128)-1:0] RCHUNKSTRB;
	rand bit [$clog2((4096*8)/`MAX_AXI5_DATA_WIDTH)-1:0] RCHUNKNUM; 
	rand bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0]RPOISON;
    rand bit[(`MAX_AXI5_DATA_WIDTH/64)-1:0]RPOISON_STORE[];


//=======================================for monitor exclusive access purpose ======================

	bit[`MAX_AXI5_DATA_WIDTH-1:0] exclusive_store_rdata [$];
	bit [(`MAX_AXI5_ADDRESS_WIDTH - 1):0] addr_exclusive;
		bit another_ex_op_invoked;

//----------------------constraint for addr -----------------------------//

/*constraint addr {
					if(AWBRUST==2) AWADDR=AWADDR





				}*/


			
endclass
