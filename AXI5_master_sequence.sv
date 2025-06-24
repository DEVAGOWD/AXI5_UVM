class AXI5_sequence extends uvm_sequence #(AXI5_sequence_item);

//=======================factory registeration====================

	`uvm_object_utils(AXI5_sequence)


//==================instance===============
	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction


//==========================task body===============//
task body();

//================================config class getting=========================

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
//===============basic write
	aw_channel_signals_atomic(8,1,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

	w_channel_signals;

	b_channel_signals;



//=====================atomic write and read
	aw_channel_signals_atomic(8,1,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_ADD,1);//--addr,len,size,burst,awatop,awidunq

	if(h_config.AWATOP[5:4]!=2'b01)
	r_channel_signals;
	
	w_channel_signals;

	b_channel_signals;

//===================basic read

	ar_channel_signals_atomic(8,1,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

	r_channel_signals;

endtask

//=============================task for aw channel signals =============================

task aw_channel_signals(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst , bit unique_id);

		h_config.write_or_read = h_config.write_or_read.last();

//================================driving write address channel signals
		start_item(req);
		assert(req.randomize() with {(AWVALID==1);(AWID==req.AWID);(AWADDR==addr);(AWATOP=='b000000);(AWBURST==burst);(AWLEN==len);(AWSIZE==size);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);(AWIDUNQ==unique_id);
										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==0);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);(ARLOCK==0);
										(RREADY==0);

										});
		finish_item(req);
	//	wait(h_config.wr_addr_ev);
		h_config.WSTRB_config=new[h_config.AWLEN+1];//---memory creation for dynamic array
		write_strobe_update;

endtask

//--------------------------------atomic transaction purpose --------------aw channel signals--------------
task aw_channel_signals_atomic(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,axi5_size_e size,bit[1:0]burst,axi5_awatop_e atomic_op,bit awidunq);
		h_config.write_or_read = h_config.write_or_read.last();

//================================driving write address channel signals
		start_item(req);

		assert(req.randomize() with {(AWVALID==1);(AWID==req.AWID);(AWADDR==`ADDRESS);(AWATOP==atomic_op);(AWBURST==`BURST);(AWLEN==`LEN);(AWSIZE==`SIZE);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);(AWIDUNQ==awidunq);
										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==0);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
										(RREADY==0);

										});
		finish_item(req);
	//	wait(h_config.wr_addr_ev);
	 	h_config.WSTRB_config=new[h_config.AWLEN+1];//---memory creation for dynamic array
		write_strobe_update;

endtask


//======================================task for w channel signals driving =========================

task w_channel_signals;

//=================================driving write data channel signals
		for(int i=0;i<=h_config.AWLEN;i++)begin
			start_item(req);
			h_config.total_beats=i;
			h_config.write_data_config();

			assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
											(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==1);(WSTRB==h_config.WSTRB_config[i]);(WLAST==h_config.WLAST);(WDATA==req.WDATA);
											(BREADY==0);
											(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);(ARLOCK==0);

											(RREADY==0);

										});

			finish_item(req);
		//	wait(h_config.wr_data_ev);
		//	$display($time,"data phase handshake completed from master",);
		end



endtask


//==============================task for b channel signals driving =========================

task b_channel_signals;

//=======================drivng response phase signals
		
		start_item(req);
		assert(req.randomize() with {
										(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==1);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
(ARLOCK==0);

										(RREADY==0);
									});
		finish_item(req);

	//	wait(h_config.wr_resp_ev);
		//$display($time,"response phase handshake completed from master");


endtask


//==============================task for ar channel signals driving=========================

task ar_channel_signals(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst,bit unique_id , bit archunken);

 		 h_config.write_or_read = h_config.write_or_read.first();

		start_item(req);
		assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==1);(ARLEN==len);(ARADDR==addr);(ARBURST==burst);(ARSIZE==size);(ARID==req.ARID);(ARLOCK==0);(ARCACHE==0);(ARPROT==0);
											(ARQOS==0); (ARIDUNQ==unique_id);(ARCHUNKEN== archunken);
											(RREADY==0);
									});
		finish_item(req);
	//	wait(h_config.rd_addr_ev);

endtask



//--------------------------------for atomic purpose------------- ar channel-----------------
task ar_channel_signals_atomic(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst,bit aridunq);
 		 h_config.write_or_read = h_config.write_or_read.first();

		start_item(req);

		assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==1);(ARLEN==`LEN);(ARADDR==`ADDRESS);(ARBURST==`BURST);(ARSIZE==`SIZE);(ARID==req.ARID);(ARCACHE==0);(ARPROT==0);(ARIDUNQ==aridunq);(ARLOCK==0);
											(ARQOS==0);
											(RREADY==0);
									});



		finish_item(req);
	//	wait(h_config.rd_addr_ev);

endtask


//=======================task for r channel signals driving ============================

task r_channel_signals();

//=================================================driving r channel signals
	
		for(int i=0;i<=h_config.ARLEN;i++)begin
			start_item(req);
			assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==0);(ARADDR==0);(ARSIZE==0);(ARBURST==0);(ARLEN==0);(ARID==0);(ARCACHE==0);(ARLOCK==0);(ARPROT==0);(ARQOS==0);
											(RREADY==1);

										}); 
			finish_item(req); 

			h_config.wdata_atomic_compare;	//---------valid data storing purpose ---------

 
	//		wait(h_config.rd_data_ev);
		//	$display($time,"read data  phase handshake completed from master");	
		end

endtask

task r_channel_signals_rdc();

//=================================================driving r channel signals
	

		for(int i=0;i<(h_config.total_chunks);i++)begin
	//		if(h_config.total_chunks==h_config.chunk_num) begin break; end
			start_item(req);
			assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
											(AWPROT==0);(AWLOCK==0);(AWQOS==0);
											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==0);(ARADDR==0);(ARSIZE==0);(ARBURST==0);(ARLEN==0);(ARID==0);(ARCHUNKEN==1);(ARCACHE==0);(ARPROT==0);(ARLOCK==0);(ARQOS==0);
											(RREADY==1);

										}); 
			finish_item(req);  
			//wait(h_config.rd_data_ev);
			if(h_config.total_chunks==h_config.chunk_num) begin break; end
		end

endtask

//==========================================================================================
//========================task for READ DATA CHUNKING =============================
//============================================================================================
task read_data_chunking_cases(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst,bit unique_id,bit archunken);

	aw_channel_signals(addr,len,size,burst,unique_id);//--addr,len,size,burst,unique_id

	w_channel_signals;

	b_channel_signals;

	ar_channel_signals(addr,len,size,burst,unique_id,archunken);//--addr,len,size,burst,unique_id,archunken


	r_channel_signals_rdc;


endtask


//****************************************************************************************************
//===============================tasks for exclusive access purpose===================================
//****************************************************************************************************

//=============================task for aw channel signals for exclusive =============================

task aw_channel_signals_exclusive(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst , bit unique_id,bit [(`MAX_AXI5_ID_WIDTH - 1):0]awid);

		h_config.write_or_read = h_config.write_or_read.last();

