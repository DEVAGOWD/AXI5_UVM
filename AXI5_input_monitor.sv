class AXI5_input_monitor extends uvm_monitor;

//====================factory registration =================
	`uvm_component_utils(AXI5_input_monitor)

//=========================analysis port decleration=================//
	uvm_analysis_port #(AXI5_sequence_item) h_in_mon_analysis;


//===============seq item instance========================

	AXI5_sequence_item h_seq_item;

//==================virtual interface instance ============

	virtual intf h_intf;

//======================config instance==================
	AXI5_config_class h_config;


// ================ internal variables ==============
  	bit[(`MAX_AXI5_DATA_WIDTH - 1):0]store_rdata[$];		// ----------- to store the read data obtained from RDATA pin -------

// ------------ for outstanding controlling ------ channel wise indicators -----------------
	bit write_address_indicator,data_indicator,response_indicator,read_address_indicator,read_data_indicator;

//----------------------------------- B response internal ----------------
	bit [1:0] BRESP_mon , RRESP_mon;
	
// ------------------ for storing transactions handles in-order to execute the transactions in order 
	AXI5_sequence_item trans_wr_q[$],trans_rd_q[$];

// ---------------------- memory to store data -----------------------
  	bit[7:0]memory[(4096/(`MAX_AXI5_DATA_WIDTH/8))-1:0][((`MAX_AXI5_DATA_WIDTH/8)-1):0];			
  	bit [7:0]memory_poison[(4096/8)-1:0];			
// ---------------------- for exclusive access purpose ----------------
	AXI5_sequence_item seq_item_exclusive_que[$];

// ============= to store configuration settings
	_max_bit_t configuration_values[0:20] = '{0,0,10000,100000,1,1,1,1,1000,10000,10000,10000,10000,0,1,0,4095,0,0,0,0};		



//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		h_in_mon_analysis=new("h_in_mon_analysis",this);
		h_seq_item= AXI5_sequence_item:: type_id :: create("h_seq_item");

	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		assert(uvm_config_db #(virtual intf) :: get(this , this.get_full_name() , "intf" , h_intf));
		assert(uvm_config_db #(AXI5_config_class)::get(null,this.get_full_name(),"AXI5_config_class",h_config));

	endfunction


//========================run phase=====================

	task run_phase(uvm_phase phase);

		super.run_phase(phase);
		forever @(h_intf.cb_monitor) begin
//====================getting interface signals===================
			get_rw_transaction;
		end

	endtask




// ===================================================================================
// ============= execute transaction task for normal read_write operations ===========
// ===================================================================================

task automatic get_rw_transaction;	//------- class memory content is used for the execution ----
  begin
	wait(h_intf.ARESETn==1);	//--------------------------reset condition wait for ARESETn==1---------

    if(h_config.write_or_read == 1) begin //{
 
//----------------------------------------------------------------------write addr phase
				wait(write_address_indicator == 0);
				get_write_addr_phase();
				write_address_indicator = 0;
				if(h_seq_item.AWATOP == 0) begin			//-------------------for normal operation-----------
					trans_wr_q.push_back(h_seq_item);			//-------------------for getting same order of ids in aw to data and resp 

//----------------------------------------------------------------------write data phase
					wait(data_indicator == 0);
					h_seq_item = trans_wr_q.pop_front();
				end
		
				if(!h_config.exit_transaction) begin//{			//-----------------for unique id condition---------------- 
				 	if(h_seq_item.AWATOP == 0) begin	// -------  checking for non atomic operation -----------
						fork
            				get_write_data_phase;
							write_poison_task;
						join
					end
					else begin	// ---------  if atomic operation corresponding task is invoked ---------------
						execute_atomic_operations;
					end
					data_indicator = 0;
//-------------------------------------------------------------------------write response phase
					wait(response_indicator==0);
					get_write_response_phase;
					response_indicator = 0;
				end//}

	end//}
	else begin//{


//------------------------------------read channel
//----------------------------------------------------------------------read addr phase


			wait(read_address_indicator == 0);
			get_read_addr_phase;
			read_address_indicator = 0;
			trans_rd_q.push_back(h_seq_item);

//-----------------------------------------------------------------------read data phase
			wait(read_data_indicator==0);
			h_seq_item = trans_rd_q.pop_front();
			if(!h_config.exit_transaction) begin	
					if(h_seq_item.ARCHUNKEN == 1) begin
							execute_read_data_chunking();
					end
			  		else begin
						fork
							get_read_data_phase();
							read_poison_task();
						join
					end
			end
			read_data_indicator = 0;
	end//}
  end
endtask






// ================================================================================================================
// ========================================== for atomic operations ===============================================
// ================================================================================================================

task automatic execute_atomic_operations();
  shortint Number_bytes;		// ------------- to check the no:of bytes transferring in the transaction ------------
  shortint Aligned_Address;		// --------------- to check whether address is aligned or not ------------------
  bit [(`MAX_AXI5_ADDRESS_WIDTH - 1):0] addr;
begin

// ---------------- calculating total no:of bytes in transaction -----------------------
	Number_bytes = (h_seq_item.AWLEN + 1) * (2 ** h_seq_item.AWSIZE);

// ------------for wrap we have to send only 2 or 4 or 8 or 16 beats and in atomic operation wrap condition length 0 also possible -------------
	if(h_seq_item.AWBURST == 2) begin
		case(h_seq_item.AWLEN)
			0,1,3,7,15 : begin BRESP_mon = 0; RRESP_mon = 0; end
			default  : begin BRESP_mon = 2; RRESP_mon = 2;  end
		endcase
	end


// ------------- slave error condition checkings ------------------
   if(h_seq_item.AWATOP == 'b110001 && h_seq_item.AWBURST == 1) begin
	Aligned_Address = $floor(h_seq_item.AWADDR/(Number_bytes)) * Number_bytes;	// ----------- compare incriment addr should be aligned
	if(Aligned_Address != h_seq_item.AWADDR) begin BRESP_mon = 2;	RRESP_mon = 2; end				// ----------- to total no:of bytes
  end

  else if(h_seq_item.AWATOP == 'b110001 && h_seq_item.AWBURST == 2) begin
	Aligned_Address = $floor(h_seq_item.AWADDR/(Number_bytes/2)) * (Number_bytes/2);	// -- compare wrap addr should be aligned to
	if(Aligned_Address != h_seq_item.AWADDR)  begin BRESP_mon = 2; RRESP_mon = 2; end
							// --- half of total no:of bytes
  end

  else begin
	Aligned_Address = ($floor(h_seq_item.AWADDR/(Number_bytes))) * (Number_bytes);	// ---- normal error checkings for swap,load,store
	if(Aligned_Address != h_seq_item.AWADDR)begin BRESP_mon = 2;RRESP_mon = 2;end 
  end


// -------------- no:of bytes should be in 2 powers ------------------
	if ((Number_bytes & (Number_bytes - 1)) != 0 ) begin BRESP_mon = 2; RRESP_mon = 2; end

// --- if len >0 and size != data width--If AWLEN indicates a burst length greater than one, AWSIZE is required to be the full data bus width.
	if(((2**h_seq_item.AWSIZE) != (`MAX_AXI5_DATA_WIDTH/8)) &&(h_seq_item.AWLEN > 0)) begin
		 BRESP_mon = 2;RRESP_mon = 2;
	end
	
	h_config.read_valid_strobe_data=new[h_seq_item.AWLEN+1];
// ----------------------- invoking the tasks ---------------------------
	
	if(h_seq_item.AWATOP == 'b110000) begin			//---------------- Atomic swap 
		if(Number_bytes > 8) BRESP_mon = 2;
		if(h_seq_item.AWBURST == 2) BRESP_mon = 2;
		wait(read_data_indicator==0);
		addr = h_seq_item.AWADDR;
		fork
			get_read_data_phase;
			read_poison_task;
		join
		h_seq_item.AWADDR = addr;
				wait(data_indicator == 0);
		fork
			get_write_data_phase;
			write_poison_task;
		join
	end
	else if(h_seq_item.AWATOP == 'b110001) begin		//---------------- Atomic compare
		if(Number_bytes > 32) BRESP_mon = 2;
		if(Number_bytes == 1) BRESP_mon = 2;
		wait(read_data_indicator==0);
		addr = h_seq_item.AWADDR;
			atomic_compare_read_data_phase;
		h_seq_item.AWADDR = addr;
				wait(data_indicator == 0);
			atomic_compare_write_data_phase;
	end
	else if(h_seq_item.AWATOP[5:4] == 'b01) begin
	//--------------- Atomic store
		
		if(Number_bytes > 8) BRESP_mon = 2;

		if(h_seq_item.AWBURST == 2)  BRESP_mon = 2; 
 
				wait(data_indicator == 0);
		fork
			atomic_store_load_data_phase;
			write_poison_task;
		join
	end
	else if(h_seq_item.AWATOP[5:4] == 'b10) begin	//-------------- Atomic load
		if(Number_bytes > 8) BRESP_mon = 2;
		if(h_seq_item.AWBURST == 2) BRESP_mon=2;
		wait(read_data_indicator==0);
		addr = h_seq_item.AWADDR;
		fork
			get_read_data_phase;
			read_poison_task;
		join
		h_seq_item.AWADDR = addr;
		wait(data_indicator == 0);
		fork
			atomic_store_load_data_phase;
			write_poison_task;
		join
	end
end
endtask




//***************************************************************************************************************
//======================address phase ===================
// ============== task for sending AW channel signalls to the dut =============
task get_write_addr_phase;
	AXI5_sequence_item h_trans_seq_item;			//-------------for exclusive access purpose---------

 begin//{

  if(h_intf.ARESETn) begin//{
	write_address_indicator=1;
	wait(h_intf.cb_monitor.AWVALID	== 1||!h_intf.ARESETn);
	wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
	
	`uvm_info(" FROM ADDRESS PHASE INPUT MONITOR  ", $sformatf("FROM MONITOR===============WRITE ADDRESS PHASE================ OF ID --- %0d ",h_intf.cb_monitor.AWID),UVM_LOW);
//============================================================================================
// ------------------ checking wheather id is already existed or not -------------------
	if(h_config.unique_id_indicator.exists(h_intf.cb_monitor.AWID)) begin//{
	// ========================= atomic purpose check in atomic operation must be follow unique id condition========================== //
		if(h_intf.cb_monitor.AWATOP != 0)begin
			$fatal($time," FROM MONITOR =================atomic transcation is not maintaining unique id ====================");
		end
	  foreach(h_config.unique_id_indicator[h_intf.cb_monitor.AWID][i]) begin
		if(h_config.unique_id_indicator[h_intf.cb_monitor.AWID][i] == 1 || h_intf.cb_monitor.AWIDUNQ == 1) begin
			$error($time,"FROM MONITOR ------------- not following unique id operation so not accepting the operation ----------------\n\n");
			h_config.exit_transaction = 1;
			break;
		end
	  end
		
	  if(!h_config.exit_transaction) h_config.unique_id_indicator[h_intf.cb_monitor.AWID].push_back(h_intf.cb_monitor.AWIDUNQ);
		
	end//}

	else begin
		h_config.unique_id_indicator[h_intf.cb_monitor.AWID].push_back(h_intf.cb_monitor.AWIDUNQ);
	end


//=============================================================================================

// ------------ control to avoid operaqtion if it is not an unique id --------------
  if(!h_config.exit_transaction) begin


  	fork
  		wait((h_intf.cb_monitor.AWVALID && h_intf.AWAKEUP && h_intf.cb_monitor.AWREADY)||!h_intf.ARESETn);
		h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_AWVALID_ASSERTION_TO_AWREADY);
  	join_any;
  	disable fork;


	if(h_intf.ARESETn) begin//{
//-----------------------AW channel signals--------------------------------------------------
			h_seq_item.AWVALID = h_intf.cb_monitor.AWVALID;			
			h_seq_item.AWREADY = h_intf.cb_monitor.AWREADY;			
			h_seq_item.AWADDR = h_intf.cb_monitor.AWADDR; 
		
			h_config.addr_poison = h_intf.cb_monitor.AWADDR;			
 	 
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
			if(h_seq_item.AWATOP !=0) begin			
				h_seq_item.ARADDR = h_seq_item.AWADDR;  	 
				h_seq_item.ARSIZE = h_seq_item.AWSIZE;		
				h_seq_item.ARBURST = h_seq_item.AWBURST;
				h_seq_item.ARID = h_seq_item.AWID;
				h_seq_item.ARLEN = h_seq_item.AWLEN;	
			end

//***************************************************************************
// ------------------------- for exclusive access --------------------------//
//****************************************************************************
		if(h_seq_item.AWLOCK == 1) begin//{
			foreach(seq_item_exclusive_que[i]) begin//{
				h_trans_seq_item = seq_item_exclusive_que[i];

				if(h_trans_seq_item.ARID == h_seq_item.AWID) begin//{

					if((h_seq_item.addr_exclusive == h_trans_seq_item.addr_exclusive) && (h_seq_item.AWLEN == h_trans_seq_item.ARLEN) && 
						(h_seq_item.AWBURST == h_trans_seq_item.ARBURST) && (h_seq_item.AWSIZE == h_trans_seq_item.ARSIZE)) begin//{
						h_config.exclusive_op_found = 1;	//  ----- ex_okay indication
						h_seq_item.exclusive_store_rdata = h_trans_seq_item.exclusive_store_rdata;
						h_config.write_strobes = h_config.read_valid_strobe_data;
// ------- deleting the memory from the list of exclusive access queue -----------------------
						seq_item_exclusive_que.delete(i);

					end//}
					if(h_trans_seq_item.another_ex_op_invoked==1) begin
						h_config.exclusive_op_found = 2;

					end

				end//}
			end//}

				if(h_config.exclusive_op_found != 1 ) begin
					BRESP_mon = 0;//-----update
					$error($time," FROM MONITOR ----- exclusive write invoked with out read operation or any of attributes are NOT MATCHED --------Op_found:%0d",h_config.exclusive_op_found);

				end
		end//}

//************************************************************************************************************

		// --------------------------- for atomic purpose -------------------------- //

		if((h_seq_item.AWATOP != 0) && !h_seq_item.AWIDUNQ) begin
			$fatal($time," FROM MONITOR ---- unique id not raised for atomic operation --------------");
		end

	end//}---- if ARESETn end

// -------------------- reset else condition -------------------
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
	end

  end//---- if !exit_transaction --end

	@(h_intf.cb_monitor)write_address_indicator=0;

 end//}-------- at begining if ARESETn --- end
 else begin
	foreach(h_config.unique_id_indicator[i]) begin
		h_config.unique_id_indicator.delete(i);
	end
 end

end//}-------task begin -- end
endtask

//=================================write data phase=======================
// ============== task for sending W channel signalls to the dut
task get_write_data_phase;
 begin
// ------------ for wrap we have to send only 2 or 4 or 8 or 16 beats -------------
	if(h_seq_item.AWBURST == 2) begin
		case(h_seq_item.AWLEN)
			1,3,7,15 : BRESP_mon = BRESP_mon;
			default  : BRESP_mon = 2;
		endcase
	end


	if(h_seq_item.AWBURST == 2) begin
      get_write_data_phase_WRAP();
	end
	else if(h_seq_item.AWBURST == 1) begin
      get_write_data_phase_INCR();
	end
	else `uvm_info("FROM MONITOR ******* GET WRITE DATA PHASE ******* ",$sformatf("  FROM MONITOR--------------- fixed type is not supported else  reserved type is invoked -------------------"),UVM_LOW);
 end
endtask




// ========================================================================================================================= //
// ================= Task for getting and stroring the data into memory during incr condition ============================== //
// ========================================================================================================================= //

task get_write_data_phase_INCR();
	// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;
	bit[7:0]temp_compare;	//----------------for exclusive access data storing purpose 	
 begin
	`uvm_info("FROM MONITOR ***** get_write_data_phase_INCR ***** ",$sformatf(" FROM MONITOR============ WRITE DATA PHASE INCR========== OF ID --- %0d \n\n",h_seq_item.AWID),UVM_LOW);
	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 ) BRESP_mon = 3;
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) BRESP_mon = 2;



//***********************************************************************************************************************
// ====================== memory tracking and intenal respose updating for exclusive access =========================== //
	if(h_seq_item.AWLOCK && (BRESP_mon != 2) && (BRESP_mon != 3)) begin


	  for(int i=0;i<=h_seq_item.AWLEN;i++) begin
		for(int j=0;j<(`MAX_AXI5_DATA_WIDTH)/8;j++)begin
			if(h_config.write_strobes[i][j]) begin			// ------------------ based on strobe checking memory contents 
				if(h_config.exclusive_op_found==1)temp_compare = h_seq_item.exclusive_store_rdata.pop_front();	// ------------ popong the data from queue
			//	$display("Memory-----%0d-------temp_comap------>%0d",memory[row][col],temp_compare);
				if(temp_compare == memory[row][col]) begin
					if(h_config.exclusive_op_found != 1) BRESP_mon=0;
					else BRESP_mon = 1;			// ----------------- ex_okay response 
					col++;
					if(`MAX_AXI5_DATA_WIDTH==8) begin
						if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
					end
					else begin
						if(col==0) row++;
					end
				end
				else begin

					BRESP_mon = 0;		// ----------------- okay response 
					h_config.exclusive_op_found = 2;	// ----- indication to say that exclusive access is failed 
					col++;
					if(`MAX_AXI5_DATA_WIDTH==8) begin
						if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
					end
					else begin
						if(col==0) row++;
					end
				end
			end
		end
	  end
// ------- updating response to okay ------------ if exclsuive access is failed ----when middle of addr --data is changed then entire addr range should be okay response 
	  if(h_config.exclusive_op_found == 2) begin
			BRESP_mon = 0;
			$error($time,"FROM MONITOR ------- MEMORY UPDATED BETWEEN EXCLUSIVE READ AND EXCLUSIVE WRITE OR MISMATCH ATTRIBUTES--------");
	  end
// --------- again calculating row and col values to point to excat memory location ---------------------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	end

//***********************************************************************************************************************************



	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction_mon=1;	//----------------there is no ARESETn then it is 1 for stopping the transaction------
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;

	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  		fork
  			wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
			h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  		join_any;
  		disable fork;
		if(h_intf.ARESETn) begin			

			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

   // ------------------------------- basic write check ----------------------
			if(!h_seq_item.AWLOCK) begin
		  		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
					if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin
              			if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096)begin BRESP_mon = 3;  end
              			else begin
                			memory[row][col] = h_seq_item.WDATA[(j*8)+:8];
							col = col + 1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
              			end
					end
		  		end	
			end
    // ------------------------------ exclusive write check -------------------
			else begin
		  		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
					if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3) && (BRESP_mon != 0)) begin
              			if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096)begin BRESP_mon = 3;  end
              			else begin
                			memory[row][col] = h_seq_item.WDATA[(j*8)+:8];
							col = col + 1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
              			end
					end
		  		end	
			end


