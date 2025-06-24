class AXI5_output_monitor extends uvm_monitor;

//====================factory registration =================
	`uvm_component_utils(AXI5_output_monitor)

//=========================analysis port decleration=================//
	uvm_analysis_port #(AXI5_sequence_item) h_out_mon_analysis;

//====================sequence item instance==================
	AXI5_sequence_item h_seq_item;

//====================config and interface instance===============

	virtual intf h_intf;

	AXI5_config_class h_config;


//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		h_out_mon_analysis=new("h_out_mon_analysis",this);
		h_seq_item = AXI5_sequence_item :: type_id :: create("h_seq_item");
	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		assert(uvm_config_db #(virtual intf) :: get(this , this.get_full_name() , "intf" , h_intf));
		assert(uvm_config_db #(AXI5_config_class)::get(null,this.get_full_name(),"AXI5_config_class",h_config));

	endfunction


//================================run phase=========================

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
			forever @(h_intf.cb_monitor) begin

//-----------------------AW channel signals--------------------------------------------------
		
			if( h_intf.cb_monitor.AWVALID&& h_intf.cb_monitor.AWREADY)begin//{


			h_seq_item.AWVALID = h_intf.cb_monitor.AWVALID;			
			h_seq_item.AWREADY = h_intf.cb_monitor.AWREADY;			
			h_seq_item.AWADDR = h_intf.cb_monitor.AWADDR;  	 
			h_seq_item.AWSIZE = h_intf.cb_monitor.AWSIZE;		
			h_seq_item.AWBURST = h_intf.cb_monitor.AWBURST;
			h_seq_item.AWCACHE = h_intf.cb_monitor.AWCACHE;	
			h_seq_item.AWPROT = h_intf.cb_monitor.AWPROT;	
			h_seq_item.AWID = h_intf.cb_monitor.AWID;		
			h_seq_item.AWLEN = h_intf.cb_monitor.AWLEN;	
			h_seq_item.AWLOCK = h_intf.cb_monitor.AWLOCK;			
			h_seq_item.AWQOS = h_intf.cb_monitor.AWQOS;			
			h_seq_item.AWATOP = h_intf.cb_monitor.AWATOP;
			h_seq_item.AWIDUNQ = h_intf.cb_monitor.AWIDUNQ;

//-----for atomic transaction ----- aw channel signals stored to ar channel signals because for atomic ar channel not invoked---

			if(h_seq_item.AWATOP !=0) begin//{

			
			h_seq_item.ARADDR = h_seq_item.AWADDR;  	 
			h_seq_item.ARBURST = h_seq_item.AWBURST;
			h_seq_item.ARID = h_seq_item.AWID;

			end//}
		
			if (h_seq_item.AWATOP != 49) begin//{
           			 	h_seq_item.ARLEN = h_seq_item.AWLEN;
           				 h_seq_item.ARSIZE = h_seq_item.AWSIZE;
     		end//} 
			else begin//{//----------for atomic compare some size and length required manipulations

          		if (h_seq_item.AWLEN == 0) begin//{
              		h_seq_item.ARLEN = h_seq_item.AWLEN;
               		h_seq_item.ARSIZE = h_seq_item.AWSIZE-1;
          		end//} 
				else begin//{
                	h_seq_item.ARLEN = h_seq_item.AWLEN / 2;
                	h_seq_item.ARSIZE = h_seq_item.AWSIZE;
           		end//}
       		end//}	
	
			h_config.aw_channel_flag=1;
		end//}

//-----------------------W channel signals--------------------------------------------------
			if( h_intf.cb_monitor.WVALID&& h_intf.cb_monitor.WREADY)begin//{
			
			
			
	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

			end//}
//-----------------------------b channel signals---------------------
			if( h_intf.cb_monitor.BVALID&& h_intf.cb_monitor.BREADY)begin//{
			
	 		h_seq_item.BVALID = h_intf.cb_monitor.BVALID;				
	 		h_seq_item.BREADY = h_intf.cb_monitor.BREADY;			
	 		h_seq_item.BRESP = h_intf.cb_monitor.BRESP;			// ----------- to specify that the transaction is completed with or with out errors
	 		h_seq_item.BID = h_intf.cb_monitor.BID;			// ----------- to tell for which address the resp is coming
	 		h_seq_item.BIDUNQ = h_intf.cb_monitor.BIDUNQ;
			h_config.response_flag = 1;

			end//}

//-----------------------AR channel signals--------------------------------------------------


		if(h_intf.cb_monitor.ARVALID&& h_intf.cb_monitor.ARREADY) begin//{
				
	  		h_seq_item.ARVALID = h_intf.cb_monitor.ARVALID;			
	  		h_seq_item.ARREADY = h_intf.cb_monitor.ARREADY;				// ---------- slave ack 
	  		h_seq_item.ARADDR = h_intf.cb_monitor.ARADDR;  	// ---------- used to define_addressointer 
	  		h_seq_item.ARSIZE = h_intf.cb_monitor.ARSIZE;		// ---------- defines size of transfer ------- in bytes 
	  		h_seq_item.ARBURST = h_intf.cb_monitor.ARBURST;	//----------- type of acces---- fixed --- incriment --- wrap 
	  		h_seq_item.ARCACHE = h_intf.cb_monitor.ARCACHE;	// ---------- cache storage 
	  		h_seq_item.ARPROT = h_intf.cb_monitor.ARPROT;		// ---------- protection specification signal 
	  		h_seq_item.ARID = h_intf.cb_monitor.ARID;		// ---------- id for the address location 
	  		h_seq_item.ARLEN = h_intf.cb_monitor.ARLEN;		// ---------- specifies the length of the transfer 
	  		h_seq_item.ARLOCK = h_intf.cb_monitor.ARLOCK;			// ---------- specifies locked transfer or not 
	  		h_seq_item.ARQOS = h_intf.cb_monitor.ARQOS;			// ---------- specifies the quality of the signal
	  		h_seq_item.ARIDUNQ = h_intf.cb_monitor.ARIDUNQ;
			h_seq_item.ARCHUNKEN = h_intf.cb_monitor.ARCHUNCKEN;
			h_config.ar_channel_flag=1;
			

		end//}
//---------------------------R channel has to be invoked when we have ar channel invocation and for atomic expect atomic store--------------------
		if(h_config.ar_channel_flag ||(h_seq_item.AWATOP!=0&&h_config.aw_channel_flag&&h_seq_item.AWATOP[5:4]!=01))	begin //{

			read_data_phase;
		h_config.ar_channel_flag=0;h_config.aw_channel_flag=0;
		end//}
//--------------------------------write method will be invoked when we have invocation of write_response and read_data channels -------			
			if(h_config.response_flag || h_config.read_channel_flag)begin//{

				h_config.output_monitor_write_indicator = 1;
				h_out_mon_analysis.write(h_seq_item);
		//=========================making config temporary varibles as 0
				h_config.BRESP=0;
				h_config.RRESP=0;
				h_config.atomic_error=0;
				if(h_config.response_flag) h_config.b_ch_triggred=1;
				else if(h_config.read_channel_flag) h_config.r_ch_triggred=1;

			end//}
		

			end
		

	endtask


//=====================================================================================================
// =============== task for sending ready to R data channel
//=====================================================================================================

task  read_data_phase();
	bit [((`MAX_AXI5_DATA_WIDTH / 8)-1):0] read_strobe_indicator;	// ----------- to get indication for reading and storing only the exact data ------
	bit[15:0]memory_loc_indicator,aligned_address;	//------for calculation aligned addr and memory pointing conditions----