//================================driving write address channel signals
		start_item(req);
		assert(req.randomize() with {(AWVALID==1);(AWID==awid);(AWADDR==addr);(AWATOP=='b000000);(AWBURST==burst);(AWLEN==len);(AWSIZE==size);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==1);(AWQOS==0);(AWIDUNQ==unique_id);
										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==0);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARLOCK==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
										(RREADY==0);

										});
		finish_item(req);
		h_config.WSTRB_config=new[h_config.AWLEN+1];//---memory creation for dynamic array
		write_strobe_update;



endtask
//==============================task for ar channel signals driving for exclusive =========================

task ar_channel_signals_exclusive(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst,bit unique_id);

 		 h_config.write_or_read = h_config.write_or_read.first();

		start_item(req);
		assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==1);(ARLEN==len);(ARADDR==addr);(ARBURST==burst);(ARSIZE==size);(ARID==req.ARID);(ARLOCK==1);(ARCACHE==0);(ARPROT==0);
											(ARQOS==0); (ARIDUNQ==unique_id);(ARCHUNKEN==0);
											(RREADY==0);
									});

		h_config.ex_id = req.ARID;

		h_config.exclusive_id_queue.push_back(req.ARID);
		finish_item(req);

endtask
task ar_channel_signals_exclusive_same_id(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst,bit unique_id,bit [`MAX_AXI5_ID_WIDTH-1:0] arid);

 		 h_config.write_or_read = h_config.write_or_read.first();

		start_item(req);
		assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==1);(ARLEN==len);(ARADDR==addr);(ARBURST==burst);(ARSIZE==size);(ARID==arid);(ARLOCK==1);(ARCACHE==0);(ARPROT==0);
											(ARQOS==0); (ARIDUNQ==unique_id);(ARCHUNKEN==0);
											(RREADY==0);
									});

//		h_config.ex_rd_id_to_basic_wr = req.ARID;

		finish_item(req);

endtask

//----------------------------EXLUSIVE ACCESS SAME or DIFF  Id PURPOSE-------------------
task aw_channel_ex_same_or_diff_id(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst , bit unique_id , bit [(`MAX_AXI5_ID_WIDTH-1):0] awid);

		h_config.write_or_read = h_config.write_or_read.last();

//================================driving write address channel signals
		start_item(req);
		assert(req.randomize() with {(AWVALID==1);(AWID==awid);(AWADDR==addr);(AWATOP=='b000000);(AWBURST==burst);(AWLEN==len);(AWSIZE==size);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);(AWIDUNQ==unique_id);
										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==0);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
										(RREADY==0);

										});
		finish_item(req);
		h_config.WSTRB_config=new[h_config.AWLEN+1];//---memory creation for dynamic array
		write_strobe_update;

endtask

//------------------------------exclusive read operation------------------------------------
task exclusive_read_operation(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);

	ar_channel_signals_exclusive(addr,len,size,burst,unique_id);//--addr,len,size,burst,unique_id,archunken
	r_channel_signals;

endtask
task exclusive_read_operation_same_id(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);

	ar_channel_signals_exclusive_same_id(addr,len,size,burst,unique_id,h_config.ex_id);//--addr,len,size,burst,unique_id,archunken
	r_channel_signals;

endtask

//-----------------------------------exclusive_write_operation---------------------------------

task exclusive_write_operation(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);


	aw_channel_signals_exclusive(addr,len,size,burst,unique_id,h_config.ex_id);//--addr,len,size,burst,unique_id

	w_channel_signals;

	b_channel_signals;

endtask

//---------------------------basic read operation ------------------------------

task basic_read(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);
	
	ar_channel_signals(addr,len,size,burst,unique_id,0);

	r_channel_signals;

endtask
//---------------------------basic write operation ------------------------------

task basic_write(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);
	
	aw_channel_signals(addr,len,size,burst,unique_id);

	w_channel_signals;
	b_channel_signals;

endtask

//----------------------------exclusive read_write_operation-------------------------------

task basic_exclusive_read_write(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst);
	exclusive_read_operation(addr,len,0,size,burst);

	exclusive_write_operation(addr,len,0,size,burst);
	basic_read(addr,len,0,size,burst);

endtask