// -------------- checking wlast feature condition ---------------------------------
			if(i == h_seq_item.AWLEN) begin
				h_config.wlast_indicator_mon = 1;
				if(h_seq_item.WLAST != 1) begin
					`uvm_error(" FROM MONITOR========================= not geeting wlast in last beat ======================",$sformatf("===================WLAST = %d ",h_seq_item.WLAST));
				end
			end
			else begin
				h_config.wlast_indicator_mon = 0;
				if(h_seq_item.WLAST == 1) begin
					`uvm_error(" FROM MONITOR=========================  getting wlast in middle  of the transaction ======================",$sformatf("===================WLAST = %d ",h_seq_item.WLAST));
				end

			end
			repeat(2) begin @(h_intf.cb_monitor);end
		end//----------if ARESETn end
		else begin
			foreach(h_config.unique_id_indicator[i]) begin
				h_config.unique_id_indicator.delete(i);
			end
			break;
		end
	 end//------------if !ARESETn else end---
	end//-------------for i end

	data_indicator = 0;
 end//----------task begin --  end
endtask



// ========================================================================================================================= //
// ================= Task for getting and stroring the data into memory during wrap condition ============================== //
// ========================================================================================================================= //

task  get_write_data_phase_WRAP();
	// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;
// ----------------- wrap boundary calculations ----------------------
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Lower_wrap_boundary; 			// ----------- The boundaries for wrap based conditions ---------------.
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Upper_wrap_boundary; 	
	bit[7:0] Number_Bytes; 				// ----------- The maximum number of bytes in each data transfer.
	bit[15:0]Aligned_Address;	 		// ----------- The aligned version of the start address.
	bit[7:0]temp_compare;				//-------------------for exclusive access data storing purpose------
 begin
	`uvm_info(" ***** get_write_data_phase_WRAP ***** ",$sformatf(" FROM MONITOR============ WRITE DATA PHASE WRAP========== OF ID --- %0d ",h_seq_item.AWID),UVM_LOW);

  // ====================== calculations to check the initial address is aligned or not ==================//
	Number_Bytes = 2 ** h_seq_item.AWSIZE;
//	addr = h_seq_item.AWADDR;	

	Aligned_Address = ($floor(h_seq_item.AWADDR/Number_Bytes)) * Number_Bytes;

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// --------------------------- wrap_calculations ---------------------------------
	Lower_wrap_boundary = ($floor(h_seq_item.AWADDR/((2**h_seq_item.AWSIZE)*(h_seq_item.AWLEN+1))))	* ((2**h_seq_item.AWSIZE)*(h_seq_item.AWLEN+1));
	Upper_wrap_boundary = Lower_wrap_boundary + ((2**h_seq_item.AWSIZE)*(h_seq_item.AWLEN+1));

   
	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end
	// ------------------- checking for address is aligned or not --------------
   else if(Aligned_Address != h_seq_item.AWADDR) begin BRESP_mon = 2; end


//***********************************************************************************************************************
// ====================== memory tracking and internal respose updating for exclusive access for resp purpose =========================== //
	if(h_seq_item.AWLOCK && (BRESP_mon != 2) && (BRESP_mon != 3)) begin 

	  for(int i=0;i<=h_seq_item.AWLEN;i++) begin
		for(int j=0;j<(`MAX_AXI5_DATA_WIDTH)/8;j++)begin
			if(h_config.write_strobes[i][j]) begin			// ------------------ based on strobe checking memory contents 
				if(h_config.exclusive_op_found==1)temp_compare = h_seq_item.exclusive_store_rdata.pop_front();	// ------------ popong the data from queue
				if(temp_compare == memory[row][col]) begin
					if(h_config.exclusive_op_found!=1) BRESP_mon=0;	//---update
					else BRESP_mon = 1;			// -----update------------ ex_okay response 
					col++;
					if(`MAX_AXI5_DATA_WIDTH==8) begin
						if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
					end
					else begin
						if(col==0) row++;
					end
					h_seq_item.AWADDR = h_seq_item.AWADDR+1;
					if(h_seq_item.AWADDR == Upper_wrap_boundary) begin
						h_seq_item.AWADDR = Lower_wrap_boundary;
	// ---------- again pointing the exact memory location -----------
						row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));
						col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8))));
					end
				end
				else begin
					BRESP_mon = 0;		// ----------------- okay response 
					h_config.exclusive_op_found = 2;	// ----- indication to say that exclusive access is failed 
					col++;
					if(`MAX_AXI5_DATA_WIDTH==8) begin
						if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
					end
					else begin
						if(col==0) row++;
					end
					h_seq_item.AWADDR = h_seq_item.AWADDR+1;
					if(h_seq_item.AWADDR == Upper_wrap_boundary) begin
						h_seq_item.AWADDR = Lower_wrap_boundary;
	// ---------- again pointing the exact memory location -----------
						row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));
						col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8))));
					end
				end
			end
		end
	  end