// ----------------- wrap boundary calculations ----------------------
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Lower_wrap_boundary; 			// ----------- The boundaries for wrap based conditions ---------------.
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Upper_wrap_boundary; 

	bit[31:0] exclusive_support;	// ---- to check wheather slave supports exclusive op or not =================
  begin

	// --------------------------- wrap_calculations ---------------------------------
	Lower_wrap_boundary = ($floor(h_seq_item.ARADDR/((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1))))	* ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1));
	Upper_wrap_boundary = Lower_wrap_boundary + ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN + 1));



	aligned_address = ($floor(h_seq_item.ARADDR/(2**h_seq_item.ARSIZE))) * (2**h_seq_item.ARSIZE); //for calculating the aligned_address to point to next_location 

	h_config.slave_memory_chunknum = new[h_seq_item.ARLEN+1];
	h_config.slave_poison_chunknum = new[h_seq_item.ARLEN+1];

//*******************************************************************************************************
//----------------------setting the read data strobes--------------
//*******************************************************************************************************


	if(h_seq_item.ARBURST == 2 || h_seq_item.ARBURST == 1) begin
		strobe_compute_in_read_data; 
	end
	else begin
		`uvm_info("**** FROM OUT MONITOR *****",$sformatf(" FROM OUT MONITOR--------------- fixed type is not supported else  reserved type is invoked while reading --------"),UVM_LOW);
	end

	for(int i=0;i<=h_config.total_chunks;i++)begin//{
  	  if(!h_intf.ARESETn) begin
		break;
  	  end
  	  else begin//{
			wait(h_intf.cb_monitor.RVALID == 1||!h_intf.ARESETn);
			wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);

  // ----- time out factor running parllely with ready -----------
 			fork
  				wait((h_intf.cb_monitor.RREADY&&h_intf.AWAKEUP&&h_intf.cb_monitor.RVALID)||!h_intf.ARESETn);
				h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_RVALID_ASSERTION_TO_RREADY);
 			join_any;
  			disable fork;

	 		if(h_intf.ARESETn) begin///{

//-----------------------R channel signals--------------------------------------------------
	 		h_seq_item.RVALID = h_intf.cb_monitor.RVALID;				// ----------- specifies the coming data is valid 
	 		h_seq_item.RREADY = h_intf.cb_monitor.RREADY;			// ----------- data ack signal
	 		h_seq_item.RLAST = h_intf.cb_monitor.RLAST;				// ----------- to specify the indication that sending last byte in transfer
	 		h_seq_item.RDATA = h_intf.cb_monitor.RDATA;			// ----------- data that had to be wriiten to the slave
	 		h_seq_item.RRESP = h_intf.cb_monitor.RRESP;			// ----------- to specify that the transaction is completed with or with out errors 
	 		h_seq_item.RID = h_intf.cb_monitor.RID;			// ----------- for address identification purpose
	 		h_seq_item.RIDUNQ = h_intf.cb_monitor.RIDUNQ;
	 		h_seq_item.RCHUNKV = h_intf.cb_monitor.RCHUNKV;
	 		h_seq_item.RCHUNKNUM = h_intf.cb_monitor.RCHUNKNUM;
	 		h_seq_item.RCHUNKSTRB = h_intf.cb_monitor.RCHUNKSTRB;
	  		h_seq_item.RPOISON = h_intf.cb_monitor.RPOISON;
//-------------------------------strobe collection ------------------
 				read_strobe_indicator = h_config.read_valid_strobe_data[i];
//--------------------------------------------------------------------

				aligned_address = ($floor(h_seq_item.ARADDR/(2**h_seq_item.ARSIZE))) * (2**h_seq_item.ARSIZE); // ---- for calculating the aligned_address to point to next_location 

//=============================read opration =================
				if(h_seq_item.ARCHUNKEN ==0) begin
				//-----------------storing rpoision for comparion purpose  in read operation -------------
					h_config.poison_out_monitor_que.push_back(h_seq_item.RPOISON);
	// ------------------ storing only the valid byte which is coming on the rdata pin ------------------------//
					for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1)begin//{
		 	 			if(read_strobe_indicator[j]==1) begin
							h_config.store_rdata_output_monitor.push_back(h_seq_item.RDATA[(j*8)+:8]);
		  				end
					end//}
				end
				else if(h_seq_item.RCHUNKV) begin//{else_begin
						foreach(h_seq_item.RCHUNKSTRB[i]) begin

							if(h_seq_item.RCHUNKSTRB[i]== 1'b1)begin
								//--------------------read data chunking data comparision purpose --------------
								h_config.slave_memory_chunknum[h_seq_item.RCHUNKNUM][(i*128)+:128] = h_seq_item.RDATA[(i*128)+:128];
								//---------------------poision storing for comparison purpose for read data chunking
								 h_config.slave_poison_chunknum[h_seq_item.RCHUNKNUM][(i*2)+:2] = h_seq_item.RPOISON[(i*2)+:2];

							end
						end
					if(h_seq_item.RLAST == 1) begin
						break;
					end
					 
					//	repeat(1) @(h_intf.cb_monitor);	
				//	end : i_loop
				end //}else_if_end


				


// ============================== decerr condition ==============================
				h_seq_item.ARADDR = aligned_address +(2**h_seq_item.ARSIZE);	//--------updating the addr

				if(h_seq_item.ARBURST == 2) begin		// ---- if wrap pointing address to lower boundary if it reaches upper boundary 
					if((h_seq_item.ARADDR >= Upper_wrap_boundary)) h_seq_item.ARADDR = Lower_wrap_boundary;
				end				
				repeat(1) begin @(h_intf.cb_monitor); end
			end//} rst end
			else begin
				break;
			end
  		end//} if(!rst---else end
  	end//} for i end
	h_config.read_channel_flag=1;

//$display($time,"^^&&&&&&&&&&&&&&&&&&&&&&& in output monitor read data phase   %d &&&&&&&&&&&&77777^^^^^^^^ \n\n\n\n\n",h_config.read_channel_flag);

  end//} task end
endtask



// ================================================================================================================ //
    // ======================= function TO  OBTAIN THE VALID BYTES ONLY  DURING READ ====================== //
// ================================================================================================================ //

function void strobe_compute_in_read_data();
 begin
  // ------------- internal variable declartion --------
	bit [((`MAX_AXI5_DATA_WIDTH / 8)-1):0] read_stb; 
	bit [(`MAX_AXI5_ADDRESS_WIDTH -1):0] addr;
// ------------ adress and byte lane calculations for read data purpose -------------
	bit[7:0] Number_Bytes_rd; 				// ----------- The maximum number of bytes in each data transfer.
	bit[15:0]Aligned_Address_rd;	 		// ----------- The aligned version of the start address.
	bit[15:0]Address_N_rd; 					// ----------- The address of transfer N in a burst. N is 1 for the first transfer in a burst.
	bit[7:0] Lower_Byte_Lane_rd; 			// ----------- The byte lane of the lowest addressed byte of a transfer.
	bit[7:0] Upper_Byte_Lane_rd; 
	
	Number_Bytes_rd = 2 ** h_seq_item.ARSIZE;
	addr = h_seq_item.ARADDR;	

	// ------------- strobe calculation for transfers except the first one -----------------
	for(int i =1;i<=h_seq_item.ARLEN+1;i++)begin
	Aligned_Address_rd = ($floor(addr/Number_Bytes_rd)) * Number_Bytes_rd;
		if(i>1) begin
			Address_N_rd = Aligned_Address_rd + (i-1) * Number_Bytes_rd;
			Lower_Byte_Lane_rd = Address_N_rd - (($floor(Address_N_rd/(`MAX_AXI5_DATA_WIDTH/8))) * (`MAX_AXI5_DATA_WIDTH/8));
			Upper_Byte_Lane_rd = Lower_Byte_Lane_rd + Number_Bytes_rd - 1;

			for(int j=Lower_Byte_Lane_rd;j<=Upper_Byte_Lane_rd;j++) begin read_stb[j] = 1; end			
			addr = Aligned_Address_rd;
			h_config.read_valid_strobe_data[i-1] = read_stb;
			read_stb = 'd0;
		end
	// -------------------- strobe calculation for first transfer ------------------
		else begin
			Address_N_rd = Aligned_Address_rd + (i-1) * Number_Bytes_rd;
			Lower_Byte_Lane_rd = addr - (($floor(addr/(`MAX_AXI5_DATA_WIDTH/8))) * (`MAX_AXI5_DATA_WIDTH/8));
			Upper_Byte_Lane_rd = Aligned_Address_rd + (Number_Bytes_rd - 1) - (($floor(addr/(`MAX_AXI5_DATA_WIDTH/8))) * (`MAX_AXI5_DATA_WIDTH/8));

			for(int j=Lower_Byte_Lane_rd;j<=Upper_Byte_Lane_rd;j++) begin read_stb[j] = 1;	end		
			addr = Aligned_Address_rd;
			h_config.read_valid_strobe_data[i-1] = read_stb;
			read_stb = 'd0;
		end
	end
 end
endfunction


endclass











