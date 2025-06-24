class AXI5_slave_sequence extends uvm_sequence #(AXI5_sequence_item);

//=======================factory registeration====================

	`uvm_object_utils(AXI5_slave_sequence)


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


	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

	if(h_config.AWATOP == 0) begin
		ar_channel_signals();
		if(h_config.ARCHUNKEN ==0 )r_channel_signals();
		else r_channel_signals_rdc;
	end

	else begin
//===============for atomic transactions

	aw_channel_signals();

	if(h_config.AWATOP[5:4]!=2'b01) r_channel_signals;
	
	w_channel_signals();

	b_channel_signals();

//==================normal read
	ar_channel_signals();

	r_channel_signals();

	end 
endtask

//=============================task for aw channel signals =============================

task aw_channel_signals;


//================================driving write address channel signals
		start_item(req);

		assert(req.randomize() with {(AWREADY==1);(ARREADY==0);(WREADY==0);
										(BVALID==0);(BID==0);(BRESP==0);(BIDUNQ==0);
										(RVALID==0);(RLAST==0);(RDATA==0);(RRESP==0);
										(RID==0);(RIDUNQ==0);(RCHUNKV==0);(RCHUNKNUM==0);
										(RCHUNKSTRB==0);(RPOISON==0);

									});

		finish_item(req);
endtask


//======================================task for w channel signals driving =========================

task w_channel_signals;

//=================================driving write data channel signals
		for(int i=0;i<=h_config.AWLEN;i++)begin

			start_item(req);
		
			assert(req.randomize() with {(AWREADY==0);(ARREADY==0);(WREADY==1);
										(BVALID==0);(BID==0);(BRESP==0);(BIDUNQ==0);
										(RVALID==0);(RLAST==0);(RDATA==0);(RRESP==0);
										(RID==0);(RIDUNQ==0);(RCHUNKV==0);(RCHUNKNUM==0);
										(RCHUNKSTRB==0);(RPOISON==0);
										});
			finish_item(req);
		end


endtask


//==============================task for b channel signals driving =========================

task b_channel_signals;

//=======================drivng response phase signals
		start_item(req);
			assert(req.randomize() with {	(AWREADY==0);(ARREADY==0);(WREADY==0);
											(BVALID==1);(BID==h_config.BID);(BRESP==h_config.BRESP);(BIDUNQ==h_config.BIDUNQ);
											(RVALID==0);(RLAST==0);(RDATA==0);(RRESP==0);
											(RID==0);(RIDUNQ==0);(RCHUNKV==0);(RCHUNKNUM==0);
											(RCHUNKSTRB==0);(RPOISON==0);
										});

		finish_item(req);
endtask


//==============================task for ar channel signals driving=========================

task ar_channel_signals;

		start_item(req);
			assert(req.randomize() with {	(AWREADY==0);(ARREADY==1);(WREADY==0);
											(BVALID==0);(BID==0);(BRESP==0);(BIDUNQ==0);
											(RVALID==1);(RLAST==0);(RDATA==0);(RRESP==0);
											(RID==0);(RIDUNQ==0);(RCHUNKV==0);(RCHUNKNUM==0);
											(RCHUNKSTRB==0);(RPOISON==0);

										});
		finish_item(req);
		
endtask


//=======================task for r channel signals driving ============================

task r_channel_signals;

//=================================================driving r channel signals
		for(int i=0;i< (h_config.ARLEN + 1'b1);i++)begin
			start_item(req);
					h_config.execute_read_data_phase();

					if(h_config.ARLOCK && (i==0))
						h_config.execute_exclusive_read_transaction();							
							assert(req.randomize() with {(AWREADY==0);(ARREADY==0);(WREADY==0);
											(BVALID==0);(BID==0);(BRESP==0);(BIDUNQ==0);
											(RVALID==1);(RLAST==h_config.RLAST);(RDATA==h_config.RDATA);
											(RRESP==h_config.RRESP);
											(RID==h_config.RID);(RIDUNQ==h_config.RIDUNQ);(RCHUNKV==h_config.RCHUNKV);
											(RCHUNKNUM==h_config.RCHUNKNUM);
											(RCHUNKSTRB==h_config.RCHUNKSTRB);(RPOISON==h_config.RPOISON);
										                });
			finish_item(req);  
		end
	h_config.ar_ch_handshake=0;
endtask




    task r_channel_signals_rdc;
//=================================================driving r channel signals
			for(int i=0;i<(h_config.total_chunks);i++)
        	begin//{
					start_item(req);
					//----------calling executing read_data_phase before getting RDATA on to interface from config---------------
							h_config.execute_read_data_phase;

							assert(req.randomize() with {(AWREADY==0);(ARREADY==0);(WREADY==0);
											(BVALID==0);(BID==0);(BRESP==0);(BIDUNQ==0);
											(RVALID==1);(RLAST==h_config.RLAST);(RDATA==h_config.RDATA);
											(RRESP==h_config.RRESP);
											(RID==h_config.RID);(RIDUNQ==h_config.RIDUNQ);(RCHUNKV==h_config.RCHUNKV);
											(RCHUNKNUM==h_config.RCHUNKNUM);
											(RCHUNKSTRB==h_config.RCHUNKSTRB);(RPOISON==h_config.RPOISON);
										                });
					finish_item(req);  			
			if(h_config.total_chunks==h_config.chunk_num) begin break; end
		   end//}
    endtask


endclass



class basic_exclusive_read_write extends AXI5_slave_sequence;

//=======================factory registeration====================

	`uvm_object_utils(basic_exclusive_read_write)


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


//----------------------exclusive read
		
		ar_channel_signals();
		 r_channel_signals;
//---------------------exclusive write
	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

//==================normal read
	ar_channel_signals();

	r_channel_signals();

endtask

endclass


class EX_RD_NORMAL_WR_WITH_SAME_ID_DIFF_ADDR_EX_WR extends AXI5_slave_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EX_RD_NORMAL_WR_WITH_SAME_ID_DIFF_ADDR_EX_WR)


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


//----------------------exclusive read
		ar_channel_signals();
		 r_channel_signals;
//---------------------normal write
	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

//---------------------exclusive write
	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

endtask

endclass






class EX_OP_WITH_2_READS_2_WRITES extends AXI5_slave_sequence;

//=======================factory registeration====================

	`uvm_object_utils(EX_OP_WITH_2_READS_2_WRITES)


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


//----------------------exclusive read
		ar_channel_signals();
		 r_channel_signals;
		ar_channel_signals();
		 r_channel_signals;

//---------------------ex  write
	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

//---------------------exclusive write
	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

endtask

endclass



class exclusive_write_without_read extends AXI5_slave_sequence;

//=======================factory registeration====================

	`uvm_object_utils(exclusive_write_without_read)


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

//---------------------exclusive write
	aw_channel_signals();

	w_channel_signals();

	b_channel_signals();

//==================normal read
	ar_channel_signals();

	r_channel_signals();

endtask

endclass