// ------- updating response to okay,if exclsuive access is failed ---when middle of addr --data is changed then entire addr range should be okay response 

	  if(h_config.exclusive_op_found == 2) begin 
			BRESP_mon = 0;
			$error($time,"FROM MONITOR ------- MEMORY UPDATED BETWEEN EXCLUSIVE READ AND EXCLUSIVE WRITE OR MISMATCH ATTRIBUTES--------");
	  end
// --------- again calculating row and col values to point to excat memory location ---------------------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	end
//****************************************************************************************************************************************

//**********************************************************************
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction_mon=1;
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;

	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID  == 1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  		fork
  				wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
			h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  		join_any;
  		disable fork;
		if(h_intf.ARESETn) begin

			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;


	// ========================= basic write check ============================//
			if(!h_seq_item.AWLOCK)	begin				
		  		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
					if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin
              			if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096)begin BRESP_mon = 3;  end
              			else begin
							memory[row][col] = h_seq_item.WDATA[(j*8)+:8];
							col = col + 1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
							h_seq_item.AWADDR = h_seq_item.AWADDR+1;
							if(h_seq_item.AWADDR == Upper_wrap_boundary) begin
								h_seq_item.AWADDR = Lower_wrap_boundary;
								// ---------- again pointing the exact memory location -----------
								row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));
								col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 
							end
              			end
					end
		  		end
			end
	// =========================== exclusive write check ==========================//
			else begin
		  		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
					if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3) &&(BRESP_mon != 0)) begin
              			if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096)begin BRESP_mon = 3;  end
              			else begin
							memory[row][col] = h_seq_item.WDATA[(j*8)+:8];
							col = col + 1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
							h_seq_item.AWADDR = h_seq_item.AWADDR+1;
							if(h_seq_item.AWADDR == Upper_wrap_boundary) begin
								h_seq_item.AWADDR = Lower_wrap_boundary;
								// ---------- again pointing the exact memory location -----------
								row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));
								col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 
							end
              			end
					end
		  		end
			end	
// -------------- checking wlast feature condition ---------------------------------
			if(i == h_seq_item.AWLEN) begin
				h_config.wlast_indicator_mon = 1;
				if(h_seq_item.WLAST != 1) begin
					`uvm_error(" FROM MONITOR========================= not geeting wlast in last beat ======================",$sformatf("===================WLAST = %d ",h_seq_item.WLAST));
				end
			end
			else begin
				h_config.wlast_indicator_mon = 0;
				if(h_seq_item.WLAST == 1) begin
					`uvm_error(" FROM MONITOR=========================  getting wlast in middle  of the transaction ======================",$sformatf("===================WLAST = %d ",h_seq_item.WLAST));
				end

			end
			repeat(2) begin @(h_intf.cb_monitor);end

		end//-----if ARESETn end
		else begin
			foreach(h_config.unique_id_indicator[i]) begin
				h_config.unique_id_indicator.delete(i);
			end
			break;

		end
	 end//-----------if !ARESETn else end
  end//-----------for i end
	data_indicator=0;
 end//---------task begin -- end
endtask


//================================================================================================
// ============================================================================= task for sending ready to Bresp channel
//===================================================================================================
task get_write_response_phase();
 begin//{

  if(h_intf.ARESETn && !h_config.terminate_transaction_mon) begin//{
	response_indicator=1;
	wait(h_intf.cb_monitor.BVALID == 1 || !h_intf.ARESETn);
	wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);

  // ----- time out factor running parllely with ready -----------
  	fork
  		wait((h_intf.cb_monitor.BREADY&&h_intf.AWAKEUP&&h_intf.cb_monitor.BVALID)||!h_intf.ARESETn);
		h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_BVALID_ASSERTION_TO_BREADY);
  	join_any;
  	disable fork;
	`uvm_info(" *****  FROM MONITOR ***** ",$sformatf(" FROM MONITOR============ WRITE RESPONSE PHASE========= OF ID --- %0d ",h_seq_item.AWID),UVM_LOW);
	if(h_intf.ARESETn) begin//{
//-----------------------B channel signals--------------------------------------------------

	 		h_seq_item.BVALID = h_intf.cb_monitor.BVALID;				
	 		h_seq_item.BREADY = h_intf.cb_monitor.BREADY;			
	 		h_seq_item.BRESP = BRESP_mon;			// ----------- to specify that the transaction is completed with or with out errors
	 		h_seq_item.BID = h_seq_item.AWID;			// ----------- to tell for which address the resp is coming
	 		h_seq_item.BIDUNQ = h_seq_item.AWIDUNQ;



// ------------------ deleting the location if that id is exist -------------------
  // --------- only scenario that assoc array will not store is outstanding operations 
  // --------- with no uniques id feature it will store only one transactin data not all.

		if(h_config.unique_id_indicator.exists(h_seq_item.AWID)) begin
// -------------- deleting the completed id from assoc array -----------
			h_config.unique_id_indicator[h_seq_item.AWID].delete(0);
// -------------- if size of that id based queue is 0 then removing the location from assoc array -------------
			if(h_config.unique_id_indicator[h_seq_item.AWID].size == 0)
				h_config.unique_id_indicator.delete(h_seq_item.AWID);
		end


	//	@(h_intf.cb_monitor) 
		response_indicator=0;

	end//}--------if ARESETn end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
	end

  end//}---------- if ARESETn and terminate_transaction end
  else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
  end


//==========================calling write method for scoreboard comparision============
			h_in_mon_analysis.write(h_seq_item);
			RRESP_mon=0; BRESP_mon=0;
			h_config.input_monitor_write_indicator = 1;

 end//} task begin --- end
endtask




//===============================================================================================
// ============== task for sending AR channel signalls to the dut =============
//==============================================================================================
task  get_read_addr_phase();		
  shortint Number_bytes;		// ------------- to check the no:of bytes transferring in the transaction ------------
  shortint Aligned_Address;		// --------------- to check whether address is aligned or not ------------------
	bit[31:0] exclusive_support;	// ---- to check wheather slave supports exclusive op or not =================
	AXI5_sequence_item h_trans_seq_item;	//---------------for exclusive access purpose----------

 begin

  if(h_intf.ARESETn) begin
	read_address_indicator=1;
	wait(h_intf.cb_monitor.ARVALID	== 1||!h_intf.ARESETn);
	wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
	`uvm_info(" ***** FROM MONITOR get_read_addr_phase ***** ",$sformatf(" FROM MONITOR============ READ ADDRESS PHASE========== OF ID --- %0d ",h_intf.cb_monitor.ARLEN),UVM_LOW);


//********************************************************************************************8
// ------------------ checking wheather id is already existed or not -------------------

	if(h_config.unique_id_indicator.exists(h_intf.cb_monitor.ARID)) begin

	// ====================== read data chunk id check ================== //
	  if(h_intf.cb_monitor.ARCHUNCKEN == 1) begin
			$fatal($time,"FROM MONITOR --------- for read data chunking outstanding operation with same id has no to be performed -----------\n\n");
	  end

	  foreach(h_config.unique_id_indicator[h_intf.cb_monitor.ARID][i]) begin
		if(h_config.unique_id_indicator[h_intf.cb_monitor.ARID][i] == 1 || h_intf.cb_monitor.ARIDUNQ == 1) begin
			$fatal($time,"FROM MONITOR ------------- not following unique id operation so not accepting the operation ----------------\n\n");
			h_config.exit_transaction = 1;
			break;
		end
	  end
	  if(!h_config.exit_transaction)									// ----- previously in place of $fatal i have $error so all controllings are there
		h_config.unique_id_indicator[h_intf.cb_monitor.ARID].push_back(h_intf.cb_monitor.ARIDUNQ);		// ----- now assuming to rise fatal so changed $error to $fatal cause master cant override AWchannel
	end																// ----- signalls without handshaking.... if happend it is functionality error.

	else begin
		h_config.unique_id_indicator[h_intf.cb_monitor.ARID].push_back(h_intf.cb_monitor.ARIDUNQ);
	end

//*************************************************************************************************************************


// ------------ control to avoid operaqtion if it is not an unique id --------------
  	if(!h_config.exit_transaction) begin//{

  	// ----- time out factor running parllely with ready -----------
  		fork
  			wait((h_intf.cb_monitor.ARREADY&&h_intf.AWAKEUP&&h_intf.cb_monitor.ARVALID)||!h_intf.ARESETn);
			h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_ARVALID_ASSERTION_TO_ARREADY);
  		join_any;
  		disable fork;

		if(h_intf.ARESETn)begin//{

			h_seq_item = new("h_seq_item");
