class AXI5_scoreboard extends uvm_scoreboard;

//====================factory registration =================
	`uvm_component_utils(AXI5_scoreboard)

	`uvm_analysis_imp_decl(_outmon)

//===============construction =======================

	function new(string name="", uvm_component parent);
		super.new(name,parent);
	endfunction

//=======================analysis implement port declaration==============
	uvm_analysis_imp #(AXI5_sequence_item , AXI5_scoreboard) h_in_monitor;
	uvm_analysis_imp_outmon #(AXI5_sequence_item , AXI5_scoreboard) h_out_monitor;

//======================seq item instance =========================
	AXI5_sequence_item h_seq_item_in , h_seq_item_out;

//====================interface instance =========================
	virtual intf h_intf;

//======================config instance==============

	AXI5_config_class h_config;

//====================build phase=======================

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

//====================memory creation=======================
		h_in_monitor = new("h_in_monitor",this);
		h_out_monitor = new("h_out_monitor",this);
		h_seq_item_in = new("h_seq_item_in");
		h_seq_item_out = new("h_seq_item_out");
	
	endfunction

//===========================connect phase=====================

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		assert(uvm_config_db #(virtual intf) :: get(this , this.get_full_name() , "intf" , h_intf));
		assert(uvm_config_db #(AXI5_config_class)::get(null,this.get_full_name(),"AXI5_config_class",h_config));

	endfunction

//====================write functions==================

	function void write(input AXI5_sequence_item in_data);
		h_seq_item_in = in_data;
	endfunction

	function void write_outmon(input AXI5_sequence_item out_data);
		h_seq_item_out = out_data;
	endfunction


//===================run phase =========================

	task run_phase(uvm_phase phase);
		super.run_phase(phase);

		forever begin
//$display($time,"***************************************************  in mon indicator  %d  out mon indicator  %d",h_config.input_monitor_write_indicator,h_config.output_monitor_write_indicator);

		if(h_config.input_monitor_write_indicator && h_config.output_monitor_write_indicator)begin

		$display(" \n\n\n\n  %d ############################## SCOREBOARD COMPARISON STARTED ##########################  \n\n\n\n ",$time);

//===================================comparing the ids and response signals from input and output monitors===================
		if(h_config.response_flag)begin//{
			if((h_seq_item_in.BID == h_seq_item_out.BID) && (h_seq_item_in.BRESP == h_seq_item_out.BRESP) && (h_seq_item_in.BIDUNQ == h_seq_item_out.BIDUNQ)) begin

				`uvm_info(" ************ WRITE RESPONSE PASS  ************",$sformatf(" \n\n FROM IN-MONITOR --- BID = %0d , BRESP = %0d , BIDUNQ = %0d , \n\n FROM OUT-MONITOR --- BID = %0d , BRESP = %0d , BIDUNQ = %0d ",h_seq_item_in.BID,h_seq_item_in.BRESP,h_seq_item_in.BIDUNQ,h_seq_item_out.BID,h_seq_item_out.BRESP,h_seq_item_out.BIDUNQ),UVM_LOW);

			end

			else begin
				`uvm_info(" ************ WRITE RESPONSE FAIL  ************",$sformatf(" \n\n FROM IN-MONITOR --- BID = %0d , BRESP = %0d , BIDUNQ = %0d , \n\n FROM OUT-MONITOR --- BID = %0d , BRESP = %0d , BIDUNQ = %0d ",h_seq_item_in.BID,h_seq_item_in.BRESP,h_seq_item_in.BIDUNQ,h_seq_item_out.BID,h_seq_item_out.BRESP,h_seq_item_out.BIDUNQ),UVM_LOW);

			end
		end//}
//===================================comparing the ids and response signals from input and output monitors===================
		if(h_config.read_channel_flag)begin//{

			if(h_config.AWLOCK==0 &&  h_config.ARLOCK==0) begin	
				if((h_seq_item_in.RRESP == h_seq_item_out.RRESP) && (h_seq_item_in.RID == h_seq_item_out.RID) && (h_config.poison_in_monitor_que == h_config.poison_out_monitor_que)) begin

					`uvm_info(" ************ READ RESPONSE PASS  ************",$sformatf(" \n\n FROM IN-MONITOR --- RRESP = %0d  , RID = %0d  ,    RPOISON = %p \n\n FROM OUT-MONITOR --- RRESP = %0d , RID = %0d ,    RPOISON = %p ",h_seq_item_in.RRESP,h_seq_item_in.RID,h_config.poison_in_monitor_que,h_seq_item_out.RRESP,h_seq_item_out.RID,h_config.poison_out_monitor_que),UVM_LOW);

				end

				else begin
					`uvm_info(" ************ READ RESPONSE FAIL  ************",$sformatf(" \n\n FROM IN-MONITOR --- RRESP = %0d  , RID = %0d  ,    RPOISON = %p \n\n FROM OUT-MONITOR --- RRESP = %0d , RID = %0d ,    RPOISON = %p ",h_seq_item_in.RRESP,h_seq_item_in.RID,h_config.poison_in_monitor_que,h_seq_item_out.RRESP,h_seq_item_out.RID,h_config.poison_out_monitor_que),UVM_LOW);

				end
			end
			else begin
				if((h_seq_item_in.RRESP == h_seq_item_out.RRESP) && (h_seq_item_in.RID == h_seq_item_out.RID)) begin

					`uvm_info(" ************ READ RESPONSE PASS  ************",$sformatf(" \n\n FROM IN-MONITOR --- RRESP = %0d  , RID = %0d  \n\n FROM OUT-MONITOR --- RRESP = %0d , RID = %0d ",h_seq_item_in.RRESP,h_seq_item_in.RID,h_seq_item_out.RRESP,h_seq_item_out.RID),UVM_LOW);

				end

				else begin
					`uvm_info(" ************ READ RESPONSE FAIL  ************",$sformatf(" \n\n FROM IN-MONITOR --- RRESP = %0d  , RID = %0d  \n\n FROM OUT-MONITOR --- RRESP = %0d , RID = %0d ",h_seq_item_in.RRESP,h_seq_item_in.RID,h_seq_item_out.RRESP,h_seq_item_out.RID),UVM_LOW);

				end



			end
		end//}

//==========================comparing RDATA from input monitor and output monitor of read operation=======================
		if(((h_seq_item_out.RRESP==0 && h_seq_item_in.RRESP ==0) || (h_seq_item_out.RRESP ==1 && h_seq_item_in.RRESP==1)) && h_config.read_channel_flag)begin//{

			if((h_config.store_mem_data_input_monitor == h_config.store_rdata_output_monitor)) begin

				`uvm_info(" ************  DATA PASS  ************",$sformatf(" \n\n FROM IN-MONITOR ---  RDATA   %p \n\n  FROM OUT-MONITOR --- RDATA  %p \n\n",h_config.store_mem_data_input_monitor,h_config.store_rdata_output_monitor),UVM_LOW);
				
			end

			else begin

				`uvm_info(" ************  DATA FAIL  ************",$sformatf(" \n\n FROM IN-MONITOR ---  RDATA   %p \n\n  FROM OUT-MONITOR --- RDATA  %p \n\n",h_config.store_mem_data_input_monitor,h_config.store_rdata_output_monitor),UVM_LOW);


			end
		end//}
		else begin

				`uvm_info(" ************  DATA PASS  ************",$sformatf(" \n\n \t FROM SCOREBOARD DATA MATCHED DUE TO READ ERROR RESPONSE (OR) READ OPERATION NOT INVOKED \n\n  "),UVM_LOW);

		end


//==========================comparing RDATA from input monitor and output monitor of read data chunking =======================
		if(h_config.RCHUNKV && h_config.read_channel_flag) begin//{

			if((h_config.slave_memory_chunknum == h_config.monitor_memory_chunknum)) begin

				`uvm_info(" ************  DATA PASS  ************",$sformatf(" \n\n FROM OUT-MONITOR ---  READ DATA CHUNKING RDATA  %p \n\n  FROM IN-MONITOR --- READ DATA CHUNKING RDATA %p \n\n",h_config.slave_memory_chunknum,h_config.monitor_memory_chunknum),UVM_LOW);
				
			end

			else begin

				`uvm_info(" ************  DATA FAIL  ************",$sformatf(" \n\n FROM OUT-MONITOR ---  READ DATA CHUNKING RDATA  %p \n\n  FROM IN-MONITOR --- READ DATA CHUNKING RDATA  %p \n\n",h_config.slave_memory_chunknum,h_config.monitor_memory_chunknum),UVM_LOW);


			end

//-=========================== comparing the RPOISON in input monitor and output monitor of read data chunking ==============
			if((h_config.monitor_poison_chunknum == h_config.slave_poison_chunknum)) begin

				`uvm_info(" ************  DATA PASS  ************",$sformatf(" \n\n FROM OUT-MONITOR ---  READ DATA CHUNKING POISION  %p \n\n  FROM IN-MONITOR --- READ DATA CHUNKING POISION %p \n\n",h_config.slave_poison_chunknum,h_config.monitor_poison_chunknum),UVM_LOW);
				
			end

			else begin

				`uvm_info(" ************  DATA FAIL  ************",$sformatf(" \n\n FROM OUT-MONITOR ---  READ DATA CHUNKING POISION  %p \n\n  FROM IN-MONITOR --- READ DATA CHUNKING POISION  %p \n\n",h_config.slave_poison_chunknum,h_config.monitor_poison_chunknum),UVM_LOW);


			end
	   end//}
		else begin
				`uvm_info(" ************  DATA PASS  ************",$sformatf(" \n\n \t READ DATA CHUNKING ERROR CASES ARE INVOKED (OR) READ CHANNEL NOT INVOKED \n\n"),UVM_LOW);

		end
			
			//@(h_intf.cb_monitor);
		h_config.input_monitor_write_indicator =0;h_config.store_mem_data_input_monitor.delete();h_config.r_ch_triggred=0;
		h_config.output_monitor_write_indicator =0;h_config.store_rdata_output_monitor.delete();h_config.b_ch_triggred=0;
				h_config.response_flag=0;
				h_config.read_channel_flag=0;			
		end
		#4;
	//	#4;

		end


	endtask

endclass 