//=================================================================================//
//========== FOR PASSING SAME ID AFTER INVOKING EXCLUSIVE READ OPERATION ==========//
//=================================================================================//

task basic_write_Exrd_same_ID(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);
	aw_channel_ex_same_or_diff_id(addr,len,size,burst,unique_id,(h_config.exclusive_id_queue.pop_front()));
	w_channel_signals();
	b_channel_signals();
endtask

//=====================multiple exclusive read operation ==============

task multiple_exclusive_read_operation(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);

	ar_channel_signals_exclusive(addr,len,size,burst,unique_id);
	r_channel_signals;
endtask

task multiple_exclusive_wr1_wr2_operation(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);
	aw_channel_signals_exclusive(addr,len,size,burst,unique_id,h_config.exclusive_id_queue.pop_front());
	w_channel_signals();
	b_channel_signals();
endtask

task multiple_exclusive_wr2_wr1_operation(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit unique_id,bit[2:0]size,bit[1:0]burst);
	aw_channel_signals_exclusive(addr,len,size,burst,unique_id,h_config.exclusive_id_queue.pop_back());
	w_channel_signals();
	b_channel_signals();
endtask

//---------------------------------------------------function to generate strobes------------------------------//
function automatic void write_strobe_update();		
        //--------internal variables-----------//
		int a; // ----- start address for every beat for asserting strobe----//
		int count;//--- counting no of bits is asserted in strobe signl  in beat----//
		int Number_Bytes,Aligned_Address,strobe_signal_width;
		//------ checking whether address is alligned or not--------//

		strobe_signal_width = `MAX_AXI5_DATA_WIDTH/8;	
		Number_Bytes = 2 ** req.AWSIZE;
		Aligned_Address = (req.AWADDR / Number_Bytes) * Number_Bytes;
		if(req.AWADDR == Aligned_Address||req.AWATOP==6'B110001)
		begin			
			a=Aligned_Address%strobe_signal_width;
		end
		else
		begin						
			a=req.AWADDR%strobe_signal_width;
			count = req.AWADDR - Aligned_Address;	
		end	
		for(int i = 0;i <= req.AWLEN;i++)
		begin:Forbeats
			for(int j = a;j <= strobe_signal_width;j++)
			begin : For_every_Byte

				if(count==2**req.AWSIZE)
				begin		
					count=0;
					if(a>=strobe_signal_width) a=0;
					break;
				end	
				else 
				begin
					h_config.WSTRB_config[i][j] = 1'b1;
					count++;a++;						
				end
			end	:For_every_Byte	
		end :Forbeats

	endfunction

endclass


//=================test case which is extend from base class==aligned_write_read_len_eq_0_incr=================//
class aligned_write_read_len_eq_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_write_read_len_eq_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(0,1,1,1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(0,1,1,1,1,0);
		r_channel_signals;
	endtask
endclass


//=================test case which is extend from base class=aligned_write_read_len_eq_0_wrap================//
class aligned_write_read_len_eq_0_wrap extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_write_read_len_eq_0_wrap);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(16,0,$clog2(`MAX_AXI5_DATA_WIDTH/8),2,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(16,0,$clog2(`MAX_AXI5_DATA_WIDTH/8),2,1,0);
		r_channel_signals;
	endtask
endclass


//=================test case which is extend from base class=unaligned_write_read_len_eq_0_incr================//
class unaligned_write_read_len_eq_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(unaligned_write_read_len_eq_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(2,0,$clog2(`MAX_AXI5_DATA_WIDTH/8),1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(2,0,$clog2(`MAX_AXI5_DATA_WIDTH/8),1,1,0);
		r_channel_signals;
	endtask
endclass


//=================test case which is extend from base class=unaligned_write_read_len_eq_0_wrap================//
class aligned_write_read_len_gr_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_write_read_len_gr_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(128,0,$clog2(`MAX_AXI5_DATA_WIDTH/8),1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(128,0,$clog2(`MAX_AXI5_DATA_WIDTH/8),1,1,0);
		r_channel_signals;
	endtask
endclass



//=================test case which is extend from base class=unaligned_write_read_len_gr_0_incr================//
class unaligned_write_read_len_gr_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(unaligned_write_read_len_gr_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(55,3,$clog2(`MAX_AXI5_DATA_WIDTH/8),1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(55,3,$clog2(`MAX_AXI5_DATA_WIDTH/8),1,1,0);
		r_channel_signals;
	endtask
endclass


//=================test case which is extend from base class=aligned_narrow_write_read_len_eq_0_incr================//
class aligned_narrow_write_read_len_eq_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_narrow_write_read_len_eq_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(112,0,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(112,0,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1,0);
		r_channel_signals;
	endtask
endclass

//unaligned_narrow_write_read_len_eq_0_incr

//=================test case which is extend from base class=unaligned_narrow_write_read_len_eq_0_incr================//
class unaligned_narrow_write_read_len_eq_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(unaligned_narrow_write_read_len_eq_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(501,0,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(501,0,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1,0);
		r_channel_signals;
	endtask
endclass



//=================test case which is extend from base class=aligned_narrow_write_read_len_gr_0_incr================//
class aligned_narrow_write_read_len_gr_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_narrow_write_read_len_gr_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(256,7,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(256,7,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1,0);
		r_channel_signals;
	endtask
endclass


//=================test case which is extend from base class=unaligned_narrow_write_read_len_gr_0_incr================//
class unaligned_narrow_write_read_len_gr_0_incr extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(unaligned_narrow_write_read_len_gr_0_incr);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(1001,7,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(1001,7,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,1,1,0);
		r_channel_signals;
	endtask
endclass

//=================test case which is extend from base class=aligned_write_read_len_gr_0_wrap================//
class aligned_write_read_len_gr_0_wrap extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_write_read_len_gr_0_wrap);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(768,7,$clog2(`MAX_AXI5_DATA_WIDTH/8),2,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(768,7,$clog2(`MAX_AXI5_DATA_WIDTH/8),2,1,0);
		r_channel_signals;
	endtask
endclass


//=================test case which is extend from base class=aligned_narrow_write_read_len_eq_0_wrap================//
class aligned_narrow_write_read_len_eq_0_wrap extends AXI5_sequence;

//=================factory registration===============//
	`uvm_object_utils(aligned_narrow_write_read_len_eq_0_wrap);
//================component constructor=============//
	function new(string name="");

		super.new(name);

	endfunction

//=================task body to drive signals to driver================//
	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");
		aw_channel_signals(1024,7,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,2,1);//---addr,len,size,burst
		w_channel_signals;
		b_channel_signals;
		ar_channel_signals(1024,7,$clog2(`MAX_AXI5_DATA_WIDTH/8)-1,2,1,0);
		r_channel_signals;
	endtask


endclass
//===========================read data chuncking =====================


class AXI5_sequence_512 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(AXI5_sequence_512)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction


//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);

//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	aw_channel_signals(0,3,6,1,1);//--addr,len,size,burst

	w_channel_signals;

	b_channel_signals;

	ar_channel_signals(0,3,6,1,1,1);

	//r_channel_signals;

	r_channel_signals_rdc();


	
endtask

endclass



class AXI5_sequence_256 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(AXI5_sequence_256)




//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction


//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);

//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	aw_channel_signals(0,3,5,1,1);//--addr,len,size,burst

	w_channel_signals;

	b_channel_signals;

	ar_channel_signals(0,3,5,1,1,1);

	//r_channel_signals;

	r_channel_signals_rdc();


	
endtask

endclass


class AXI5_sequence_128 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(AXI5_sequence_128)




//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction


//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);

//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	aw_channel_signals(0,3,4,1,1);//--addr,len,size,burst

	w_channel_signals;

	b_channel_signals;

	ar_channel_signals(0,3,4,1,1,1);

	//r_channel_signals;

	r_channel_signals_rdc();


	
endtask

endclass



class AXI5_sequence_1024 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(AXI5_sequence_1024)




//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction


//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);

//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	aw_channel_signals(0,1,7,1,1);//--addr,len,size,burst

	w_channel_signals;

	b_channel_signals;

	ar_channel_signals(0,1,7,1,1,1);

	//r_channel_signals;

	r_channel_signals_rdc();


	
endtask


endclass



//========================read data chunking individual test cases===========================
//==========================read_data_chunking_single_beat_INCR_128=========================
class read_data_chunking_single_beat_INCR_128 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_single_beat_INCR_128)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,0,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
endtask
endclass


//==========================read_data_chunking_multibeat_INCR_128=========================
class read_data_chunking_multibeat_INCR_128 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multibeat_INCR_128)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,3,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
endtask
endclass


//==========================read_data_chunking_multi_beat_WRAP_128=========================
class read_data_chunking_multi_beat_WRAP_128 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multi_beat_WRAP_128)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,3,4,2,1,1);//--addr,len,size,burst,unique_id,archunken	
endtask
endclass













//==================================read_data_chunking_max_possible_beats_255_INCR_128=



class  read_data_chunking_max_possible_beats_255_INCR_128 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_max_possible_beats_255_INCR_128)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,255,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass






//==================================read_data_chunking_single_beat_data_bus_INCR_256=



class read_data_chunking_single_beat_data_bus_INCR_256 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_single_beat_data_bus_INCR_256)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,0,5,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass




//==================================read_data_chunking_multibeat_INCR_256=



class read_data_chunking_multibeat_INCR_256 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multibeat_INCR_256)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,3,5,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass



//===================================read_data_chunking_multibeat_INCR_unaligned_address_256



class  read_data_chunking_multibeat_INCR_unaligned_address_256 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multibeat_INCR_unaligned_address_256)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(16,3,5,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass





//===================================read_data_chunking_single_beat_narrow_transfer_INCR_256



class read_data_chunking_single_beat_narrow_transfer_INCR_256 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_single_beat_narrow_transfer_INCR_256)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,0,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass






//===================================read_data_chunking_multi_beat_WRAP_256



class read_data_chunking_multi_beat_WRAP_256 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multi_beat_WRAP_256)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(32,3,5,2,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass

//===================================read_data_chunking_multi_beat_data_bus_INCR_512



class read_data_chunking_multi_beat_data_bus_INCR_512 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multi_beat_data_bus_INCR_512)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,3,6,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass

//===================================read_data_chunking_multi_beat_data_bus_INCR_1024



class read_data_chunking_multi_beat_data_bus_INCR_1024 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multi_beat_data_bus_INCR_1024)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,3,7,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass


//=============================error cases ======================
//===================================read_data_chunking_multi_beat_size_ne_data_width

class read_data_chunking_multi_beat_size_ne_data_width extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_multi_beat_size_ne_data_width)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,3,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass

//===================================read_data_chunking_single_beat_size_lt_128

class read_data_chunking_single_beat_size_lt_128 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_single_beat_size_lt_128)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(0,0,3,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass

//===================================read_data_chunking_addr_not_multiples_of_16

class read_data_chunking_addr_not_multiples_of_16 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_addr_not_multiples_of_16)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(8,0,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass

//===================================read_data_chunking_wrap_unalined_addr

class read_data_chunking_wrap_unalined_addr extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_wrap_unalined_addr)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(16,3,5,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass
//===================================read_data_chunking_addr_gt_4096

class read_data_chunking_addr_gt_4096 extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(read_data_chunking_addr_gt_4096)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
	read_data_chunking_cases(4092,3,4,1,1,1);//--addr,len,size,burst,unique_id,archunken	
	endtask
endclass


//*******************************************************************************************
//================================exclusive test cases ========================================
//********************************************************************************************

//===================================BASIC_READ_WRITE_EXCLUSIVE=============================

class BASIC_READ_WRITE_EXCLUSIVE extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(BASIC_READ_WRITE_EXCLUSIVE)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
		basic_exclusive_read_write(0,0,0,1);	//---------addr,len,size,burst -------------	
		basic_exclusive_read_write(8,0,1,1);
		basic_exclusive_read_write(16,0,2,1);
		basic_exclusive_read_write(32,0,3,1);
		basic_exclusive_read_write(48,0,4,1);
		basic_exclusive_read_write(96,0,5,1);
		basic_exclusive_read_write(128,0,6,1);
	//	basic_exclusive_read_write(256,0,7,1);

		//-----------len=0 not supported in wrap so len=1-------
		basic_exclusive_read_write(258,1,0,2);  //-----addr,Len,Size,burst
		basic_exclusive_read_write(260,1,1,2);
		basic_exclusive_read_write(280,1,2,2);
		basic_exclusive_read_write(320,1,3,2);
		basic_exclusive_read_write(480,1,4,2);
		basic_exclusive_read_write(640,1,5,2);
		basic_exclusive_read_write(768,1,6,2);

	//	basic_exclusive_read_write(1280,1,7,2); //-----Func Error----- exceeds 128 bytes----

		//------------multi beat---------//
//		basic_exclusive_read_write(0,127,0,1);  //-----addr,Len,Size	128,64,32,16,8,4,2----- func error --- 16 transfers exceeds---
//		basic_exclusive_read_write(192,31,1,1);	

		basic_exclusive_read_write(800,7,2,1);
		basic_exclusive_read_write(896,3,3,1);
		basic_exclusive_read_write(920,1,1,1);
		basic_exclusive_read_write(950,1,0,1);
		
	//	basic_exclusive_read_write(0,15,4,2);  //-----addr,Len,Size	128,64,32,16,8,4,2 --- func error --- exceeds 128 bytes --- 16*16
		basic_exclusive_read_write(1024,7,3,2);
		basic_exclusive_read_write(1120,3,2,2);
		basic_exclusive_read_write(1160,1,2,2);
		basic_exclusive_read_write(1180,1,1,2);
		basic_exclusive_read_write(1200,1,0,2);
	endtask
endclass

//===================================EX_READ_NORMAL_WRITE_WITH_SAME_ID_DIFF_ADDR_EX_WRITE

class EX_READ_NORMAL_WRITE_WITH_SAME_ID_DIFF_ADDR_EX_WRITE extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EX_READ_NORMAL_WRITE_WITH_SAME_ID_DIFF_ADDR_EX_WRITE)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
			exclusive_read_operation(2016,3,0,3,1);
			basic_write_Exrd_same_ID(2080,3,0,3,1);
			exclusive_write_operation(2016,3,0,3,1);


	endtask
endclass

//===================================EX_READ_NORMAL_WRITE_WITH_DIFF_ID_SAME_ADDR_EX_WRITE

class EX_READ_NORMAL_WRITE_WITH_DIFF_ID_SAME_ADDR_EX_WRITE extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EX_READ_NORMAL_WRITE_WITH_DIFF_ID_SAME_ADDR_EX_WRITE)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
			exclusive_read_operation(1280,3,0,3,1);
			basic_write(1280,3,0,3,1);
			exclusive_write_operation(1280,3,0,3,1);
		//	basic_read(1280,3,0,3,1);


	endtask
endclass


//===================================TWO_EX_READ_EX_WR1_WR2_DIFF_ID_SAME_ADDR

class TWO_EX_READ_EX_WR1_WR2_DIFF_ID_SAME_ADDR extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(TWO_EX_READ_EX_WR1_WR2_DIFF_ID_SAME_ADDR)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//

			multiple_exclusive_read_operation(1344,7,0,2,1);
			multiple_exclusive_read_operation(1344,7,0,2,1);
			multiple_exclusive_wr1_wr2_operation(1344,7,0,2,1);
			multiple_exclusive_wr1_wr2_operation(1344,7,0,2,1);
	endtask
endclass


//===================================TWO_EX_READ_EX_WR2_WR1_DIFF_ID_SAME_ADDR

class TWO_EX_READ_EX_WR2_WR1_DIFF_ID_SAME_ADDR extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(TWO_EX_READ_EX_WR2_WR1_DIFF_ID_SAME_ADDR)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//

			multiple_exclusive_read_operation(1344,7,0,2,1);
			multiple_exclusive_read_operation(1344,7,0,2,1);
			multiple_exclusive_wr2_wr1_operation(1344,7,0,2,1);
			multiple_exclusive_wr2_wr1_operation(1344,7,0,2,1);
	endtask
endclass


//===================================TWO_EX_READ_EX_WR2_WR1_SAME_ID_DIFF_ADDR

class TWO_EX_READ_EX_WR2_WR1_SAME_ID_DIFF_ADDR extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(TWO_EX_READ_EX_WR2_WR1_SAME_ID_DIFF_ADDR)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
			exclusive_read_operation(1472,7,0,2,1);
			exclusive_read_operation_same_id(1536,7,0,3,1);
			exclusive_write_operation(1536,7,0,3,1);	//----write 2
			exclusive_write_operation(1472,7,0,2,1); //--write 1 -resp 0 error condition due ID is overridden


	endtask
endclass


//===================================TWO_EX_READ_EX_WR1_WR2_SAME_ID_DIFF_ADDR

class TWO_EX_READ_EX_WR1_WR2_SAME_ID_DIFF_ADDR extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(TWO_EX_READ_EX_WR1_WR2_SAME_ID_DIFF_ADDR)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
			exclusive_read_operation(1632,7,0,2,1);
			exclusive_read_operation_same_id(1728,7,0,3,1);
			exclusive_write_operation(1632,7,0,2,1);//- write 1 ---error condition due ID is overridden
			exclusive_write_operation(1728,7,0,3,1); //-----write 2
	endtask
endclass


//===================================TWO_EX_READ_EX_WR2_WR1_SAME_ID_SAME_ADDR

class TWO_EX_READ_EX_WR2_WR1_SAME_ID_SAME_ADDR extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(TWO_EX_READ_EX_WR2_WR1_SAME_ID_SAME_ADDR)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//

			exclusive_read_operation(1856,7,0,2,1);
			exclusive_read_operation_same_id(1856,7,0,3,1);
			exclusive_write_operation(1856,7,0,3,1); //-----write 2
			exclusive_write_operation(1856,7,0,2,1);//- write 1 ---error condition due ID is overridden

	endtask
endclass


//===================================TWO_EX_READ_EX_WR1_WR2_SAME_ID_SAME_ADDR

class TWO_EX_READ_EX_WR1_WR2_SAME_ID_SAME_ADDR extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(TWO_EX_READ_EX_WR1_WR2_SAME_ID_SAME_ADDR)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
			exclusive_read_operation(1920,7,0,2,1);
			exclusive_read_operation_same_id(1920,7,0,3,1);
			exclusive_write_operation(1920,7,0,2,1);//- write 1 --- attributes diff ---- error case
			exclusive_write_operation(1920,7,0,3,1); //-----write 2

	endtask
endclass


//===================================EX_SEQUENCE_WITH_UNIQUE_ID

class EX_SEQUENCE_WITH_UNIQUE_ID extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EX_SEQUENCE_WITH_UNIQUE_ID)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
				exclusive_read_operation(2688,7,1,3,2);
				exclusive_write_operation(2688,7,1,3,2);
				basic_read(2688,7,1,3,2);			
	endtask
endclass


//===========================================================================
//==========================func error cases os exclusive access===========
//===========================================================================
//===================================EXCLUSIVE_WRITE_WITHOUT_READ

class EXCLUSIVE_WRITE_WITHOUT_READ extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EXCLUSIVE_WRITE_WITHOUT_READ)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
			exclusive_write_operation(2912,3,0,3,2);
			basic_read(2912,3,0,3,2);

			
	endtask
endclass
//===================================EX_RD_WR_WITH_DIFF_ATTRIBUTES

class EX_RD_WR_WITH_DIFF_ATTRIBUTES extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EX_RD_WR_WITH_DIFF_ATTRIBUTES)

//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

//==========================task body===============//
	task body();

//================================config class getting=========================

		uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config);
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//

			exclusive_read_operation(2976,3,0,2,1);
			exclusive_write_operation(2976,3,0,3,2);
			basic_read(2976,3,0,3,2);
			
	endtask
endclass



//=========================================================================================================================
//===============================atomic test cases=========================================================================
//=========================================================================================================================



//-------------------------ATOMIC_STORE_ADD_LE_CHECK---------------------------//

class ATOMIC_STORE_ADD_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_ADD_LE_CHECK);


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();
	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		req=AXI5_sequence_item::type_id::create("req");



		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,`LEN,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_ADD,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_STORE_CLR_LE_CHECK---------------------------//

class ATOMIC_STORE_CLR_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_CLR_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");

		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



	//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_CLR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass






//-------------------------ATOMIC_STORE_EOR_LE_CHECK---------------------------//

class ATOMIC_STORE_EOR_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_EOR_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();
		assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
		req=AXI5_sequence_item::type_id::create("req");

		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



	//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_EOR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass











//-------------------------ATOMIC_STORE_SET_LE_CHECK---------------------------//

class ATOMIC_STORE_SET_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_SET_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_SET,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//ATOMIC_STORE_SMAX_LE_CHECK



//-------------------------ATOMIC_STORE_SET_LE_CHECK---------------------------//

class ATOMIC_STORE_SMAX_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_SMAX_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_SMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass





//-------------------------ATOMIC_STORE_SMIN_LE_CHECK---------------------------//

class ATOMIC_STORE_SMIN_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_SMIN_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_SMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass


//========ATOMIC_STORE_UMAX_LE_CHECK



//-------------------------ATOMIC_STORE_UMAX_LE_CHECK---------------------------//

class ATOMIC_STORE_UMAX_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_UMAX_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_UMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_STORE_UMIN_LE_CHECK---------------------------//

class ATOMIC_STORE_UMIN_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_UMIN_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_UMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass











//-------------------------ATOMIC_STORE_ADD_BE_CHECK---------------------------//

class ATOMIC_STORE_ADD_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_ADD_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_ADD,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_STORE_CLR_BE_CHECK---------------------------//

class ATOMIC_STORE_CLR_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_CLR_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_CLR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass


//-------------------------ATOMIC_STORE_CLR_BE_CHECK---------------------------//

class ATOMIC_STORE_EOR_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_EOR_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_EOR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass





//-------------------------ATOMIC_STORE_SET_BE_CHECK---------------------------//

class ATOMIC_STORE_SET_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_SET_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_SET,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//-------------------------ATOMIC_STORE_SMAX_BE_CHECK---------------------------//

class ATOMIC_STORE_SMAX_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_SMAX_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_SMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_STORE_SMIN_BE_CHECK---------------------------//

class ATOMIC_STORE_SMIN_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_SMIN_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_SMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//-------------------------ATOMIC_STORE_UMAX_BE_CHECK---------------------------//

class ATOMIC_STORE_UMAX_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_UMAX_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_BIG_ENDIAN_UMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_STORE_UMIN_BE_CHECK---------------------------//

class ATOMIC_STORE_UMIN_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_STORE_UMIN_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_STORE_LITTLE_ENDIAN_UMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//-------------------------ATOMIC_LOAD_ADD_LE_CHECK---------------------------//

class ATOMIC_LOAD_ADD_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_ADD_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_ADD,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_CLR_LE_CHECK---------------------------//

class ATOMIC_LOAD_CLR_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_CLR_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_CLR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass


//-------------------------ATOMIC_LOAD_EOR_LE_CHECK---------------------------//

class ATOMIC_LOAD_EOR_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_EOR_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_EOR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_SET_LE_CHECK---------------------------//

class ATOMIC_LOAD_SET_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_SET_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_SET,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass





//-------------------------ATOMIC_LOAD_SMAX_LE_CHECK---------------------------//

class ATOMIC_LOAD_SMAX_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_SMAX_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_SMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass





//-------------------------ATOMIC_LOAD_SMIN_LE_CHECK---------------------------//

class ATOMIC_LOAD_SMIN_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_SMIN_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_SMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass





//-------------------------ATOMIC_LOAD_UMAX_LE_CHECK---------------------------//

class ATOMIC_LOAD_UMAX_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_UMAX_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_UMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_UMIN_LE_CHECK---------------------------//

class ATOMIC_LOAD_UMIN_LE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_UMIN_LE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_LITTLE_ENDIAN_UMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_ADD_BE_CHECK---------------------------//

class ATOMIC_LOAD_ADD_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_ADD_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_ADD,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//-------------------------ATOMIC_LOAD_CLR_BE_CHECK---------------------------//

class ATOMIC_LOAD_CLR_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_CLR_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_CLR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_EOR_BE_CHECK---------------------------//

class ATOMIC_LOAD_EOR_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_EOR_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_EOR,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_SET_BE_CHECK---------------------------//

class ATOMIC_LOAD_SET_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_SET_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_SET,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//-------------------------ATOMIC_LOAD_SMAX_BE_CHECK---------------------------//

class ATOMIC_LOAD_SMAX_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_SMAX_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_SMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass






//-------------------------ATOMIC_LOAD_SMIN_BE_CHECK---------------------------//

class ATOMIC_LOAD_SMIN_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_SMIN_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_SMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//-------------------------ATOMIC_LOAD_UMAX_BE_CHECK---------------------------//

class ATOMIC_LOAD_UMAX_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_UMAX_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_UMAX,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass



//-------------------------ATOMIC_LOAD_UMIN_BE_CHECK---------------------------//

class ATOMIC_LOAD_UMIN_BE_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_LOAD_UMIN_BE_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_LOAD_BIG_ENDIAN_UMIN,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass





//-------------------------ATOMIC_SWAP_CHECK---------------------------//

class ATOMIC_SWAP_CHECK extends AXI5_sequence;

//======================factory registration================================//
	`uvm_object_utils(ATOMIC_SWAP_CHECK)


//==================instance===============
//	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction

	task body();

		req=AXI5_sequence_item::type_id::create("req");

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));


		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

		w_channel_signals;

		b_channel_signals;



		//=====================atomic write and read
		aw_channel_signals_atomic(64,0,AXI_BYTES_2,1,ATOMIC_SWAP,1);//--addr,len,size,burst,awatop,awidunq

		if(h_config.AWATOP[5:4]!=2'b01)
		r_channel_signals;
	
		w_channel_signals;

		b_channel_signals;

//===================basic read

		ar_channel_signals_atomic(64,0,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

		r_channel_signals;


	endtask

endclass




//=================================sequence for atomic compare=======================================//


class ATOMIC_COMPARE_tc extends AXI5_sequence;

//=======================factory registeration====================

	`uvm_object_utils(ATOMIC_COMPARE_tc)


	AXI5_config_class h_config;


//==============construction================================

	function new(string name="");
		super.new(name);
	endfunction


//==========================task body===============//
task body();

//================================config class getting=========================

	  assert(uvm_config_db #(AXI5_config_class) :: get(null,"","AXI5_config_class",h_config));
//======================memory creation for sequence item===//
	req=AXI5_sequence_item::type_id::create("req");
//============================invoking tasks for driving master signals=================//
//===============basic write
	aw_channel_signals_atomic(8,1,AXI_BYTES_2,2,NON_ATOMIC,0);//--addr,len,size,burst,awatop,awidunq

	w_channel_signals;

	b_channel_signals;



//=====================atomic write and read
	aw_channel_signals_atomic(8,1,AXI_BYTES_2,2,ATOMIC_COMPARE,1);//--addr,len,size,burst,awatop,awidunq

	if(h_config.AWATOP[5:4]!=2'b01)
	r_channel_signals;
	
	w_channel_signals;

	b_channel_signals;

//===================basic read

	ar_channel_signals_atomic(8,1,AXI_BYTES_2,1,0);//----addr,len,size,burst,aridunq

	r_channel_signals;

endtask

//=============================task for aw channel signals =============================

task aw_channel_signals_atomic(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,axi5_size_e size,bit[1:0]burst,axi5_awatop_e atomic_op,bit awidunq);
		h_config.write_or_read = h_config.write_or_read.last();

//================================driving write address channel signals
		start_item(req);

		assert(req.randomize() with {(AWVALID==1);(AWID==req.AWID);(AWADDR==`ADDRESS);(AWATOP==atomic_op);(AWBURST==`BURST);(AWLEN==`LEN);(AWSIZE==`SIZE);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);(AWIDUNQ==awidunq);
										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==0);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
										(RREADY==0);

										});
		finish_item(req);
	//	wait(h_config.wr_addr_ev);
	 	h_config.WSTRB_config=new[h_config.AWLEN+1];//---memory creation for dynamic array
		write_strobe_update;

endtask


//======================================task for w channel signals driving =========================

task w_channel_signals;

//=================================driving write data channel signals
	//	if(AWATOP==0) wdata_atomic_compare=new[h_config.AWLEN+1];
		for(int i=0;i<=h_config.AWLEN;i++)begin
			start_item(req);
			h_config.total_beats=i;
			h_config.write_data_config();
			
			if(h_config.AWATOP[5:4]!=2'b11) begin
				h_config.WDATA=new[h_config.AWLEN+1];//----------------------for storing the read data to send for atomic compare

				assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
											(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==1);(WSTRB==h_config.WSTRB_config[i]);(WLAST==h_config.WLAST);(WDATA==req.WDATA);
											(BREADY==0);
											(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
											(RREADY==0);

										});
			end
			else if(h_config.AWATOP[5:4]==2'b11) begin
				//	if(h_config.AWBURST==1&&i>((h_config.AWLEN)/2)) h_config.randomize();
					assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
											(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==1);(WSTRB==h_config.WSTRB_config[i]);(WLAST==h_config.WLAST);(WDATA==h_config.WDATA[i]);
											(BREADY==0);
											(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
											(RREADY==0);

										});
				//	$display($time,"************from slave sequence***********************************h_config.WDATA[i]=%d==%p",h_config.WDATA[i],h_config.WDATA);


			end

			finish_item(req);
		//	wait(h_config.wr_data_ev);
		end



endtask


//==============================task for b channel signals driving =========================

task b_channel_signals;

//=======================drivng response phase signals
		
		start_item(req);
		assert(req.randomize() with {
										(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

										(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
										(BREADY==1);
										(ARVALID==0);(ARADDR==0);(ARLEN==0);(ARSIZE==0);(ARBURST==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
										(RREADY==0);
									});
		finish_item(req);

	//	wait(h_config.wr_resp_ev);
endtask


//==============================task for ar channel signals driving=========================

task ar_channel_signals_atomic(bit [`MAX_AXI5_ADDRESS_WIDTH-1:0]addr,bit [7:0]len,bit[2:0]size,bit[1:0]burst,bit aridunq);
 		 h_config.write_or_read = h_config.write_or_read.first();

		start_item(req);

		assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==1);(ARLEN==`LEN);(ARADDR==`ADDRESS);(ARBURST==`BURST);(ARSIZE==`SIZE);(ARID==req.ARID);(ARCACHE==0);(ARPROT==0);(ARIDUNQ==aridunq);(ARLOCK==0);
											(ARQOS==0);
											(RREADY==0);
									});



		finish_item(req);
	//	wait(h_config.rd_addr_ev);

endtask


//=======================task for r channel signals driving ============================

task r_channel_signals();

//=================================================driving r channel signals
	
		for(int i=0;i<=h_config.ARLEN;i++)begin
			start_item(req);
			assert(req.randomize() with {
											(AWVALID==0);(AWID==0);(AWADDR==0);(AWATOP==0);(AWBURST==0);(AWLEN==0);(AWSIZE==0);(AWCACHE==0);
										(AWPROT==0);(AWLOCK==0);(AWQOS==0);

											(WVALID==0);(WLAST==0);(WSTRB==0);(WDATA==0);
											(BREADY==0);
											(ARVALID==0);(ARADDR==0);(ARSIZE==0);(ARBURST==0);(ARLEN==0);(ARID==0);(ARCACHE==0);(ARPROT==0);(ARQOS==0);
											(RREADY==1);

										}); 
			finish_item(req);  
	
	//		wait(h_config.rd_data_ev);
		end
		h_config.wdata_atomic_compare();
endtask



//---------------------------------------------------function to generate strobes------------------------------//
function automatic void write_strobe_update();		
        //--------internal variables-----------//
		int a; // ----- start address for every beat for asserting strobe----//
		int count;//--- counting no of bits is asserted in strobe signl  in beat----//
		int Number_Bytes,Aligned_Address,strobe_signal_width;
		//------ checking whether address is alligned or not--------//

		strobe_signal_width = `MAX_AXI5_DATA_WIDTH/8;	
		Number_Bytes = 2 ** req.AWSIZE;
		Aligned_Address = (req.AWADDR / Number_Bytes) * Number_Bytes;
		if(req.AWADDR == Aligned_Address||req.AWATOP==6'B110001)
		begin			
			a=Aligned_Address%strobe_signal_width;
		end
		else
		begin						
			a=req.AWADDR%strobe_signal_width;
			count = req.AWADDR - Aligned_Address;	
		end	
		for(int i = 0;i <= req.AWLEN;i++)
		begin:Forbeats
			for(int j = a;j <= strobe_signal_width;j++)
			begin : For_every_Byte

				if(count==2**req.AWSIZE)
				begin		
					count=0;
					if(a>=strobe_signal_width) a=0;
					break;
				end	
				else 
				begin
					h_config.WSTRB_config[i][j] = 1'b1;
					count++;a++;						
				end
			end	:For_every_Byte	
		end :Forbeats

	endfunction

endclass