//-----------------------AR channel signals--------------------------------------------------
	
	  		h_seq_item.ARVALID = h_intf.cb_monitor.ARVALID;			
	  		h_seq_item.ARREADY = h_intf.cb_monitor.ARREADY;				// ---------- slave ack 
	  		h_seq_item.ARADDR = h_intf.cb_monitor.ARADDR;  	// ---------- used to define_addressointer

//-------------for poision and exclusive purpose ------------------------
			h_config.addr_poison = h_intf.cb_monitor.ARADDR;
			h_seq_item.addr_exclusive = h_intf.cb_monitor.ARADDR;

 
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

	//=============================================================================//

// --------------------------- for read data chunking --------------------
			if(h_seq_item.ARCHUNKEN && !h_seq_item.ARIDUNQ) begin
				$fatal($time," FROM MONITOR ------------ not following unique id feature ------------");
			end

	
//***************************************************************************************************	
//=========================== for exclusive attributes check ============================
			if(h_seq_item.ARLOCK) begin//{
// ---------------- calculating total no:of bytes in transaction -----------------------
				Number_bytes = (h_seq_item.ARLEN + 1) * (2 ** h_seq_item.ARSIZE);
//-----------------------aligned addresive_ss conditon---------------
				Aligned_Address = $floor(h_seq_item.ARADDR/(Number_bytes)) * Number_bytes;
//------The burst length for an exclusive access must not exceed 16 transfers.
				if((h_seq_item.ARLEN) > 'd15)
			 		$error($time,"FROM MONITOR --- The no.of transfers are exceeds from 16 transfers for exclusivhe access \n\n");
//------The address of an exclusive access must be aligned to the total number of bytes in the transaction, that is, the
//------product of the burst size and burst length.
				if(Aligned_Address != h_seq_item.ARADDR)
					$error($time,"FROM MONITOR ----The address not aligned to total number of bytes of transaction for exclusive access----\n\n");	
// -------------- no:of bytes should be in 2 powers ------------------
				if (((Number_bytes & (Number_bytes - 1)) != 0 ) || (Number_bytes > 'd128)) 
					$error($time," FROM MONITOR ---- total no.of bytes are not powers of 2 and exceeds then 128 bytes for exclusive access \n\n");

			end//}
//**************************************************************************************************
		
	
		end//}--- if ARESETn end
		else begin
			foreach(h_config.unique_id_indicator[i]) begin
				h_config.unique_id_indicator.delete(i);
			end
		end

  	end//}---- if exit_transaction end

 		@(h_intf.cb_monitor) read_address_indicator=0;

  end//------------begining if ARESETn -- end
  else begin
	  foreach(h_config.unique_id_indicator[i]) begin
		  h_config.unique_id_indicator.delete(i);
	  end
  end
 
 end//-----task begin -- end
endtask

//=====================================================================================================
// =============== task for sending ready to R data channel
//=====================================================================================================

task  get_read_data_phase();
	bit [((`MAX_AXI5_DATA_WIDTH / 8)-1):0] read_strobe_indicator;	// ----------- to get indication for reading and storing only the exact data ------
	bit[15:0]memory_loc_indicator,aligned_address;	//------for calculation aligned addr and memory pointing conditions----
// ----------------- wrap boundary calculations ----------------------
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Lower_wrap_boundary; 			// ----------- The boundaries for wrap based conditions ---------------.
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Upper_wrap_boundary; 

	bit[31:0] exclusive_support;	// ---- to check wheather slave supports exclusive op or not =================

	AXI5_sequence_item h_trans_seq_item;

  begin

//*************************************************************
// -------------------------- calculations --------------------
//*************************************************************

	read_data_indicator=1;


	if(h_intf.cb_monitor.AWATOP !=0) begin RRESP_mon = BRESP_mon;   end

// ------------ for wrap we have to send only 2 or 4 or 8 or 16 beats -------------

	if((h_seq_item.ARBURST == 2) && !h_seq_item.AWATOP) begin		//-------for non-atomic condition
		case(h_seq_item.ARLEN)
			1,3,7,15 : RRESP_mon = RRESP_mon;
			default  : RRESP_mon = 2;
		endcase

	end
	else if((h_seq_item.ARBURST == 2) && (h_seq_item.AWATOP != 0 )) begin		//------------for atomic operation condition
		case(h_seq_item.ARLEN)
			0,1,3,7,15 : RRESP_mon = RRESP_mon;
			default  : RRESP_mon = 2;
		endcase
	end

	// --------------------------- wrap_calculations ---------------------------------
	Lower_wrap_boundary = ($floor(h_seq_item.ARADDR/((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1))))	* ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1));
	Upper_wrap_boundary = Lower_wrap_boundary + ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN + 1));


//****************************************************************************************************
// -------------------- decode error condition ----------------
	if(h_seq_item.ARADDR >= 4096) RRESP_mon = 3;

	else if(((2**h_seq_item.ARSIZE)+h_seq_item.ARADDR) >= 4096) begin
		RRESP_mon = 3;
	end
// -------------- slave error condition -------------------
	else if(((2**h_seq_item.ARSIZE) > (`MAX_AXI5_DATA_WIDTH/8)) && (h_intf.ARESETn)) begin
		RRESP_mon = 2;
	end

	aligned_address = ($floor(h_seq_item.ARADDR/(2**h_seq_item.ARSIZE))) * (2**h_seq_item.ARSIZE); //for calculating the aligned_address to point to next_location 


	if((aligned_address != h_seq_item.ARADDR) && (h_seq_item.ARBURST == 2)) RRESP_mon = 2;		// ----  wrap contion must be a aligned addr check --------

//*******************************************************************************************************
//----------------------setting the read data strobes--------------
	if(h_seq_item.ARBURST == 2 || h_seq_item.ARBURST == 1) begin

		strobe_compute_in_read_data; 
	end
	else begin
		`uvm_info("**** FROM MONITOR *****",$sformatf(" FROM MONITOR--------------- fixed type is not supported else  reserved type is invoked while reading --------"),UVM_LOW);
	end

	`uvm_info("***** FROM MONITOR *****",$sformatf(" FROM MONITOR==================== READ DATA PHASE =========================== OF ID --- %0d",h_intf.cb_monitor.RID),UVM_LOW);

	for(int i=0;i<=h_seq_item.ARLEN;i++)begin//{

  	  if(!h_intf.ARESETn) begin

		break;
  	  end
  	  else begin//{

			wait(h_intf.cb_monitor.RVALID == 1||!h_intf.ARESETn);

			wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);


  // ----- time out factor running parllely with ready -----------

 			fork
				begin

					wait((h_intf.cb_monitor.RREADY&&h_intf.AWAKEUP&&h_intf.cb_monitor.RVALID)||!h_intf.ARESETn);

				end
				h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_RVALID_ASSERTION_TO_RREADY);
 			join_any;
  			disable fork;

	 		if(h_intf.ARESETn) begin///{

//-----------------------R channel signals--------------------------------------------------
	 		h_seq_item.RVALID = h_intf.cb_monitor.RVALID;				// ----------- specifies the coming data is valid 
	 		h_seq_item.RREADY = h_intf.cb_monitor.RREADY;			// ----------- data ack signal
	 //		h_seq_item.RLAST = h_intf.cb_monitor.RLAST;				// ----------- to specify the indication that sending last byte in transfer
//	 		h_seq_item.RDATA = h_intf.cb_monitor.RDATA;			// ----------- data that had to be wriiten to the slave
	 		h_seq_item.RID = h_seq_item.ARID;			// ----------- for address identification purpose
	 		h_seq_item.RIDUNQ = h_seq_item.ARIDUNQ;
	 		h_seq_item.RCHUNKV = h_intf.cb_monitor.RCHUNKV;
	 		h_seq_item.RCHUNKNUM = h_intf.cb_monitor.RCHUNKNUM;
	 		h_seq_item.RCHUNKSTRB = h_intf.cb_monitor.RCHUNKSTRB;

	// -------------------------- calculations ------------------------------------------------ 
 				read_strobe_indicator = h_config.read_valid_strobe_data[i];

				memory_loc_indicator = $floor((h_seq_item.ARADDR/(`MAX_AXI5_DATA_WIDTH/8)));		  // ---- to specify the momory location row pointer ----
				aligned_address = ($floor(h_seq_item.ARADDR/(2**h_seq_item.ARSIZE))) * (2**h_seq_item.ARSIZE); // ---- for calculating the aligned_address to point to next_location 

	// ------------------ storing only the valid byte which is coming on the rdata pin ------------------------//
				for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1)begin//{
		 	 		if(read_strobe_indicator[j]==1) begin
						//store_rdata.push_back(RDATA_i[(j*8)+:8]);
						h_config.store_mem_data_input_monitor.push_back(memory[memory_loc_indicator][j]);
//-----------for exclusive access purpose----- storing data into a queue-----
						if(h_seq_item.ARLOCK)	h_seq_item.exclusive_store_rdata.push_back(memory[memory_loc_indicator][j]);
		  			end
				end//}


//**********************************************************************************************************
// ================================== for exclusive response =====================================//
	exclusive_support = h_config.get_config(AXI5_CONFIG_ENABLE_SLAVE_EXCLUSIVE);

	if((exclusive_support != 0)&&(h_seq_item.ARLOCK == 1)) begin

		if((RRESP_mon!=2) && (RRESP_mon!=3)) begin
			RRESP_mon = 1;

		end
	end


// ============================== decerr condition ==============================
				h_seq_item.ARADDR = aligned_address +(2**h_seq_item.ARSIZE);	//--------updating the addr

				if(h_seq_item.ARBURST == 2) begin		// ---- if wrap pointing address to lower boundary if it reaches upper boundary 
					if((h_seq_item.ARADDR >= Upper_wrap_boundary)) h_seq_item.ARADDR = Lower_wrap_boundary;
				end

				if(h_seq_item.ARADDR >= 4096) RRESP_mon = 3;
// -------------- checking wlast feature condition ---------------------------------
				if(i == h_seq_item.ARLEN) begin

						h_seq_item.RLAST = 1;		
				end
				else begin
						h_seq_item.RLAST = 0;		
					
				end

			end//} h_intf.ARESETn end
			else begin
				foreach(h_config.unique_id_indicator[i]) begin
					h_config.unique_id_indicator.delete(i);
				end

				break;
			end

	 		h_seq_item.RRESP = RRESP_mon;			// ----------- to specify that the transaction is completed with or with out errors 

  		end//} if(!h_intf.ARESETn---else end

  	end//} for i end
// ------------------ deleting the location if that id is exist -------------------
// --------- only scenario that assoc array will not store is outstanding operations 
// --------- with no uniques id feature it will store only one transactin data not all.

	if(h_config.unique_id_indicator.exists(h_seq_item.ARID)) begin
// -------------- deleting the completed id from assoc array -----------
		h_config.unique_id_indicator[h_seq_item.ARID].delete(0);

// -------------- if size of that id based queue is 0 then removing the location from assoc array -------------
		if(h_config.unique_id_indicator[h_seq_item.ARID].size == 0)
			h_config.unique_id_indicator.delete(h_seq_item.ARID);

	end

//*******************************************************************************************
// ----------------------- for exclusive acces  ---------------------------//
	if(h_seq_item.ARLOCK == 1 && RRESP_mon == 1) begin//{
		foreach(seq_item_exclusive_que[i]) begin
			h_trans_seq_item = seq_item_exclusive_que[i];
			if(h_trans_seq_item.ARID == h_seq_item.ARID) begin
				if((h_seq_item.addr_exclusive == h_trans_seq_item.addr_exclusive) && (h_seq_item.ARLEN == h_trans_seq_item.ARLEN) && 
						(h_seq_item.ARBURST == h_trans_seq_item.ARBURST) && (h_seq_item.ARSIZE == h_trans_seq_item.ARSIZE)) begin//{				
					h_seq_item.another_ex_op_invoked=1;

				end
				else begin
					h_trans_seq_item.another_ex_op_invoked = 1;
				end
			end
		end
		seq_item_exclusive_que.push_back(h_seq_item);
	end//}
//********************************************************************************************

			read_data_indicator=0;

//=================================writing to scoreboard for comparision ====================
			h_in_mon_analysis.write(h_seq_item);
			RRESP_mon =0; //BRESP_mon =0;
			h_config.input_monitor_write_indicator = 1;



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


// ****************************************************************************************************************************************
// ================================================== poison feature implementations ======================================================
// ****************************************************************************************************************************************


// ============================================================================
  // ====================== task for write poison ===========================
// ============================================================================
task automatic write_poison_task();
	// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;bit[2:0]col;		// ------------ to specify row and col for poisined memory pointer		
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Lower_wrap_boundary; 			// ----------- The boundaries for wrap based conditions ---------------.
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Upper_wrap_boundary;
  	int wpoison_position;
	shortint Aligned_address;
 begin

	// --------------------------- wrap_calculations ---------------------------------
	Lower_wrap_boundary = ($floor(h_seq_item.AWADDR/((2**h_seq_item.AWSIZE)*(h_seq_item.AWLEN+1))))	* ((2**h_seq_item.AWSIZE)*(h_seq_item.AWLEN+1));
	Upper_wrap_boundary = Lower_wrap_boundary + ((2**h_seq_item.AWSIZE)*(h_seq_item.AWLEN+1));

	//Aligned_address = ($floor(h_seq_item.AWADDR/(2**h_seq_item.AWSIZE)))*(2**h_seq_item.AWSIZE);
	Aligned_address = ($floor(h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))*(`MAX_AXI5_DATA_WIDTH/8);
// ================ to point to 8 byte boundary granule ===========
	row = $floor(h_seq_item.AWADDR/8);
	if(`MAX_AXI5_DATA_WIDTH <= 32)
			col = h_seq_item.AWADDR%8;
	else 
			col = Aligned_address%8;
// ==================================== checking poison bit =====================================

		for(int k=0;k<=h_seq_item.AWLEN;k++) begin : main_for_loop
			wait(h_intf.cb_monitor.WVALID || !h_intf.ARESETn);
			wait(h_intf.AWAKEUP || !h_intf.ARESETn);
			wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
			
			if(h_intf.ARESETn) begin//{
					wpoison_position = 0;
					for(int strb=0;strb<(`MAX_AXI5_DATA_WIDTH/8);strb++) begin:strb_i//{
						if(h_intf.cb_monitor.WSTRB[strb] == 1) begin//{
// if poision is asserted marked as poison else not poisoned
								if(h_intf.cb_monitor.WPOISON[wpoison_position] == 1) begin
									memory_poison[row][col] = 1;
								end
							    else begin
									memory_poison[row][col] = 0; 
								end
	
							h_config.addr_poison++;
							if(col == 7) begin row++;
							end
							if(`MAX_AXI5_DATA_WIDTH <= 32) col ++;
						end//}

	
// ----- incrimenting the col position -----------------
							if(`MAX_AXI5_DATA_WIDTH > 32) col++;
// ---- as col is always 3 bit if it reaches 0 indicates that coressponding all row coloumns are covered so incrimenting row position 						
							if(col == 0) begin//{							
								wpoison_position ++;
							end//}
// ----------------- for wrap condition ------------------------
							if(h_seq_item.AWBURST == 2) begin//{
								if(h_config.addr_poison == Upper_wrap_boundary) begin//{
										h_config.addr_poison = Lower_wrap_boundary;
										row = $floor(h_config.addr_poison/8);
										col = h_config.addr_poison%8;
								end//}
							end	//}

					end:strb_i//}
			end//}
			else break;
		repeat(1) @(h_intf.cb_monitor);
		end : main_for_loop

//  to check wheather the corresponding row is poisoned or not
							foreach(memory_poison[i,j]) begin//{
								if(memory_poison[i][j] == 1) begin//{	// ---- if atleast one among the all coloumns in a row is poisoned
						
									for(int b=0;b<8;b++)begin			// ----- entire row is treated as poisoned
										memory_poison[i][b] = 1;
									end
								end//}
							end//}


 end
endtask


// ===========================================================================
  // ====================== task for read poison ===========================
// ===========================================================================

task automatic read_poison_task();
	// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;bit[2:0]col;		// ------------ to specify row and col for poisined memory pointer		
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Lower_wrap_boundary; 			// ----------- The boundaries for wrap based conditions ---------------.
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Upper_wrap_boundary;	
	bit [((`MAX_AXI5_DATA_WIDTH / 8)-1):0] read_strobe_indicator;	// ------- to get indication for reading and storing only the exact data ----

	bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] poison_indicator;
	int rpoison_position;
	bit [7:0]rpoison_row_check;
	shortint Aligned_address;
 begin

//	Aligned_address = ($floor(h_seq_item.AWADDR/(2**h_seq_item.AWSIZE)))*(2**h_seq_item.AWSIZE);
// ================ to point to 8 byte boundary granule ===========
	Aligned_address = ($floor(h_seq_item.ARADDR/(`MAX_AXI5_DATA_WIDTH/8)))*(`MAX_AXI5_DATA_WIDTH/8);
	row = $floor(h_seq_item.ARADDR/8);
	if(`MAX_AXI5_DATA_WIDTH <= 32)
			col = h_seq_item.ARADDR%8;
	else 
			col = Aligned_address%8;
	// --------------------------- wrap_calculations ---------------------------------
	Lower_wrap_boundary = ($floor(h_seq_item.ARADDR/((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1))))	* ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1));
	Upper_wrap_boundary = Lower_wrap_boundary + ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1));
		
	// ---------------------- calling strobe calculation task ----------------------
		strobe_compute_in_read_data(); 
// ****************************************************************************************************************************************

	for(int k=0;k<=h_seq_item.ARLEN;k++) begin : main_for_loop
			wait(h_intf.cb_monitor.RVALID == 1||!h_intf.ARESETn);
			wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  		wait((h_intf.cb_monitor.RREADY && h_intf.AWAKEUP && h_intf.cb_monitor.RVALID)||!h_intf.ARESETn);
 			read_strobe_indicator = h_config.read_valid_strobe_data[k];
			if(h_intf.ARESETn) begin//{
					rpoison_position = 0;
					h_seq_item.RPOISON = 0;
			
					for(int strb=0;strb<(`MAX_AXI5_DATA_WIDTH/8);strb++) begin:strb_i//{
						if(read_strobe_indicator[strb] == 1) begin
								foreach(rpoison_row_check[i])begin
									rpoison_row_check[i] = memory_poison[row][i];
								end
								if((|rpoison_row_check) == 1) 
									h_seq_item.RPOISON[rpoison_position] = 1;
									
							if(col == 7) begin
								 row++;
							end
							h_config.addr_poison++;
						  if(`MAX_AXI5_DATA_WIDTH <= 32) begin
							col++;
							if(col == 0) begin	
								rpoison_position++;
							end
						  end
						end

						  if(`MAX_AXI5_DATA_WIDTH > 32) begin
							col++;
							if(col == 0) begin
								
								rpoison_position++;
							end
						  end
							if(h_seq_item.ARBURST == 2) begin
								if(h_config.addr_poison == Upper_wrap_boundary) begin
									h_config.addr_poison = Lower_wrap_boundary;
									row = $floor(h_config.addr_poison/8);
									col = h_config.addr_poison%8;
								end
							end
					end:strb_i//}	

			end//}
			else break;
		repeat(1) @(h_intf.cb_monitor);

//--------------------------------poision storing for comparing purpose ---- in read operation
		h_config.poison_in_monitor_que.push_back(h_seq_item.RPOISON);

	end : main_for_loop
end
endtask

// ============================================================================================================================================== //
// ========================================================= Atomic Implementations ============================================================= //
// ============================================================================================================================================== //



// *************************************************************************************************************************************
						// *********************************** atomic compare **********************
// *************************************************************************************************************************************
task automatic atomic_compare_read_data_phase();
	bit[2:0]temp_size;
	bit[7:0]temp_bst_len;
	bit[1:0]temp_resp;

$display($time," FROM MONITOR================= IN READ ATOMIC COMPARE PHASE ========================================\n\n");
// ------------- in compare operation we need to send only half of specified bytes --------------------------
  if(h_seq_item.ARLEN == 0) begin
	temp_size = h_seq_item.ARSIZE;
  	h_seq_item.ARSIZE = h_seq_item.ARSIZE - 1;
  end
  else begin
	temp_bst_len = h_seq_item.ARLEN;
	h_seq_item.ARLEN = $floor(h_seq_item.ARLEN/2);
  end
	temp_resp = RRESP_mon;
// ---------------- invoking read_data channel ----------------
  fork
	get_read_data_phase();
	read_poison_task();
  join
//----------------------re assign the original size,len,resp after the read data phase completion---for proper writing------
	h_seq_item.ARSIZE = temp_size;
	h_seq_item.ARLEN = temp_bst_len;
	RRESP_mon = temp_resp;
endtask


task automatic atomic_compare_write_data_phase();

	if(h_seq_item.AWBURST == 1)
		atomic_compare_INCR();
	else if(h_seq_item.AWBURST == 2)
		atomic_compare_WRAP();
	else $display($time," FROM MONITOR====== Fixed type is not supported or else reserved burst type is invoked =======\n\n");

endtask

//******************************************************************************
// ================== for atomic compare incriment ===================		   *
//******************************************************************************

task automatic atomic_compare_INCR();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;
	bit[15:0] row_p;bit[2:0]col_p;		// ------------ to specify row and col for poisined memory pointer		
// ---------- to differentiate between the swap and compare values coming grom wdata pin ------------
	shortint number_bytes = 2 ** h_seq_item.AWSIZE;
	bit[((`MAX_AXI5_DATA_WIDTH / 8)-1):0]compare_status[];		//------------for comparision purpose (compare data with memory data)
	bit [5:0] max_bytes = 32; 
	shortint strobe_count;	//----------for seperation of swap and compare data 
  	int wpoison_position;
	shortint Aligned_address;
 begin
	$display("FROM MONITOR============ ATOMIC COMPARE INCR PHASE==========\n\n");

// --------------------- memory creation for dynamic array -------------------	
	if(h_seq_item.AWLEN > 1) compare_status = new[(h_seq_item.AWLEN+1)/2];
	else compare_status = new[1];

// ======================================== IMPLEMENTATION ================================================ //

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 
// ================ to point to 8 byte boundary granule ===========
	Aligned_address= ($floor(h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8))) * (`MAX_AXI5_DATA_WIDTH/8);
	row_p = $floor(h_seq_item.AWADDR/8);
	col_p = h_seq_item.AWADDR%8;

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin // --{

	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  		// ----- time out factor running parllely with ready -----------
  		fork
  				wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
			  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  		join_any;
  		disable fork;
//-------------------------------burst_length ==0------------------
	  	if(h_intf.ARESETn && (h_seq_item.AWLEN==0)) begin // --- {

			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;


	// ------------------------ loop which ckecks all possiblities(2,4,8,16,32) ------------
			for(int k=0;k<5;k++) begin	
		  		if(max_bytes == number_bytes) begin		//-------to find out total no.of bytes from transaction----
					for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin		
						if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin
              				if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              				else begin
					  		  if(strobe_count <= ((number_bytes/2)-1)) begin			//---------------for compare value
								if(memory[row][col] == h_seq_item.WDATA[(j*8)+:8]) begin
								
									compare_status[i][j] = 1;
									col = col+1;
									strobe_count++;
								end else begin
									compare_status[i][j] = 0;
									col = col+1;
									strobe_count++;
								end
					  		  end else begin
//---------------------------swap value storing to memory if compare value and memory value is matched-----------
								if(compare_status[i][j-col]==1) begin			//---- to point out to col 0 == j-col
                					memory[row][j-col] = h_seq_item.WDATA[(j*8)+:8];	
									memory_poison[row_p][col_p] = h_seq_item.WPOISON[wpoison_position];
									if(col_p == 7) begin row_p++;wpoison_position++; end
									col_p++;
								end
								else continue;
				  	  		  end
              				end
						end
					end	
					break;	
		  		end
		  		else begin
					max_bytes = max_bytes/2;
					continue;
		  		end
			end
	  	end // ---}


//--------------------------------burst length >0------------
	  	else if(h_intf.ARESETn && h_seq_item.AWLEN>0) begin//{

// **********************************************************************************************
//------ AWLEN = 1-- 2 transfers--																*
//-------1 beat for compare value and 2nd beat for swap value									*
//------ AWLEN = 3-- 4 transfers--																*
//------- first 2 beats for compare value and last 2 beats for swap value						*
// **********************************************************************************************

	$display($time," FROM MONITOR================== in burst_length > 0 condition==================== \n\n");


			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;


//--------------------------------for compare value comparision with wdata---- 
			if(i <(h_seq_item.AWLEN+1)/2) begin//{
			  for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin//{		//------differentiates the beats	
				if(h_seq_item.WSTRB[j] == 1 && (BRESP_mon != 2 || BRESP_mon != 3)) begin//{
              		if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              		else begin//{
						if(memory[row][col] == h_seq_item.WDATA[(j*8)+:8]) begin		//------------------wdata and memory data comparision
							compare_status[i][j] = 1;		//-------------if match compare status = 1
							col = col+1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end

						end
						else begin
							compare_status[i][j] = 0;		//---------------if doesn't match compare status = 0
							col = col+1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
							
						end
				    end//}
				end//}
			  end//}
			$display($time," FROM MONITOR-------------------- compare_status = %p ---------------\n\n",compare_status);
			end//}
//---------------------------- swap value storing into memory 
			else if(i >= (h_seq_item.AWLEN+1)/2) begin//{
	$display($time," FROM MONITOR--------------- storing swap value -------------------\n\n");
				row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8))) + (i-(h_seq_item.AWLEN+1)/2);
				col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8))));
			  for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin 		//----------differentiates the beats
				if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin
              		if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end		//----error condition
              		else begin
						if(compare_status[(i-(h_seq_item.AWLEN+1)/2)][j]==1) begin		//---------if compare value and memory value match
            			 	memory[row][col] = h_seq_item.WDATA[(j*8)+:8];
							memory_poison[row_p][col_p] = h_seq_item.WPOISON[wpoison_position];
							col = col+1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
							
						end
						else begin
							col = col+1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
						end
						if(col_p == 7) begin row_p++;wpoison_position++; end
						col_p++;
					end
			  	end	
			  end	
			end//}		
	  end//}
	  else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	  end
	 end  // ----}
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end
		repeat(1) @(h_intf.cb_monitor);
	end  // --- }
	foreach(memory_poison[i,j]) begin//{
								if(memory_poison[i][j] == 1) begin//{				// ---- if atleast one among the all coloumns in a row is poisoned
									for(int b=0;b<8;b++)							// ----- entire row is treated as poisoned
										memory_poison[i][b] = 1;
								end//}
							end//}

//	$display($time," ==================== contents of memory from atomic compare incriment operation = %p\n\n",memory);
	data_indicator = 0;
 end
endtask

//******************************************************************************
// ================== for atomic compare wrap ===================			   *
//******************************************************************************

task automatic atomic_compare_WRAP();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;
	bit[15:0] row_p;bit[2:0]col_p;		// ------------ to specify row and col for poisined memory pointer		
// ---------- to differentiate between the swap and compare values coming grom wdata pin ------------
	shortint number_bytes = 2 ** h_seq_item.AWSIZE;
	bit [7:0] store_swap_data[$];
	bit  swap_poison_data[$];
	bit [5:0] max_bytes = 32;
	shortint strobe_count;  //------------to differentiate between swap and compare values
  	int wpoison_position;
	shortint Aligned_address;
 begin
	$display("FROM MONITOR============ ATOMIC COMPARE WRAP PHASE==========\n\n");
// ======================================== IMPLEMENTATION ================================================ //

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 
// ================ to point to 8 byte boundary granule ===========
	Aligned_address= ($floor(h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8))) * (`MAX_AXI5_DATA_WIDTH/8);
	row_p = $floor(h_seq_item.AWADDR/8);
	col_p = h_seq_item.AWADDR%8;

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin // --{
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  		fork
  				wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
			  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  		join_any;
  		disable fork;

//-------------------------------burst_length ==0------------------
	  if(h_intf.ARESETn && (h_seq_item.AWLEN==0)) begin // --- {

			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;


	// ------------------------ loop which ckecks all possiblities ------------
		for(int k=0;k<5;k++) begin

		  if(max_bytes == number_bytes) begin
			for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin	
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin
              		if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              		else begin		// ----------------- pushing swap value into array --------------- //

					  if(strobe_count <= ((number_bytes/2)-1)) begin
						store_swap_data.push_back(h_seq_item.WDATA[(j*8)+:8]);
						swap_poison_data.push_back(h_seq_item.WPOISON[wpoison_position]);
						strobe_count++;

					  end else begin	// ------------ comparing copmare value with memory if mapped storing swap value into memory --------- //
						if(memory[row][col] == h_seq_item.WDATA[(j*8)+:8]) begin
                			memory[row][col] = store_swap_data.pop_front();
							memory_poison[row_p][col_p] = swap_poison_data.pop_front();
							col++;							
						end
						else begin
							store_swap_data.delete(0);
							swap_poison_data.delete(0);
							col++;
							continue;
						end
						if(col_p == 7) begin row_p++; wpoison_position++; end
						col_p++;
				  	  end
              		end
				end
			end
			break;		
		  end
		  else begin
			max_bytes = max_bytes/2;
			continue;
		  end
		end
	  end // ---}
//--------------------------------burst length >0------------
	  else if(h_intf.ARESETn && h_seq_item.AWLEN>0) begin//{

		$display($time," FROM MONITOR========================= burst length >0 condition===============\n\n");
// **********************************************************************************************
//------ AWLEN = 1-- 2 transfers--																*
//-------1 beat for swap value and 2nd beat for compare value									*
//------ AWLEN = 3-- 4 transfers--																*
//------- first 2 beats for swap value and last 2 beats for compare value						*
// **********************************************************************************************
			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;


//--------------------------------for swap value storing---- 
			if(i < (h_seq_item.AWLEN+1)/2) begin//{
			  for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin//{		//------differentiates the beats	
				if(h_seq_item.WSTRB[j] == 1 && (BRESP_mon != 2 || BRESP_mon != 3)) begin//{
              		if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              		else begin//{
						store_swap_data.push_back(h_seq_item.WDATA[(j*8)+:8]);
						swap_poison_data.push_back(h_seq_item.WPOISON[wpoison_position]);
				    end//}
				end//}
			  end//}
			end//}

//---------------------------- swap value storing into memory if compaison is true
			else if(i >= (h_seq_item.AWLEN+1)/2) begin//{
			  for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin 		//----------differentiates the beats
				if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              		if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end		//----error condition
              		else begin
						//	$display($time," FROM MONITOR----------from swap--------wdata =  %0d   memory_content=%0d row=%0d   %0d\n\n",h_seq_item.WDATA[(j*8)+:8],	memory[row][col],row,col);
						if(memory[row][col] == h_seq_item.WDATA[(j*8)+:8]) begin
                			memory[row][col] = store_swap_data.pop_front();	
							memory_poison[row_p][col_p] = swap_poison_data.pop_front();
							col++;
 							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
						
						end
						else begin
							store_swap_data.delete(0);
							swap_poison_data.delete(0);
							col++;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end	
							continue;
						end
						if(col_p == 7) begin row_p++; wpoison_position++; end
						col_p++;
					end
			  	end	
			  end	
			end//}		
	  end//}
	  else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	  end
	end  // ----}
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(2) begin @(h_intf.cb_monitor); end
//	repeat(1) @(h_intf.cb_monitor);
	end  // --- }
//  to check wheather the corresponding row is poisoned or not
							foreach(memory_poison[i,j]) begin//{
								if(memory_poison[i][j] == 1) begin//{	// ---- if atleast one among the all coloumns in a row is poisoned
						
									for(int b=0;b<8;b++)begin			// ----- entire row is treated as poisoned
										memory_poison[i][b] = 1;
									end
								end//}
							end//}

//	$display($time," FROM MONITOR==================== contents of memory from Atomic comapre wrap = %p\n\n",memory);
	data_indicator = 0;
 end
endtask




// *************************************************************************************************************************************
						// *********************************** atomic store and load **********************
// *************************************************************************************************************************************

task automatic atomic_store_load_data_phase();
	case(h_seq_item.AWATOP[2:0])
		0 : atomic_add_operation();
		1 : atomic_clear_operation();
		2 : atomic_xor_operation();
		3 : atomic_set_operation();
		4 : atomic_smax_operation();
		5 : atomic_smin_operation();
		6 : atomic_umax_operation();
		7 : atomic_umin_operation();
	default : $display($time," FROM MONITOR------------ no atomic operation to perform ------------------\n\n");
	endcase
endtask

//******************************************************************************
// ================== for atomic addition ===================				   *
//******************************************************************************

task automatic atomic_add_operation();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;
	bit[7:0]add_store_q[$];
 begin

	$display($time," FROM MONITOR======================== in atomic add operation ================ \n\n");

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
  		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  		fork
  				wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
			  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  		join_any;
  		disable fork;


		if(h_intf.ARESETn) begin


			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;



	  		if(h_seq_item.AWATOP[3] == 0) begin
	$display($time," FROM MONITOR======================== in atomic little endian add operation ================  bresp  %d\n\n",BRESP_mon);
						
				for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
					if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              			if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              			else begin
							$display($time," FROM MONITOR======== wdata from atomic add operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
							memory[row][col] = memory[row][col] + h_seq_item.WDATA[(j*8)+:8];
							col = col + 1;
							if(`MAX_AXI5_DATA_WIDTH==8) begin
								if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
							end
							else begin
								if(col==0) row++;
							end
              			end
					end
		  		end
			end	
		
	  		else begin
	$display($time," FROM MONITOR======================== in atomic big endian add operation ================\n\n");
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				//	$display($time," FROM MONITOR======== wdata from atomic add operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
					add_store_q.push_back(memory[row][col] + h_seq_item.WDATA[(j*8)+:8]);
					col = col + 1;
					if(`MAX_AXI5_DATA_WIDTH==8) begin
						if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
					end
					else begin
						if(col==0) row++;
					end
              end
			end
		  end
	  end

 // -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end	

	  $display($time," FROM MONITOR----contents in queue from atomic big endian addition is = %p\n\n",add_store_q);
		  for (int j=0;j<add_store_q.size;j++)begin
				col--;
				if(&col == 1) begin row = row - 1; if(`MAX_AXI5_DATA_WIDTH == 8) col = 0; end
				memory[row][col] = add_store_q[j];
		  end
	//$display($time," FROM MONITOR==================== contents of memory from add operation of atomic = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic xor ===================					   *
//******************************************************************************

task automatic atomic_xor_operation();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;


 begin

	$display($time," FROM MONITOR=============== in atomic exor operation ==================\n\n");
	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin	


			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

					
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic xor operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = memory[row][col]  ^ h_seq_item.WDATA[(j*8)+:8];
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end

              end
			end
		end	
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
//	$display($time," FROM MONITOR==================== contents of memory in atomic xor operation = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic set ===================					   *
//******************************************************************************

task automatic atomic_set_operation( );
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;


 begin

	$display($time," FROM MONITOR========================== from atomic set operation ===================\n\n");

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin



			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

						
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic set operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = memory[row][col]  | (h_seq_item.WDATA[(j*8)+:8]);
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end
              end
			end
		end	
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
//	$display($time," FROM MONITOR==================== contents of memory from atomic set operation = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic clear ===================					   *
//******************************************************************************

task automatic atomic_clear_operation(  );
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;


 begin
	$display($time," FROM MONITOR========================== from atomic clear operation ===================\n\n");
	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin



			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

						
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic clear operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = memory[row][col]  & (~(h_seq_item.WDATA[(j*8)+:8]));
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end

              end
			end
		end	
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
//	$display($time," FROM MONITOR==================== contents of memory from atomic clear operation is = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic umax ===================					   *
//******************************************************************************

task automatic atomic_umax_operation();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;

 begin

	$display($time," FROM MONITOR ======================== in atomic umax operation =======================\n\n");	

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin


			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

						
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic umax operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = (memory[row][col] > (h_seq_item.WDATA[(j*8)+:8])) ? memory[row][col] : (h_seq_item.WDATA[(j*8)+:8]);
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end
              end
			end
		end	
 // -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
//	$display($time," FROM MONITOR==================== contents of memory from atomic umax operation = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic umin ===================					   *
//******************************************************************************


task automatic atomic_umin_operation();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;

 begin

	$display($time," FROM MONITOR ============== from atomic umin operation ===================\n\n");

	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin


			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

						
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic umin operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = (memory[row][col] < (h_seq_item.WDATA[(j*8)+:8])) ? memory[row][col] : (h_seq_item.WDATA[(j*8)+:8]);
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end
              end
			end
		end	
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
	//$display($time," FROM MONITOR==================== contents of memory from atomic umin operation = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic smax ===================					   *
//******************************************************************************


task automatic atomic_smax_operation();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;

 begin
	$display($time," FROM MONITOR ============== from atomic smax operation ===================\n\n");
	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin


			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

						
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic smax operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = ($signed(memory[row][col]) > $signed((h_seq_item.WDATA[(j*8)+:8]))) ? memory[row][col] : (h_seq_item.WDATA[(j*8)+:8]);
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end

              end
			end
		end	
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
//	$display($time," FROM MONITOR==================== contents of memory from atomic smax operation = %p\n\n",memory);
	data_indicator = 0;
 end

endtask

//******************************************************************************
// ================== for atomic smin ===================				   		*
//******************************************************************************


task automatic atomic_smin_operation();
// ----------- to specify memory row and coloum nothing but pointing to exact memory location-----------------
	bit[15:0] row;
	bit[($clog2(`MAX_AXI5_DATA_WIDTH/8)-1):0]col;


 begin
	$display($time," FROM MONITOR ============== from atomic smin operation ===================\n\n");
	data_indicator=1;
	// ---------- ex if addr = 20 and datawidth = 64 then row = 20/(64/8) which results 2.5 floor becomes location 2 -----------
	row = $floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)));

	// ------ considering above ex col = 20 - (64/8)*(20/(64/8)) results 4 which points to location memory[2][4] ---------------- 
	col = h_seq_item.AWADDR - (`MAX_AXI5_DATA_WIDTH/8)*($floor((h_seq_item.AWADDR/(`MAX_AXI5_DATA_WIDTH/8)))); 

	// ---------------------- decode error condition if address exceeds 4096 ---------------
   if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 )begin BRESP_mon = 3;  end
	// --------------------- transfer size greater than bus width so slave error condition ---------------
   else if ( ((2 ** h_seq_item.AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8))&& h_intf.ARESETn) begin BRESP_mon = 2; end

   
	for(int i=0;i<=h_seq_item.AWLEN;i++)begin
	  if(!h_intf.ARESETn) begin
		h_config.terminate_transaction=1;
		break;
	  end
	  else begin//{
	
//----iteration to collect the samples from the array
	 	wait(h_intf.cb_monitor.WVALID	==1||!h_intf.ARESETn);
		wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);
  // ----- time out factor running parllely with ready -----------
  fork
  		wait((h_intf.cb_monitor.WVALID && h_intf.AWAKEUP && h_intf.cb_monitor.WREADY) || !h_intf.ARESETn);
	  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_WVALID_ASSERTION_TO_WREADY);
  join_any;
  disable fork;


	if(h_intf.ARESETn) begin	



			//-----------------------W channel signals--------------------------------------------------

	  		h_seq_item.WVALID = h_intf.cb_monitor.WVALID;		
	  		h_seq_item.WREADY = h_intf.cb_monitor.WREADY;				
	  		h_seq_item.WLAST = h_intf.cb_monitor.WLAST;			
	  		h_seq_item.WDATA = h_intf.cb_monitor.WDATA;		
	  		h_seq_item.WSTRB = h_intf.cb_monitor.WSTRB;	
			h_seq_item.WPOISON = h_intf.cb_monitor.WPOISON;

					
		for(int j= 0;j<(`MAX_AXI5_DATA_WIDTH/8);j=j+1) begin			
			if((h_seq_item.WSTRB[j] == 1) && (BRESP_mon != 2) && (BRESP_mon != 3)) begin

              if((row*(`MAX_AXI5_DATA_WIDTH/8))+col >= 4096 && BRESP_mon != 2)begin BRESP_mon = 3;  end
              else begin
				$display($time," FROM MONITOR======== wdata from atomic smin operation is wdata = %0d memory_content=%0d\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				$display($time," FROM MONITOR======== wdata from atomic smin operation is wdata = %b memory_content=%b\n\n",h_seq_item.WDATA[(j*8)+:8],memory[row][col]);
				memory[row][col] = ($signed(memory[row][col]) < $signed((h_seq_item.WDATA[(j*8)+:8]))) ? memory[row][col] : (h_seq_item.WDATA[(j*8)+:8]);
				col = col + 1;
				if(`MAX_AXI5_DATA_WIDTH==8) begin
					if(col ==`MAX_AXI5_DATA_WIDTH/8) begin row = row + 1; col=0; end
				end
				else begin
					if(col==0) row++;
				end

              end
			end
		end	
// -------------- checking wlast feature condition ---------------------------------
		if(i == h_seq_item.AWLEN) begin
			h_config.wlast_indicator_mon = 1;
			if(h_seq_item.WLAST != 1)
				$error($time," FROM MONITOR========================= not geeting wlast in last beat ======================\n\n");
		end
		else begin
			h_config.wlast_indicator_mon = 0;
			if(h_seq_item.WLAST == 1)
				$error($time," FROM MONITOR========================= geeting wlast middle of transaction beat ======================\n\n");
		end

	repeat(1) @(h_intf.cb_monitor);
	end
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
	 end
	end
//	$display($time," FROM MONITOR==================== contents of memory from atomic smin operation = %p\n\n",memory);

	data_indicator = 0;
 end

endtask



// *********************************************************************************************************************** //
			// =========================== READ DATA CHUNKING IMPLEMENTATIONS ==============================//
// *********************************************************************************************************************** //

task automatic execute_read_data_chunking();
  begin:task_begin

// *******************************************************************************

	if(h_seq_item.ARADDR%16 != 0) RRESP_mon=2;

	if((h_seq_item.ARLEN > 0) && ((2**h_seq_item.ARSIZE) != (`MAX_AXI5_DATA_WIDTH/8))) begin
		RRESP_mon = 2;			// --- len >0 and ARsize is != total bus width ---- checsk only when len > 0
	end

	if(((2**h_seq_item.ARSIZE) > (`MAX_AXI5_DATA_WIDTH/8)) && (h_intf.ARESETn)) begin
		RRESP_mon = 2;			// ----- arsize greater than data bus width --------- checks for every condition
	end

// ------------ for wrap we have to send only 2 or 4 or 8 or 16 beats -------------
	if(h_seq_item.ARBURST == 2) begin
		case(h_seq_item.ARLEN)
			1,3,7,15 : RRESP_mon = RRESP_mon;
			default  : RRESP_mon = 2;
		endcase
	end


	if((2**h_seq_item.ARSIZE < 16) || (RRESP_mon ==2)) begin
		RRESP_mon = 0;
		fork
			get_read_data_phase();
			read_poison_task();
		join
	end
	else begin
	//	fork
			invoke_read_data_chunking();
	//		read_poison_task(trans);
	//	join
	end

  end:task_begin
endtask

// ************************************************************************************
	// =================== invoking read data chinking phase ====================//
// ************************************************************************************

task automatic invoke_read_data_chunking();
	// ------------------ task internal variables -------------------
	bit[8:0]total_chunk_no;	// --------- specify no of maximum possible chunks will come in trasaction ----- -----
	bit[(`MAX_AXI5_DATA_WIDTH-1):0]monitor_memory_chunknum[];	// ------- creates ARLEN no:of locations ---------
	bit[((`MAX_AXI5_DATA_WIDTH/128)-1):0]strobe_check[];	// ----------to check incoming chunck strobe creates ARLEN no:of locations------------
	bit[8:0]chunk_count;		// ------- to count no:of chunks received ------------------
	shortint Aligned_address;	// ------ to find aligned address --------------
	bit[15:0]memory_loc_indicator;  // ------------ to find exact memory location -----------------//
// ----------------- wrap boundary calculations ----------------------
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Lower_wrap_boundary; 			// ----------- The boundaries for wrap based conditions ---------------.
	bit[(`MAX_AXI5_ADDRESS_WIDTH -1):0] Upper_wrap_boundary; 
	int row;bit[2:0]col;int pos;
  begin : task_be
// =================== calculations =================================== //
	Aligned_address = $floor(h_seq_item.ARADDR/(2**h_seq_item.ARSIZE)) * (2**h_seq_item.ARSIZE);
	total_chunk_no = ((((2**h_seq_item.ARSIZE) * (h_seq_item.ARLEN+1)))/16) - ((h_seq_item.ARADDR-Aligned_address)/16);


	monitor_memory_chunknum = new[h_seq_item.ARLEN+1];
	h_config.monitor_poison_chunknum = new[h_seq_item.ARLEN+1];
	h_config.monitor_memory_chunknum = new[h_seq_item.ARLEN+1];
	strobe_check = new[h_seq_item.ARLEN+1];
// --------------------------- wrap_calculations ---------------------------------
	Lower_wrap_boundary = ($floor(h_seq_item.ARADDR/((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1))))	* ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1));
	Upper_wrap_boundary = Lower_wrap_boundary + ((2**h_seq_item.ARSIZE)*(h_seq_item.ARLEN+1));

// ------------- row and col calculation for poison purpose ----------------------
	row = $floor(h_config.addr_poison/8);
	col = h_config.addr_poison%8;

// ==================== getting data from internal memory to memory_chunknum for comparison purpose =================//

	if(h_seq_item.ARBURST == 2) begin		// ----- wrap condition -----
		memory_loc_indicator = $floor((Lower_wrap_boundary/(`MAX_AXI5_DATA_WIDTH/8)));
		row = Lower_wrap_boundary;
	end
	else begin						// ---- incr condition ------
		memory_loc_indicator = $floor((h_seq_item.ARADDR/(`MAX_AXI5_DATA_WIDTH/8)));
		row = row;
	end
	
	strobe_compute_in_read_data();	

	for(int i = 0; i<=h_seq_item.ARLEN;i++)begin
		for(int j=0; j<`MAX_AXI5_DATA_WIDTH/8; j++) begin
			if (h_config.read_valid_strobe_data[i][j] == 1)begin 
				if(((memory_loc_indicator * (`MAX_AXI5_DATA_WIDTH/8))+j) < 4096) begin
					h_config.monitor_memory_chunknum[i][(j*8)+:8] = memory[memory_loc_indicator][j];
						
		// --------------- posion purpose ---------------------
					if(j%8 == 0) begin
						if($countones(memory_poison[row]) != 0 ) begin
							h_config.monitor_poison_chunknum[i][j/8] = 1;
						end 
							row++;
					end
				end
  		// ---------------------------------------------------------

				else continue;
			end
			else continue;
		end
		memory_loc_indicator++;
	end

// ========================= implementations =============================//
	for(int i=0;i<256;i++)begin : i_loop
		if(!h_intf.ARESETn) begin
			break;
  	  	end
  	  	else begin :main_else
			wait(h_intf.cb_monitor.RVALID == 1||!h_intf.ARESETn);
			wait(h_intf.AWAKEUP	== 1||!h_intf.ARESETn);

// -------- time out factor running parllely with ready -----------
  			fork
  			  wait((h_intf.cb_monitor.RREADY && h_intf.AWAKEUP && h_intf.cb_monitor.RVALID)||!h_intf.ARESETn);
			  h_config.max_time_to_wait_for_ready(AXI5_CONFIG_MAX_LATENCY_RVALID_ASSERTION_TO_RREADY);
  			join_any;
  			disable fork;
// ----------------- doing operation if h_intf.ARESETn is not applied if applied breaking the loop -------------------
	 		if(h_intf.ARESETn) begin : rst_condition

//-----------------------R channel signals--------------------------------------------------
	 		h_seq_item.RVALID = h_intf.cb_monitor.RVALID;				// ----------- specifies the coming data is valid 
	 		h_seq_item.RREADY = h_intf.cb_monitor.RREADY;			// ----------- data ack signal
	 		h_seq_item.RLAST = h_intf.cb_monitor.RLAST;				// ----------- to specify the indication that sending last byte in transfer
	 		h_seq_item.RDATA = h_intf.cb_monitor.RDATA;			// ----------- data that had to be wriiten to the slave
	 		h_seq_item.RRESP = RRESP_mon;			// ----------- to specify that the transaction is completed with or with out errors 
	 		h_seq_item.RID = h_seq_item.ARID;			// ----------- for address identification purpose
	 		h_seq_item.RIDUNQ = h_seq_item.ARIDUNQ;
	 		h_seq_item.RCHUNKV = h_intf.cb_monitor.RCHUNKV;
	 		h_seq_item.RCHUNKNUM = h_intf.cb_monitor.RCHUNKNUM;
	 		h_seq_item.RCHUNKSTRB = h_intf.cb_monitor.RCHUNKSTRB;
	  	//	h_seq_item.RPOISON = h_intf.cb_monitor.RPOISON;


//**************************************************************************************************************
// ----------------- chuck valid strobe checkings -----------------------
				if((h_seq_item.RCHUNKV ==1) && (|h_seq_item.RCHUNKSTRB != 0)) begin
					$display($time,"FROM MONITOR ----- chunk valid and strobe genration is pass -----------------\n\n");
				end
				else begin
					$error($time,"FROM MONITOR ----- chunk valid and strobe genration is failed -----------------\n\n");
				end



//*************************************************************************************************************
// ------------------ based on strobe and num value the given RDATA is stored in the external slave memory ----------

				foreach(h_seq_item.RCHUNKSTRB[i]) begin

					if(h_seq_item.RCHUNKSTRB[i]== 1'b1)begin

						// ------ dec_error condition ------
						if(h_seq_item.ARADDR >= 4096) begin
								 RRESP_mon = 3;
								$error($time,"FROM MONITOR ------ raising strobe for dec error condition -------");
						end
						else begin
							chunk_count++;
				// -------------------  strobe checking wheather it is genrated only once or not --------------------- //
							if(strobe_check[h_seq_item.RCHUNKNUM][i] == 0)
								strobe_check[h_seq_item.RCHUNKNUM][i] = 1;
							else 
								$error($time,"FROM MONITOR   strobe value from chunknum  %0d is getting twice",h_seq_item.RCHUNKNUM);
						// ------------- updating addr value for decc error condition checking -------------
							h_seq_item.ARADDR = h_seq_item.ARADDR + 16;
						end
					end
				end 



//**********************************************************************************************************************
//----------------------  rlast checking and loop breaking ----------------

			// ----- total chuks needed is 8 already received 7 chunks in last chunk received 2 chunks then it is error 
			// --- at that time it enters into this if condition --------------
				if(chunk_count > total_chunk_no) begin
					$error($time,"FROM MONITOR ------------ getting more chunks ------------------");
					if(h_seq_item.RLAST == 1) begin
						$display($time,"FROM MONITOR ------------ rlast generated coreectly --------------- and chunks not sent correctly---\n\n");
						break;
					end
					else begin
						$error($time,"FROM MONITOR ------------ rlast generation failed --------------- and chunks not sent correctly---\n\n");
						break;
					end
				end

			// -------------------- if all chuncks are received then enters into this if condition -------------
				else if(chunk_count == total_chunk_no) begin
					if(h_seq_item.RLAST == 1) begin
						$display($time,"FROM MONITOR ------------ rlast generated coreectly --------------- and chunks sent correctly---\n\n");
						break;
					end
					else begin
						$error($time,"FROM MONITOR ------------ rlast generation failed --------------- and chunks sent correctly---\n\n");
						break;
					end
				end
			// ------------------ rlast checking -----------------------
				else begin
					if(h_seq_item.RLAST == 1) begin
						$error($time,"FROM MONITOR ------------ getting rlast at middle of beats --------\n\n");
					//	break;
					end
				end
			end : rst_condition
// ------------ reset condition break -------------
	else begin
		foreach(h_config.unique_id_indicator[i]) begin
			h_config.unique_id_indicator.delete(i);
		end
		break;
	end
		end:main_else
		repeat(1) @(h_intf.cb_monitor);	
	end : i_loop

	
// ------------------ deleting the location if that id is exist -------------------
// --------- only scenario that assoc array will not store is outstanding operations 
// --------- with no uniques id feature it will store only one transactin data not all.

	if(h_config.unique_id_indicator.exists(h_seq_item.ARID)) begin
// -------------- deleting the completed id from assoc array -----------
		h_config.unique_id_indicator[h_seq_item.ARID].delete(0);

// -------------- if size of that id based queue is 0 then removing the location from assoc array -------------
		if(h_config.unique_id_indicator[h_seq_item.ARID].size == 0)
			  h_config.unique_id_indicator.delete(h_seq_item.ARID);

	end


			h_in_mon_analysis.write(h_seq_item);
			RRESP_mon =0; //BRESP_mon =0;
			h_config.input_monitor_write_indicator = 1;



  end : task_be
endtask







endclass
