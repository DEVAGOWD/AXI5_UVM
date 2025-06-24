
class AXI5_config_class extends uvm_object;

//-------factory registration--------//
	`uvm_object_utils(AXI5_config_class)

//-------object construction---------//
	function new(string name = "AXI5_config_class");
			super.new(name);	
	endfunction

//---------virtual interface---------//
	virtual intf h_intf;

//----------------FOR MONITOR- for identification type of transaction(read,write) ----------------//
	axi5_write_read_e write_or_read;   //read or write

//****************************************************************************
//------------------------------internal variables--------------------------//
//***************************************************************************

//--------------------WRITE ADDRESS CHANNEL---------------//
    bit ARESETn, AWAKEUP;
    bit [((`MAX_AXI5_ID_WIDTH) - 1):0] AWID;
    bit [1:0] AWBURST;
    bit AWLOCK;
    bit [5:0] AWATOP;
    bit [3:0] AWCACHE;
    bit [2:0] AWPROT;
    bit AWVALID;
    bit AWREADY;
    bit [7:0] AWLEN;
    bit [2:0] AWSIZE;
    bit [((`MAX_AXI5_ADDRESS_WIDTH) - 1):0] AWADDR;
    bit [3:0] AWQOS;
    bit AWIDUNQ;

//--------------------WRITE DATA CHANNEL------------------//
    bit [((`MAX_AXI5_ID_WIDTH) - 1):0] WID;
    bit [(`MAX_AXI5_DATA_WIDTH-1):0] WDATA[];
    bit [(`MAX_AXI5_DATA_WIDTH-1):0] WDATA_S;
    bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0] WSTRB;
    bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0] RSTRB[];
    bit WLAST;
    bit WVALID;
    bit WREADY;
    bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] WPOISON_M[];
    bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] WPOISON;

//--------------------WRITE RESPONSE CHANNEL--------------//
    bit BREADY;
    bit [((`MAX_AXI5_ID_WIDTH) - 1):0] BID;
    bit [1:0] BRESP;
    bit BVALID;
    bit BIDUNQ;

//--------------------READ ADDRESS CHANNEL----------------//
    bit [((`MAX_AXI5_ADDRESS_WIDTH) - 1):0] ARADDR;
    bit [((`MAX_AXI5_ID_WIDTH) - 1):0] ARID;
    bit [7:0] ARLEN;
    bit [7:0] ARSIZE;
    bit [1:0] ARBURST;
    bit [3:0] ARQOS;
    bit ARLOCK;
    bit [3:0] ARCACHE;
    bit [2:0] ARPROT;
    bit ARVALID;
    bit ARREADY;
    bit ARIDUNQ;
    bit ARCHUNKEN;

//--------------------READ DATA CHANNEL-------------------//
    bit RREADY;
    bit [((`MAX_AXI5_ID_WIDTH) - 1):0] RID;
    bit [((`MAX_AXI5_DATA_WIDTH)-1):0] RDATA;
    bit [1:0] RRESP;
    bit RLAST;
    bit RVALID;
    bit RIDUNQ;
    bit RCHUNKV;
    bit [(`MAX_AXI5_DATA_WIDTH/128)-1:0] RCHUNKSTRB;
    bit [$clog2((4096*8)/`MAX_AXI5_DATA_WIDTH)-1:0] RCHUNKNUM;
    bit [(`MAX_AXI5_DATA_WIDTH/64 + ( (`MAX_AXI5_DATA_WIDTH % 64) / (`MAX_AXI5_DATA_WIDTH) ))-1:0] RPOISON;
    bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] RPOISON_STORE[];
//------------ used in slave driver for handshaking purpose-------------------------//
	bit ar_ch_handshake,aw_ch_handshake,w_ch_handshake;


//-----------------for every beat it will increase in master sequence---------------//
	int total_beats;

//---------------------signal to indicate weather the addr is aligned/unaligned-----//
	bit   	[((`MAX_AXI5_ADDRESS_WIDTH) - 1):0] aligned_addr;
	bit unaligned;				
	bit outstanding;

//---------- strobes are generated in master sequence--------------------------------------//
	bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0]WSTRB_config[];



//============tempapary variables ================//	

	bit	[(`MAX_AXI5_DATA_WIDTH/8)-1:0]temp_strb;			//================to store the strobe for corresponding beat	
    bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] base_addr_w,base_addr_r; 		//==========to store given address 
    bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] temp_s_addr; 					//============== used to calculate alined address
	int addr_diff;	
//------------------for wrap boundry --------------//
	int	lower_wrap_boundary,upper_wrap_boundary;		

//--------------------------------2d memory------------------------------------------------//
	bit [7:0] memory[(4096/(`MAX_AXI5_DATA_WIDTH/8))-1:0] [((`MAX_AXI5_DATA_WIDTH/8)-1):0]; 
	bit [(4096/(`MAX_AXI5_DATA_WIDTH/8))-1:0] row; //--row size based on data width for memory alignment w.r.t DATA WIDTH
    bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0] col;	   //--column size based on data width for memory alignment w.r.t DATA WIDTH
	bit [(4096/(`MAX_AXI5_DATA_WIDTH/8))-1:0] row_r; //--row size based on data width for memory alignment w.r.t DATA WIDTH
    bit [((`MAX_AXI5_DATA_WIDTH/8)-1):0] col_r;	   //--column size based on data width for memory alignment w.r.t DATA WIDTH
    int memory_row;

//===========================for exclusive acesss variables================================//

//-----------struct for storing ex_op attributs which are should same at ex_wr,ex_rd-------//
	typedef struct {bit pass_fail;
					bit [31:0]addr;bit[7:0]len;
					bit[2:0] size;bit[1:0]burst;} struct_attributes;
//-----------associate array for storing ex_rd id to track signals over ex_wr -------------//	
	struct_attributes store_attribute[int];
	bit ex_wr_without_ex_rd_or_diff_sgl;
	bit delete_ex_id;
//----------------------Temporary variables for Exclusive access---------------------
 	bit [((`MAX_AXI5_ADDRESS_WIDTH) - 1):0] ARADDR_t;
	bit [((`MAX_AXI5_ID_WIDTH) - 1):0] ARID_t;
	bit[7:0] ARLEN_t;
	bit[2:0]ARSIZE_t;
	bit[1:0]ARBURST_t;

//==================================poision feature========================================// 

//----------beat_addr for storing start addr for every beat, next_beat_granule_addr for calculating next set of granule  address-------//
	bit [`MAX_AXI5_ADDRESS_WIDTH-1:0] next_beat_granule_addr,beat_addr,poison_addr_l8;
//--------------------------for storing RPOISON for each beat-----------------------------//
	bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0]read_poison_array[];	
	int num_granules;
	int count_granule;
	bit granule_poison;
	int poison_bytes;
	int no_of_beats,no_of_beats_rd;
	bit [((`MAX_AXI5_DATA_WIDTH)-1):0]RDATA_store[];
	bit [7:0]poison_array[512];//----------for storing poison bit for every byte in a  each granule -->total_granules=4096/8

//================================= UNIQUE ID ===========================================//
//-----------------------------queue of type struct -------------------------------------//
    unq_struct resp_track_q[$]; 
	unq_id_struct   unq_id_q[$];     //---queue used for storing ID in unique id-wr---//
	unq_id_struct_rd unq_id_q_rd[$]; //---queue used for storing ID in unique id--rd--//
	unq_id_struct_rd temp_unq_id_q_rd;   
	unq_id_struct  temp_unq_id_q;
	unq_struct temp_struct;
    bit terminate_transaction,rst_indicator;
	bit unique_id_error_w,unique_id_error_r;

//============================= struct decleration for  TIME OUT FACTOR==============================================//
	_max_bit_t configuration_values[0:20] = '{0,0,10000,100000,1,1,1,1,1000,1000,1000,1000,1000,0,1,0,4095,0,0,0,0};

//========================================ATOMIC FEATURE=============================================//
	bit [(`MAX_AXI5_DATA_WIDTH)-1:0] store_q[$],comp_q[$];//====storing the swap and compare values of WDATA in ATOMIC_COMPARE
	bit poison_atomic_comp_q[$];
	bit atomic_error;
	int count,ind;
    bit [7:0] big_endian_queue[$];

//=================================== READ DATA CHUNKING ========================================//	
//-------------------------for storing 128 bit chunk into every beat--------------//	
	chunk_store queue_128_chunk[$][$];
    int total_chunks,chunk_num; 
	chunk_store temp_chunk,temp_chunk_q[$];
	int lower_boundary;
	int aligned_address,d_element;
	int random_chunknum,random_nof_chunk;
	bit random_pop;
	int base_addr;
	bit [(`MAX_AXI5_DATA_WIDTH/128)-1:0] temp_rstrb_final,temp_rstrb;

//=================================================================================================================//
//===========================================FOR MONITOR ===========indicators for wlast and reset control---------//
//=================================================================================================================//

	bit wlast_indicator_mon , terminate_transaction_mon ,input_monitor_write_indicator,output_monitor_write_indicator;
	bit [((`MAX_AXI5_DATA_WIDTH / 8)-1):0] read_valid_strobe_data[];
	bit [(`MAX_AXI5_DATA_WIDTH - 1):0]store_mem_data_input_monitor[$]; //------for memory data storage fpr input monitor-----------
	bit [(`MAX_AXI5_DATA_WIDTH - 1):0]store_rdata_output_monitor[$]; //------for memory data storage for output monitor-----------
	bit [(`MAX_AXI5_ADDRESS_WIDTH - 1):0] addr_poison;		//------ For poison purpose
	bit [((`MAX_AXI5_DATA_WIDTH / 8)-1):0] write_strobes [];
//=======================================for output monitor ---------- 

	bit response_flag , read_channel_flag,ar_channel_flag,aw_channel_flag;
//==============================for scoreboad for comparing bresp and resp
	bit b_ch_triggred,r_ch_triggred;
	// -------------- for unique id indication ------------------------------
	static bit[(`MAX_AXI5_ID_WIDTH-1):0]unique_id_indicator[int][$];
	bit exit_transaction;
	bit unique_id;
//---------------- Exclusive Access--------------------
	bit[1:0] exclusive_op_found;
	bit another_ex_op_invoked;
	bit [`MAX_AXI5_ID_WIDTH-1:0] exclusive_id_queue[$];
	bit [(`MAX_AXI5_ID_WIDTH-1) :0]ex_id;

//--------------------for read data chunking -------------------
	bit[(`MAX_AXI5_DATA_WIDTH-1):0]monitor_memory_chunknum[];	//--------------input monitor
	bit[(`MAX_AXI5_DATA_WIDTH-1):0]slave_memory_chunknum[];	//--------------output monitor

//-------------------------for poision purpose ------------------------

	bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] poison_in_monitor_que[$];
	bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] poison_out_monitor_que[$];
	bit[((`MAX_AXI5_DATA_WIDTH/64)-1):0]monitor_poison_chunknum[];	
	bit[((`MAX_AXI5_DATA_WIDTH/64)-1):0]slave_poison_chunknum[];

//==================================for monitor ---- creating the memory for strobe array---------------
	task strobe_memory_creation(input [7:0] arlen_mon);
		read_valid_strobe_data = new[arlen_mon+1];
	endtask


// =================== get config function =============== taking enum instance as an input which is located in package
	function _max_bit_t get_config(input config_en bfm_cfg_en);	
	   return configuration_values[bfm_cfg_en];
	endfunction

// ================== set config function =============== taking enum instance as an input which is located in package

	function void set_config(input config_en bfm_cfg_en,_max_bit_t cfg_value);
		configuration_values[bfm_cfg_en] = cfg_value;
	endfunction
//==========================================================================================
// ---------------------------- task for time out purposes --------------------
//=================================================================================================
	task automatic max_time_to_wait_for_ready(config_en bfg_cfg_enum);
		int counter;
		int configured_value;

		assert(uvm_config_db #(virtual intf) :: get(null, this.get_full_name() , "intf" , h_intf));

		//-----------------calling get_config funtion for config value------------
		configured_value = get_config(bfg_cfg_enum);

		fork
		  begin
		    forever@(h_intf.cb_monitor) begin					// ----- running forever loop and wait condition in fork-join_any format
				counter = counter+1;						// ----- forever loop to check max time out condition wait will trigger if reset is applied
				if(counter >= configured_value)begin		// --- if any one is true exit from the task
					`uvm_fatal(" ***** FROM MONITOR ***** ",$sformatf(" FROM MONITOR =========== exceeded max time out factor so exiting from the silumation ============= %0d",counter));
					break;
				end
			end
		  end

		 wait(!h_intf.ARESETn);

		join_any
		disable fork;
	endtask

//======================task to generate WLAST==================this task is called in master sequence=================//
	task write_data_config();
		if(total_beats == AWLEN)begin
			WLAST=1;
			unq_id_q.pop_front();
		end
		else begin
			WLAST=0;
		end
	endtask

	//===============================================================================//
	//---------------------------get write addr phase--------------------------//
	//===============================================================================//
	task get_write_addr_phase();
    	bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] temp_s_addr,aligned_addr; 									//============== used to calculate alined address
		//-------------------------getting interface into config class---------------------
		uvm_config_db #(virtual intf) :: get(null, this.get_full_name() , "intf" , h_intf);
		//----------------------- getting interface signal reset onto port ----------------

		//--------------unique_id_tracking------------------
		if(h_intf.ARESETn==0)
		begin
			AWADDR = 0;
        	AWID = 0;
        	AWLEN = 0;
        	AWSIZE = 0;
        	AWBURST = 0;
		end
     	//----------- checking that same id is repeated in the unique id feature------------------//
  		else
		begin//{
       		AWADDR = h_intf.AWADDR;
       		AWID = h_intf.AWID;
       		AWLEN = h_intf.AWLEN;
       		AWSIZE = h_intf.AWSIZE;
       		AWBURST = h_intf.AWBURST;
			AWATOP=h_intf.AWATOP;
			AWIDUNQ = h_intf.AWIDUNQ;
			AWLOCK=h_intf.AWLOCK;
			poison_addr_l8=AWADDR;
		    base_addr_w = AWADDR; 
            row = $floor((base_addr_w / (`MAX_AXI5_DATA_WIDTH / 8)));
            col = base_addr_w - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(base_addr_w / (`MAX_AXI5_DATA_WIDTH / 8)));

			if(AWIDUNQ)
				begin
				 	temp_unq_id_q.AWID = AWID;
			        temp_unq_id_q.AWIDUNQ = AWIDUNQ;
			        unq_id_q.push_back(temp_unq_id_q);
				end	
				unique_id_tracking();
	
					//--------------- for atomic operations(not for store) only obdating AR channel signals ---------//
	 		if (AWATOP > 0&&AWATOP[5:4]!=2'b01&&AWIDUNQ==1)begin//{ //-checking that it should be atomic, load, swap, compare--//
				ARADDR = AWADDR;
				ARID   = AWID;
	      	   	ARBURST = AWBURST;
				ARIDUNQ=AWIDUNQ;
	      	   	if (AWATOP != 49) 
					begin//{
	        	 	ARLEN = AWLEN;
	        		ARSIZE = AWSIZE;
	     	   		end//} 
				else begin//{//----------for atomic compare some size and length required manipulations
	        	  	if (AWLEN == 0) begin//{
	          	    	ARLEN = AWLEN;
	           			ARSIZE = AWSIZE-1;
	        		end//} 
				  	else begin//{
	            		ARLEN = AWLEN / 2;
	            		ARSIZE = AWSIZE;
	        		end//}
	       			end//}		
				atomic_configuration_check();
	        end//}
			else if(AWATOP > 0&&AWATOP[5:4]==2'b01&&AWIDUNQ==1) 	atomic_configuration_check(); 
  		end//}
	
        	temp_s_addr = (AWADDR / (2 ** AWSIZE)); //=====address nature calculation
        	aligned_addr = temp_s_addr * (2 ** AWSIZE);

        	if (aligned_addr != AWADDR) begin//{ //==============unaligned address 
            	unaligned = 1;
        	end//} 
			else begin//{
            	unaligned = 0;
        	end//}

			if(AWLOCK==1) get_exclusive_write_transaction;

	endtask



//===============================================================================//
//---------------------------executing write addr phase--------------------------//
//===============================================================================//
	task automatic get_write_data_phase();
		if (AWBURST == 1) begin//{ //--------INCR type transaction
	    	INCR_BURST_WRITE();
			count= 0;ind=0;  
	    end//} 

		else if (AWBURST == 2) begin//{ //----------wrap type transaction
	        WRAP_BURST_WRITE();
			count= 0;ind=0;
	    end//} 

		else begin//{
	        $display($time," from slave   =======fixed or reserved burst=============");
	     end//}
		//$display($time,"================= memory ============= %p",memory);
	endtask


	//=========================INCREAMENTING TASK=====================================
	task automatic INCR_BURST_WRITE();
		int i = 0;

	 if ((row * (`MAX_AXI5_DATA_WIDTH / 8)) + col >= 4096) begin//{
       BRESP = 3; 
      end//} 
	  else if (((2 ** AWSIZE) > (`MAX_AXI5_DATA_WIDTH / 8)) && h_intf.ARESETn) begin//{
        BRESP = 2; 
      end//}
	    if (!h_intf.ARESETn || terminate_transaction == 1) begin//{
	    	terminate_transaction = 1; 
	    	AWREADY = 0;
	    	WREADY = 0;
	    end//}       
		else begin//{
	        WREADY = 1;
	        // --------- collect the samples from mater bfm update-------------//
	        WDATA_S = h_intf.WDATA;
	        WLAST = h_intf.WLAST;
	        WVALID = h_intf.WVALID;
	        WSTRB = h_intf.WSTRB;
			WPOISON=h_intf.WPOISON;
		end//}
	    wait((WVALID) || !h_intf.ARESETn); // ----------------waiting for wvalid--------------//
		 num_granules=`MAX_AXI5_DATA_WIDTH/64;

		 beat_addr=  beat_addr+(2 **  AWSIZE);	
	
        if(AWATOP!=49)
		   poison_check();
		   granule_poison=0;	
		//----------------------exclusive accesss LOGIC driving strobe 0 when ex_wr fails need not to obdate memory -------------------------
		if(AWLOCK) 
		begin
		  if(store_attribute[AWID].pass_fail==1 || ex_wr_without_ex_rd_or_diff_sgl==1)
		  begin
				WSTRB=0; 		  
		  end	
		end

		for (int s = 0; s < (`MAX_AXI5_DATA_WIDTH / 8); s++) 
		begin//{								
	    	temp_strb = WSTRB; // ===storing individual bit of WSTRB into an array for comparison purpose====//
	    end//}
	
	    for(int j = 0; j < (`MAX_AXI5_DATA_WIDTH / 8); j++) 
		begin//{
	    	if (j <= (`MAX_AXI5_DATA_WIDTH / 8) && ((2 ** AWSIZE) <= `MAX_AXI5_DATA_WIDTH / 8)) 
			begin//{
	        	if (temp_strb[j] == 1) 
				begin//{ 										// ===checking that individual WSTRB bit is one or not===//
	            	if ((((row * (`MAX_AXI5_DATA_WIDTH / 8)) + col) >= 4096) && (BRESP != 2))
					begin 
	                  	BRESP = 3; 
						BID = AWID;
						BIDUNQ=AWIDUNQ;
	           		end//} 
					else if (AWATOP == 49&&BRESP==0) begin//{
                  	  	atomic_compare_INCR( no_of_beats, j);
               	  	 end//} 
					else if(AWATOP != 49&&(BRESP==0||BRESP==1)) begin//{
						non_atomic_and_atomic_store_load_swap_INCR(i, j);
						if(WLAST)//
						begin
							checking_memory_obdate_over_ex_rd_addrs(AWADDR,AWLEN,AWSIZE,AWBURST,AWID,AWLOCK);
						end
		 			end//}
	            end//} 
		 	 end//}
		end//}
		if ((AWATOP == 6'd24 || AWATOP == 6'd40 )&& (big_endian_queue.size==AWLEN+1) ) begin//{

            little_endian_2_big_endian(); 		// queue to store each byte
			i=0;
          end//}
         if((big_endian_queue.size==AWLEN+1)) begin 
			big_endian_queue.delete();i=0;
		end

		if (WLAST) begin//{
          BID = AWID;
          BIDUNQ = AWIDUNQ;
          BRESP = BRESP;
		end//}
		
		if (AWATOP == 49 && no_of_beats >= ((AWLEN + 1) / 2)&& atomic_error==0) begin//{

          at_compare_task();

	     end//}

		i = i + 1'b1;
		foreach(poison_array[k,j])begin//{
			if(poison_array[k][j]==1)begin//{
					for(int j=0;j<8;j++)
						poison_array[k][j]=1;
								
			end//}
			else 	poison_array[k][j]=0;
		end//}
		no_of_beats=no_of_beats+1;
		if(no_of_beats==(AWLEN+1)) begin
			no_of_beats=0;count=0;ind=0;
		end

		//$display($time,"-----------------memor -------------%p",memory);
	endtask


 	task non_atomic_and_atomic_store_load_swap_INCR(int beat, int byte_lane);
  	 	 bit[7:0] outbound_data, inbound_data; // for atomic transactions
		inbound_data = memory[row][col];//===========geting the data from the memory
   		 outbound_data = WDATA_S[(byte_lane * 8) +: 8];//============storing the wdata into the temp variable
    	WDATA_S[(byte_lane * 8) +: 8] = atomic_transaction(inbound_data, outbound_data);//=====function will return the value which has to store in meory

    	memory[row][col] = WDATA_S[(byte_lane * 8) +: 8];
 	   big_endian_queue.push_back(WDATA_S[(byte_lane * 8) +: 8]);

	//	$display($time,"@@@@@@@@@@ =====write =====memory = %p ======= row = %0d col = %d DATA = %D",memory[row][col],row,col,WDATA_S[(byte_lane * 8) +: 8]);
    	col = col + 1;
    	if(col == (`MAX_AXI5_DATA_WIDTH / 8)) begin//{ //{
        	row = row + 1;
      		col = 0;
    	end//} //}
  	endtask

	task automatic WRAP_BURST_WRITE();
		static int i;
      	base_addr_w = AWADDR;
      	row = $floor((base_addr_w / (`MAX_AXI5_DATA_WIDTH / 8)));
      	col = base_addr_w - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(base_addr_w / (`MAX_AXI5_DATA_WIDTH / 8)));

      	if ((row * (`MAX_AXI5_DATA_WIDTH / 8)) + col >= 4096) begin//{
        	BRESP = 3;
			BID = AWID;BIDUNQ=AWIDUNQ;
      	end//}

      	else if (((2 ** AWSIZE) > (`MAX_AXI5_DATA_WIDTH / 8)) && h_intf.ARESETn) begin//{
        	BRESP = 2;
			BID = AWID;BIDUNQ=AWIDUNQ;
      	end//}

      	else if (unaligned == 1 &&(AWATOP!=49)|| ($countones(AWLEN + 1) != 1 || AWLEN > 16||(AWLEN==0&&AWATOP!=49))) begin//{
        	BRESP = 2;
			BID = ARID;BIDUNQ=AWIDUNQ;
      	end//}

      	lower_wrap_boundary = ($floor(base_addr_w / ((2 ** AWSIZE) * (AWLEN + 1)))) * ((2 ** AWSIZE) * (AWLEN + 1));
      	upper_wrap_boundary = lower_wrap_boundary + ((2 ** AWSIZE) * (AWLEN + 1));
        // Wait on reset & posedge clock

		WDATA_S = h_intf.WDATA;
        WLAST = h_intf.WLAST;
        WVALID = h_intf.WVALID;
        WSTRB = h_intf.WSTRB;
		WPOISON=h_intf.WPOISON;
		if(AWATOP!=49)
		   poison_check();
		   granule_poison=0;	
		//num_granules=`MAX_AXI5_DATA_WIDTH/64;

		//beat_addr= beat_addr+(2 ** AWSIZE);	
	
		if(beat_addr==upper_wrap_boundary)
		begin
			beat_addr=lower_wrap_boundary;
			
		end

        // Transaction control
        for (int s = 0; s < (`MAX_AXI5_DATA_WIDTH / 8); s++) begin//{
	    	temp_strb = WSTRB; // ===storing individual bit of WSTRB into an array for comparison purpose====//
        end//}

        for (int j = 0; j < (`MAX_AXI5_DATA_WIDTH / 8); j++) 
		begin//{
       		if(j <= (`MAX_AXI5_DATA_WIDTH / 8) && ((2 ** AWSIZE) <= `MAX_AXI5_DATA_WIDTH / 8) && (unaligned == 0 && ($countones(AWLEN + 1) == 1 && 					AWLEN <= 16 && AWLEN>0) ||(unaligned == 1 && AWATOP == 49)))        
			begin//{
            	if (temp_strb[j] == 1) begin//{
                	if ((((row * (`MAX_AXI5_DATA_WIDTH / 8)) + col) >= 4096) && (BRESP != 2))
					begin//{
                		BRESP = 3;
						BID = AWID;BIDUNQ=AWIDUNQ;
                	end//}
					else if (AWATOP == 49&&BRESP==0) begin//{
                  	  	atomic_compare_WRAP( no_of_beats, j);
               	  	 end//} 

                else if(AWATOP != 49&&(BRESP==0||BRESP==1)) begin//{
                		non_atomic_and_atomic_store_load_swap_WRAP(i, j);
					if(WLAST)
						begin
							checking_memory_obdate_over_ex_rd_addrs(AWADDR,AWLEN,AWSIZE,AWBURST,AWID,AWLOCK);
						end


				end//}
			  end//}
           end//}
        end//}

        if (WLAST) begin//{
          BID = AWID;
          BIDUNQ = AWIDUNQ;
          BRESP = BRESP;
		/*	for(int i=0;i<512;i++)begin

				$display($time,"==========in wlast=========array[%0d]=%0d",i,poison_array[i]);
			end*/

          //resp_track_q.push_back(temp_struct);
         // new_id_count++;
        end//}
		if (AWATOP == 49 && no_of_beats >= ((AWLEN + 1) / 2)&& atomic_error==0) begin//{

          at_compare_task();
	     end//}


			foreach(poison_array[k,j])begin//{
				if(poison_array[k][j]==1)begin//{
					for(int j=0;j<8;j++)
						poison_array[k][j]=1;
								
				end//}
				else 	poison_array[k][j]=0;
			end//}

		no_of_beats=no_of_beats+1;
		if(no_of_beats==(AWLEN+1)) begin
			no_of_beats=0;count=0;ind=0;
		end
	endtask


	task non_atomic_and_atomic_store_load_swap_WRAP(int beat, int byte_lane);
    	memory[row][col] = WDATA_S[(byte_lane * 8) +: 8];
    	col = col + 1;

    	if(col == (`MAX_AXI5_DATA_WIDTH / 8)) 
		begin//{ //{
      		row = row + 1;
      		col = 0; 
    	end//} //}

    	AWADDR++;
    	if(AWADDR == upper_wrap_boundary) 
		begin//{ //{
      		AWADDR = lower_wrap_boundary;
      		row = $floor((AWADDR / (`MAX_AXI5_DATA_WIDTH / 8)));
      		col = (AWADDR - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor((AWADDR / (`MAX_AXI5_DATA_WIDTH / 8)))));
    	end//} //}
  endtask



//===============================================================================//
//---------------------------get read addr phase--------------------------//
//===============================================================================//
	task automatic get_read_addr_phase();

	  int base_addr;

	  if(h_intf.ARESETn) begin //{
	    ARVALID = h_intf.ARVALID;

		wait ((ARVALID)); // ----------------waiting for awvalid--------------//

	    ARADDR = h_intf.ARADDR;
	    ARID = h_intf.ARID;
	    ARLEN = h_intf.ARLEN;
	    ARSIZE = h_intf.ARSIZE;
	    ARBURST = h_intf.ARBURST;
		ARCHUNKEN = h_intf.ARCHUNCKEN;
		ARLOCK=h_intf.ARLOCK;


		unique_id_tracking_rd;
		read_poison_l8();
	//	$display($time,"---------------*in config class get read addr phase *********************-ARADDR=%d || ARID =%0d || ARLEN =%0d || ARSIZE =%0d || ARBURST =%0d",h_intf.ARADDR,ARID,		ARLEN,ARSIZE,ARBURST);
	    aligned_address=(ARADDR/(2**ARSIZE))*(2**ARSIZE);
		lower_boundary=$floor(ARADDR/((2**ARSIZE)*(ARLEN+1))) * ((2**ARSIZE)*(ARLEN+1));
		if(ARCHUNKEN)
		total_chunks=((2**ARSIZE)*(ARLEN+1)/16);
		else total_chunks=ARLEN;
		if(ARBURST==1)base_addr = aligned_address;
		else  base_addr=lower_boundary;

	
	    temp_s_addr = (ARADDR / (2 ** ARSIZE)); //=====address nature calculation
	    aligned_addr = temp_s_addr * (2 ** ARSIZE);

	    if (aligned_addr != ARADDR)
		begin//{
	    	unaligned = 1;
		end//} 
		else 
		begin//{
	        unaligned = 0;
	    end//}
		atomic_error=0;

	  end

	endtask

//===============================================================================//
//---------------------------executing read data phase--------------------------//
//===============================================================================//

    task automatic execute_read_data_phase();
    	int read_addr; // addr pointing to current read location
        int mem_row;
        int aligned_addr;
        int id;
		static int i,k=0;
		//-------------------------------------------------------------------------//
		//	RVALID=1;
     	base_addr_r = ARADDR;
        row_r = $floor((base_addr_r / (`MAX_AXI5_DATA_WIDTH / 8)));
        col_r = base_addr_r - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(base_addr_r / (`MAX_AXI5_DATA_WIDTH / 8)));

        /*if (base_addr_r >= 4096)
		begin 
			RRESP = 3;
		end*/

        if (h_intf.ARESETn) begin//{ //{

			RID = ARID;

        	if (((2 ** ARSIZE) > (`MAX_AXI5_DATA_WIDTH / 8) || (unaligned==1&&ARBURST==2 && AWATOP!=49))&& RRESP!=3) 
			begin//{ // {
            	RRESP = 2;
				RID = ARID;
				no_of_beats_rd=no_of_beats_rd+1;
				if(no_of_beats_rd==(ARLEN+1)) begin
					no_of_beats_rd=0;RLAST = 1;atomic_error=0;

				end
				else begin 
					RLAST=0;
          	  end

			end
            else 
			begin//{ // {
				if(ARCHUNKEN==1) begin//{
    					chunking_condition_check(k);
						k = k + 1;
				end//}
				
				else if (ARBURST == 1 && h_intf.ARESETn)
				begin//{ // {
                	read_data_INCR();
                end//} // } incr
				else if(ARBURST == 2 && h_intf.ARESETn)
				begin
					read_data_WRAP();
				end

            end//} // } :INCR, WRAP

        end//} //} :rst one
     endtask

	
	//====================INCR TASK FOR READ==========
	task read_data_INCR();
	    int read_addr; // addr pointing to current read location
	    int mem_row;
	    int aligned_addr;
	    int id;
	    int row, col;
		static	int i;
		row_r = $floor((base_addr_r / (`MAX_AXI5_DATA_WIDTH / 8)));
	    col_r = base_addr_r - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(base_addr_r / (`MAX_AXI5_DATA_WIDTH / 8)));
	 
	    memory_row = $floor((ARADDR / (`MAX_AXI5_DATA_WIDTH / 8)));  
	    aligned_addr = ($floor(ARADDR / (2 ** ARSIZE))) * (2 ** ARSIZE);

	    if(ARADDR >= 4096)
		begin//{ //{
	    	RRESP = 3;
			RID = ARID;
			RIDUNQ=ARIDUNQ; 
	        RDATA = 0;
	    end//} //}

	      if(!atomic_error) RRESP=0;
  
	    if ((2 ** ARSIZE) > (`MAX_AXI5_DATA_WIDTH / 8)&&(RRESP!=3)||atomic_error) begin

			RRESP = 2;
			RID = ARID;
		end
		else if(ARLOCK==1) begin RRESP=1;RID=ARID;end

		 if(RRESP == 0||RRESP==1) begin//{
	    	for(int j = 0; j < (`MAX_AXI5_DATA_WIDTH / 8); j = j + 1)
			begin//{ //{
	    		RDATA[(j * 8) +: 8] = memory[memory_row][j];
			//	$display($time," ===read phase=======memory = %D ======= row = %0d col = %d................. RDATA = %0d==addr=%d==arlock=%d ",memory[memory_row][j],memory_row,j,RDATA,ARADDR,ARLOCK);

	    	end//} //}

			RRESP = RRESP;
			RID = ARID; 
			RPOISON=read_poison_array[i];


		end//}
				
		no_of_beats_rd=no_of_beats_rd+1;
		if(no_of_beats_rd==(ARLEN+1)) begin
			no_of_beats_rd=0;RLAST = 1;atomic_error=0;

		end
		else begin 
			RLAST=0;
			
		end

	    ARADDR = aligned_addr + (2 ** (ARSIZE)); 
		i=i+1;
		//	$display($time,"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@",i);

	endtask



//-------------------------------------------------------------------------------------------------
  	task read_data_WRAP();
		 static int i;
   		 int read_addr; // addr pointing to current read location
   		 int mem_row;
   		 int aligned_addr;
   		 int id;
   		 int row, col;

   		 row_r = $floor((base_addr_r / (`MAX_AXI5_DATA_WIDTH / 8)));
   		 col_r = base_addr_r - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(base_addr_r / (`MAX_AXI5_DATA_WIDTH / 8)));
   		 //wait_on(AXI5_CLOCK_POSEDGE, 1); // wait_on task

		 memory_row = $floor((ARADDR / (`MAX_AXI5_DATA_WIDTH / 8)));  
	     aligned_addr = ($floor(ARADDR / (2 ** ARSIZE))) * (2 ** ARSIZE);

   		 lower_wrap_boundary = ($floor(base_addr_r / ((2 **  ARSIZE) * ( ARLEN + 1)))) * ((2 **  ARSIZE) * ( ARLEN + 1));
   		 upper_wrap_boundary = lower_wrap_boundary + ((2 **  ARSIZE) * ( ARLEN + 1));
   		 if (ARADDR >= 4096) 
   		 begin 
   		 	RRESP = 3;
			RID = ARID;
   		 end
		else if(ARLOCK==1) RRESP=1;

		if(!atomic_error&&!ARLOCK) RRESP=0;

   		if ((((2 ** ARSIZE) > (`MAX_AXI5_DATA_WIDTH / 8))&&(RRESP!=3)) ||  ((unaligned == 1 &&AWATOP != 49)&&(RRESP!=3)) || ((($countones(ARLEN + 1) != 1) || ((ARLEN) > 16)/*||(AWLEN==0&&AWATOP!=49)*/)&&RRESP!=3)||(atomic_error==1)) 

   		  begin//{
   		 	RRESP = 2;
			RID = ARID;
			//	$display($time,"^^^^^^^^^^^^^^^^^^from config class ==============resp=%d===beats=%d==atomic_error",RRESP,no_of_beats_rd,AWLEN);
   		 end	
   		 if(RRESP == 0||RRESP==1)
   		  begin//{
   		    for (int j = 0; j < (`MAX_AXI5_DATA_WIDTH / 8); j = j + 1) begin//{
   		   		RDATA[(j * 8) +: 8] = memory[memory_row][j];
			//	$display($time," ===read phase=======memory = %D ======= row = %0d col = %d................. RDATA = %d ",memory[memory_row][j],memory_row,j			,RDATA);
   		 	end//}
			RRESP = RRESP;
			RID = ARID;
			RPOISON=read_poison_array[i];
   		 end//}
		no_of_beats_rd=no_of_beats_rd+1;
		if(no_of_beats_rd==(ARLEN+1)) begin
			no_of_beats_rd=0;RLAST = 1;atomic_error=0;
		end
		else begin 
			RLAST=0;
		end
	//	$display($time,"====================from config cls==============================rlast=%d==no_of_beats_rd=%d",RLAST,no_of_beats_rd);
			
	    ARADDR = aligned_addr + (2 ** (ARSIZE)); 
			if(ARADDR==upper_wrap_boundary) ARADDR=lower_wrap_boundary;
		//i=i+1;

		
	endtask

//==============================================logic to store rdata============================================================================//

function void wdata_atomic_compare();
		bit[31:0]c_addr;

		if(AWLEN==0)								//------- when len is 0 ---//
		begin:len_0
			if(AWADDR*8 > `MAX_AXI5_DATA_WIDTH) begin	//----- start index for storing compare data when index is > data bus width-----//
				c_addr=AWADDR*8 -`MAX_AXI5_DATA_WIDTH;
			end
			else 										//----- start index for storing compare data when index is < data bus width-----//
				c_addr=AWADDR*8;				
			case(AWSIZE) //--------- based on size assigning data present in the memory on WDATA -----------//
				1:WDATA[0]=RDATA_store[0];	
				2:WDATA[0]=RDATA_store[0];	
				3:WDATA[0]=RDATA_store[0];	
				4:WDATA[0]=RDATA_store[0];	
				5:WDATA[0]=RDATA_store[0];
			endcase	
		//	$display($time,"~~~~~~~~~~~~~~~~~in config~~~~~~~~~~~~~~~~~~~~~~~WSTRB=%b==awatop=%d==wdata=%d",WSTRB,AWATOP,WDATA_S);					

		end:len_0

		else 								//------ when len>0 ---//
		begin:len_n_0
//----------------- assigning comapre data(read from memory) into wdata at respected locations when burst is incr ----------------------//
			if(AWBURST==AXI_INCR)
			begin
				for(int i=0;i<(AWLEN+1)/2;i++)
				begin
					//WDATA[i][i+:8]=RDATA_store[i][i+:8];//-------for half of data is same as memory---------//
					WDATA[i]=RDATA_store[i];
//	$display($time,"=11@@@from config cls@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@wdata=%d==WDATA[i]==%d",i,WDATA[i]);
					
				end
				for(int i=(AWLEN+1)/2;i<(AWLEN+1);i++)
				begin
					WDATA[i]=$random;
//	$display($time,"=22@@@from config cls@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@wdata=%d==WDATA[i]==%d",i,WDATA[i]);
									
				end




			end
//----------------- assigning comapre data(read from memory) into wdata at respected locations when burst is wrap----------------------//
			else if(AWBURST==AXI_WRAP)
			begin
				
				for(int i=(AWLEN+1)/2;i<(AWLEN+1);i++)
				begin
					WDATA[i]=RDATA_store[i-((AWLEN+1)/2)];
//	$display($time,"=@@@from config cls@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@wdata=%d==WDATA[i]==%d",i,WDATA[i]);
									
				end
				for(int i=0;i<(AWLEN+1)/2;i++)begin
						WDATA[i]=$random+2;
//	$display($time,"11= from config class @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@wdata=%d==WDATA[i]==%d",i,WDATA[i]);

				end
			end
		end:len_n_0	
//	$display($time,"=@@@@@@from config class @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@wdata=%p==",WDATA);

	endfunction





//=========================================================================================================================//



//-----------------------------------------------------------------------------------------------------------------------------//
//================================================poison logic started=========================================================//
//-----------------------------------------------------------------------------------------------------------------------------//

//=======================================task to send the poison bit to a task for storing the poison======================//

task poison_check();
		for(int i=0;i<$bits(WPOISON);i++)begin//{
		for(int j=(i*8);j<((i*8)+8);j++)begin//{
			if(WSTRB[j]==1)begin//{
				if(WPOISON[i]) begin granule_poison = 1'b1;	end
				else granule_poison = 1'b0;
					
				write_poison_l8(granule_poison);
						
					poison_bytes=0;
					granule_poison=0;					
					poison_addr_l8= poison_addr_l8+1;
		
			end//}
		end//}
		end//}
	//	$display($time,"!!!!!!!!!!!!!!!!!!!!posion array=%p",poison_array);
	endtask

//===================================task to store the poison to the poison array ========================//

	task automatic write_poison_l8(bit poison_or_unpoison);
		bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] upper_wrap_boundary_p,lower_wrap_boundary_p;//---for calculating lower,upper boundaries

		lower_wrap_boundary_p = ($floor(AWADDR / ((2 ** AWSIZE) * (AWLEN + 1)))) * ((2 ** AWSIZE) * (AWLEN + 1));
    	upper_wrap_boundary_p = lower_wrap_boundary_p + ((2 ** AWSIZE) * (AWLEN + 1));

		if(AWBURST==2 &&(poison_addr_l8==upper_wrap_boundary_p)) begin poison_addr_l8=lower_wrap_boundary_p;
		end
		if(poison_or_unpoison==1) begin
			poison_array[poison_addr_l8/8][poison_addr_l8%8]=1;
		end
		else begin
			poison_array[poison_addr_l8/8][poison_addr_l8%8]=0;
	//	$display($time,"*************************************in slave poison_array = %b=====poison_addr_l8=%d",poison_array[poison_addr_l8/8],poison_addr_l8);
			
		end	
	
	endtask


//======================================task for geting poison for every beat from poison array for read transaction===========//	

	task automatic read_poison_l8();

		bit [`MAX_AXI5_ADDRESS_WIDTH-1:0] read_addr;
		bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] upper_wrap_boundary_p,lower_wrap_boundary_p;//---for calculating lower,upper boundaries
		
		int j,temp_size,aligned_addr,dbw_aligned_addr,valid;
		 lower_wrap_boundary_p = ($floor(ARADDR / ((2 ** ARSIZE) * (ARLEN + 1)))) * ((2 ** ARSIZE) * (ARLEN + 1));
   		 upper_wrap_boundary_p = lower_wrap_boundary_p + ((2 ** ARSIZE) * (ARLEN + 1));

			read_poison_array=new[ARLEN+1];
			read_addr=ARADDR;
			aligned_addr= ($floor(read_addr / (2**ARSIZE))*(2**ARSIZE));
			dbw_aligned_addr = ($floor(read_addr / (`MAX_AXI5_DATA_WIDTH/8))*(`MAX_AXI5_DATA_WIDTH/8));

			if(ARCHUNKEN&&ARBURST==2) read_addr=lower_wrap_boundary_p;
			else if(ARADDR != aligned_addr && dbw_aligned_addr != ARADDR)
			begin//{
				read_addr = ARADDR;	temp_size=(ARADDR-aligned_addr);
			end//}
			else if(ARADDR != aligned_addr) 
				read_addr = aligned_addr;	
			for(int i=0;i<(ARLEN+1);i++)
				begin//{
					for(int k =0;k < `MAX_AXI5_DATA_WIDTH/8;k++)	
						begin//{
							if(dbw_aligned_addr >= read_addr)
								begin//{
								if(temp_size != 2**ARSIZE)
								begin//{
								temp_size++;
								end//}
				    			else break;
								read_poison_array[i][j/8]=((poison_array[(read_addr)/8])/255);
		aligned_address=(ARADDR/(2**ARSIZE))*(2**ARSIZE);
		lower_boundary=$floor(ARADDR/((2**ARSIZE)*(ARLEN+1))) * ((2**ARSIZE)*(ARLEN+1));
	//	total_chunks=((2**ARSIZE)*(ARLEN+1)/16);
		if(ARCHUNKEN)
		total_chunks=((2**ARSIZE)*(ARLEN+1)/16);
		else total_chunks=ARLEN;

		if(ARBURST==1)base_addr = aligned_address;
		else  base_addr=lower_boundary;

							j = j + 1;
								read_addr++;
								dbw_aligned_addr++;
								if(j == `MAX_AXI5_DATA_WIDTH/8) j = 'd0;
							end//}
							else
							begin//{
								dbw_aligned_addr++;j = j + 1'b1;
							end//}
			
				end//}
				if(!ARCHUNKEN&&ARBURST==2 &&(read_addr==upper_wrap_boundary_p))  read_addr=lower_wrap_boundary_p;
				temp_size=0;
				end//}
			dbw_aligned_addr = 0;read_addr=0;j=0;
	endtask
//-----------------------------------------------------------------------------------------------------------------------------//
//================================================poison logic ended=========================================================//
//-----------------------------------------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------------------------------------//
//========================================================atomic transactions logic started===================================//
//----------------------------------------------------------------------------------------------------------------------------//

//==========================function which will return the result  for store load swap operations and wdata if its not a atomic operation
 function bit[7:0] atomic_transaction(bit[7:0] inbound_data, outbound_data);

    bit[7:0] modified_value;
    bit[7:0] sum;

    if (AWATOP == 'd0 || AWATOP[5:4] == 2'b11) begin//{
      modified_value = outbound_data;
    end//}

    else if (AWATOP[5:4] == 2'b01 || AWATOP[5:4] == 2'b10) begin//{  //{

      case (AWATOP[2:0])

        0: begin//{  //---add
          modified_value = inbound_data + outbound_data;
	//	$display($time,"========inbound_data=%d==outbound_data=%d==modified_value=%d==row=%0d",inbound_data,outbound_data,modified_value,row);
        end//}

        1: begin//{  // CLR OPERATION
          
            modified_value = inbound_data & (~outbound_data);  
        end//}

        2: begin//{  // E-OR OPERATION
           modified_value = inbound_data ^ outbound_data;
        end//}

        3: begin//{  // SET OPERATION
          
            modified_value = inbound_data | outbound_data;  
        end//}

        4: begin//{  // SMAX
          if ($signed(inbound_data) > $signed(outbound_data)) 
            modified_value = inbound_data;
          else 
            modified_value = outbound_data;
        end//}

        5: begin//{  // SMIN
          if ($signed(inbound_data) < $signed(outbound_data)) 
            modified_value = inbound_data;
          else 
            modified_value = outbound_data;
        end//}



        6: begin//{  // UMAX
          if (inbound_data > outbound_data) 
            modified_value = inbound_data;
          else 
            modified_value = outbound_data;
        end//}

        7: begin//{  // UMIN
          if (inbound_data < outbound_data) 
            modified_value = inbound_data;
          else 
            modified_value = outbound_data;
        end//}

      endcase
		$display($time,"========inbound_data=%d==outbound_data=%d==modified_value=%d==row=%0d",inbound_data,outbound_data,modified_value,row);

    end//}  //}


    return modified_value;

  endfunction


//===========================================================function to convert littleendian values to big endian values 

 function void little_endian_2_big_endian();

    bit [`MAX_AXI5_ADDRESS_WIDTH-1:0] start_addr_beat; 							// to store start address of the respective beat

    int row, col;

    start_addr_beat = base_addr_w;

    row = $floor((start_addr_beat / (`MAX_AXI5_DATA_WIDTH / 8)));
    col = start_addr_beat - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(start_addr_beat / (`MAX_AXI5_DATA_WIDTH / 8)));
    for (int i = 0; i < ((2 ** AWSIZE)*(AWLEN+1)); i++) begin//{
	
      memory[row][col] = big_endian_queue.pop_back();
      col++;
	  if(col == (`MAX_AXI5_DATA_WIDTH / 8)) begin//{ 
      row = row + 1;
      col = 0;
      end//} 

    end//}

  endfunction




//---------------------------based on beats the corresponding values will be stored into comp_q and store_q-------------------------------------------//
  task atomic_compare_INCR(int beat, int byte_lane);
    int counter;
    if(AWLEN == 0) begin//{ //{

      if(count < ((2 ** AWSIZE) / 2)) begin//{
        comp_q.push_back(WDATA_S[(byte_lane * 8) +: 8]);
      end//}
      else begin//{
        store_q.push_back(WDATA_S[(byte_lane * 8) +: 8]);
		poison_atomic_comp_q.push_back(WPOISON[byte_lane/8]);		
      end//}
      count++; 
		//$display($time,"!!!!!!!!!!!!!!!!!!!-------------------- inside the slave comp_poision_q=%p",poison_atomic_comp_q);
		
                                       
    end//} //}

    else begin//{ //{

      if(byte_lane == 0) begin//{ //{//---for calling one time in every beat 

        if(beat < (AWLEN + 1) / 2) begin//{ //{
          comp_q.push_back(WDATA_S);
        end//} //}
        
        else begin//{ //{
          for(int s = 0; s < (`MAX_AXI5_DATA_WIDTH / 8); s++) begin
            store_q.push_back(WDATA_S[s * 8 +: 8]);
	    	poison_atomic_comp_q.push_back(WPOISON[s/8]);
		  end
	//	$display($time,"!!!!!!!!!!!!!!!!!!!----------------len>0---- inside the slave comp_poision_q=%p",poison_atomic_comp_q);
			
        end//} //}

      end//} //}
    end//} //}
	$display($time,"!!!!!!!!!!in atomic incr compa!!!!!comp_q=%p,store_q=%p====beat=%d",comp_q,store_q,beat);

  endtask



  task at_compare_task;

    if(AWLEN == 0) 
	begin//{//{
      for(int m = 0; m < comp_q.size(); m++) 
	  begin//{ //{
        if(memory[row][col] == comp_q[m]) 
		begin//{ //{
      //  $display($time,"@@@@@@@@@@@memory[row][col]=%d==========comp_q[m]=%d",memory[row][col],comp_q[m]);
         	 memory[row][col] = store_q.pop_front();
			 granule_poison = poison_atomic_comp_q.pop_front();
		//	$display($time,"****************poison_atomic_comp_q=%p",poison_atomic_comp_q);
			write_poison_l8(granule_poison);
			granule_poison=0;					
			poison_addr_l8=poison_addr_l8+1;

        end//} //}
        
        else begin//{ //{
			poison_atomic_comp_q.pop_front();
         	 store_q.pop_front();
			poison_addr_l8=poison_addr_l8+1;
          
        end//} //}  
		col++;
        if(col == (`MAX_AXI5_DATA_WIDTH / 8)) begin//{ //{
          row = row + 1;
          col = 0;
          ind++;
        end//} //}

      end//} //}

    end//} //}

    else begin//{ //{

      for(int s = 0; s < `MAX_AXI5_DATA_WIDTH / 8; s++) begin//{ //{
	//	$display($time,"in if at_compare task ================== memory[row][col]=%d====comp=%d==ind=%d", memory[row][col],comp_q[ind][s*8+:8],ind);

        if(memory[row][col] == comp_q[ind][s*8+:8]) begin//{ //{
			granule_poison = poison_atomic_comp_q.pop_front();
			//	$display($time,"****************poison_atomic_comp_q=%p",poison_atomic_comp_q);
				write_poison_l8(granule_poison);
				granule_poison=0;					
				poison_addr_l8=poison_addr_l8+1;
          memory[row][col] = store_q.pop_front();

        end//} //}

        else begin//{ //{
          store_q.pop_front();
           poison_atomic_comp_q.pop_front();

		poison_addr_l8=poison_addr_l8+1;
			
	//	$display($time,"in else  at_compare task ==================poison_addr_l8=%d",poison_addr_l8);
        end//} //}
	
        col++;                        

        if(col == (`MAX_AXI5_DATA_WIDTH / 8)) begin//{ //{

          row = row + 1;
          col = 0;
          ind++;
	//	$display($time,"in if at_compare task ================== memory[row][col]=%d====comp=%d==ind=%d==col=%d", memory[row][col],comp_q[ind][s*8+:8],ind,col);

        end//} //}

        AWADDR++;

        if(AWADDR == upper_wrap_boundary) begin//{ //l{
          AWADDR = lower_wrap_boundary;
          row = $floor((AWADDR / (`MAX_AXI5_DATA_WIDTH / 8)));
          col =( AWADDR - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor((AWADDR / (`MAX_AXI5_DATA_WIDTH / 8)))));
        end//} //}

      end//} //}

    end//} //}

  endtask


 //-----------------------------------------------------------------------------------------------------//

  task atomic_compare_WRAP( int beat, int byte_lane);

    if(AWLEN == 0) begin//{ //{

      if(count < ((2 ** AWSIZE) / 2)) begin//{
        store_q.push_back(WDATA_S[(byte_lane * 8) +: 8]);
		poison_atomic_comp_q.push_back(WPOISON[byte_lane/8]);
				

      end//}
      else begin//{
        comp_q.push_back(WDATA_S[(byte_lane * 8) +: 8]);
      end//}
      count++;                                        
//$display($time,"88888888888888888888 poison_atomic_comp_q = %0p",poison_atomic_comp_q);
    end//} //}

    else begin//{ //{

      if(byte_lane == 0) begin//{ //{
        if(beat < (AWLEN + 1) / 2) begin//{ //{
          for(int s = 0; s < (`MAX_AXI5_DATA_WIDTH / 8); s++) begin//{ //{
            store_q.push_back(WDATA_S[s * 8 +: 8]);
	    	poison_atomic_comp_q.push_back(WPOISON[s/8]);
	//	$display($time,"!!!!!!!!!!!!!!!!!!!----------------len>0---- inside the slave comp_poision_q=%p",poison_atomic_comp_q);

			
          end//} //}
        end//} //}

        else begin//{ //{
          comp_q.push_back(WDATA_S);
        end//} //}

      end//} //}
    end//} //}
//	$display($time,"!!!!!!!!!!!!!!!comp_q=%p,store_q=%p====beat=%d",comp_q,store_q,beat);
  endtask

//------------------- for checking all attributesrequired for atomic operations --------------------//
	function automatic atomic_configuration_check();

		int total_size;//=========to store no:of bytes in one transaction
		bit unaligned_compare;//=====bit to indicate weather addr is aligned to total/half write data size
		total_size=((AWLEN+1) *(2**AWSIZE));//====no:of beats*no:of bytes				
		if(AWATOP==49) 
		begin   //-----for atomic compare checking given address is allined to total size or half of size--//
			if((2**AWSIZE)*(AWLEN+1)>32||total_size==1) begin   atomic_error=1; end

			if((($floor(AWADDR/total_size))*total_size)!=AWADDR &&AWBURST==1)
			begin
				unaligned_compare=1;  //--if addr isn't aligned to total data size or half of size
			end		
			if(((($floor(AWADDR/(total_size/2)))*(total_size/2))!=AWADDR)&&AWBURST==2)unaligned_compare=1; 				
			if(((AWLEN+1)==1 ||total_size>32 )&& $countones(total_size)!=1 ) atomic_error=1;//total size should be 2,4,8,16,32 
	
			else if(AWLEN >0) 
			begin		
				if(unaligned_compare) atomic_error=1;				
				else if((2**AWSIZE)!=(`MAX_AXI5_DATA_WIDTH/8)) atomic_error=1;//when AWLEN>0 the AWSIZE should be equal to WDATA width
			end
			else if(AWLEN==0) 
			begin //----for INCR type when awlen=0 the addr should be aligned to total/half wdata size
				if(unaligned_compare || (2**AWSIZE) > (`MAX_AXI5_DATA_WIDTH/8)) atomic_error=1;
			end	

		end
		else 
		begin   //-----atomic store,load,swap
			if((2**AWSIZE)*(AWLEN+1)>8) begin   atomic_error=1; end
			
			if((($floor(AWADDR/total_size))*total_size)!=AWADDR)
        		unaligned_compare=1;  //--if addr isn't aligned to total data size
			if(AWBURST==2  || unaligned ||unaligned_compare ) atomic_error=1;
			else if(total_size>8 || $countones(total_size)!=1) atomic_error=1;
			else if(AWLEN>0) 
			begin
				if((2**AWSIZE) != (`MAX_AXI5_DATA_WIDTH/8)) atomic_error=1;//when AWLEN>0 the AWSIZE should be equal to WDATA width
			end
		end
		if(atomic_error) begin BRESP=2; BIDUNQ=AWIDUNQ; //RRESP=2;
		
		end
			
	endfunction


//=====================================================================================================================================/
//------------------------------------------------ unique id --------------------------------------------------------------------------
//======================================================================================================================================/

  task unique_id_tracking();
      for(int i=0;i<unq_id_q.size();i++)
	  begin//{
		if(AWID==unq_id_q[i].AWID) 
		begin//{
			if(AWIDUNQ==0 && unq_id_q[i].AWIDUNQ==0) 	
			begin//{
				AWREADY=1; 
				break;
			end//}
			else 
			begin//{
				AWREADY=0; 
				unique_id_error_w=1; 
             	break;
			end//}	
		end//}
		end//}
//		$display($time,"==================== unq_id_q = %p",unq_id_q);
  endtask


//------------------------------------------------------------------//

	task unique_id_tracking_rd();

      for(int i=0;i<unq_id_q_rd.size();i++) begin//{
		if(ARID==unq_id_q_rd[i].ARID) begin//{
			if(ARIDUNQ==0 && unq_id_q_rd[i].ARIDUNQ==0) begin//{

			 break;
			end//}

			else begin//{
				 unique_id_error_r=1; ARREADY=0;

                break;
			end//}
			
		end//}

		end//}


		//$display($time," ======================== unique");
    endtask



//========================================= read data chuncking==========================
	task  chunking_condition_check(int k);
	
		bit aligned_16B;

//			$display($time,"333333333333333333333333333333333333333333333333333333333333333");
		if( ARADDR == ((ARADDR/16) *16)) aligned_16B=1;
	
	
//			$display($time,"3344444444444444444444444444333333333333333333333333333333333333333333333aligned_16B  =%b",aligned_16B); 
    //	if(ARSIZE >3  && (ARLEN>0 && ((2**(ARSIZE))==(`MAX_AXI5_DATA_WIDTH/8))) && (aligned_16B && ARBURST >0) &&(unaligned ==0&& ARBURST==2) && ($countones(ARLEN + 1) == 1 && ARLEN <= 16&& ARBURST==2) ) begin		
		if(ARSIZE >3  && ((ARLEN>0 && ((2**(ARSIZE))==(`MAX_AXI5_DATA_WIDTH/8)))||ARLEN==0) && (aligned_16B && ARBURST >0) ) begin//{
			if(ARBURST==2&&((unaligned ==1) || ($countones(ARLEN + 1) != 1 && ARLEN > 16) || (ARLEN == 0))) begin
					$error("FROM_SLAVE:====FROM SLAVE WRAP BURST ERROR CONDITION==================");	
			end
						
			else begin 
				Read_data_chunking(k);
			end
		end//}

		 else begin
			if (ARBURST == 1) begin
                read_data_INCR(); //rchunkv=0
            end

             else if (ARBURST == 2) begin
                read_data_WRAP();
             end
		 end

	endtask

	task Read_data_chunking(int k);
		
	//	$display($time,"11111111111111111111111111111111111111111111111");
		if(k == 0) chunk_load();
		run_till_last_chunk();
		

	 endtask


	 task chunk_load();
		int row,col;
		bit [127:0] temp_store;
	    	row = $floor((base_addr/ (`MAX_AXI5_DATA_WIDTH / 8)));
	    col = base_addr - (`MAX_AXI5_DATA_WIDTH / 8) * ($floor(base_addr / (`MAX_AXI5_DATA_WIDTH / 8)));

		 for(int i=0; i<=ARLEN; i++) begin//{			
			for(int j=0; j<((2**ARSIZE)/16);j++) begin//{
				for(int k=0; k<16;k++) begin//{
					temp_store[(k*8)+:8]=memory[row][col];
				 	col = col + 1;
				    base_addr++;	
				//	$display($time," temp_store  == %d row = %d col = %d base_addr = %0d",temp_store,row,col,base_addr);
    				if(col == (`MAX_AXI5_DATA_WIDTH / 8)) begin//{	 
    					row = row + 1;col=0;
					end//}
      		  	end//}		
				queue_128_chunk[i][j].RDATA=temp_store;
				queue_128_chunk[i][j].RCHUNKNUM=i;
				queue_128_chunk[i][j].RPOISON=read_poison_array[i][(j*2)+:2];
				if(j==0)temp_rstrb=1;
				else	temp_rstrb=temp_rstrb<<1;

				queue_128_chunk[i][j].RCHUNKSTRB=temp_rstrb;
			//	$display($time,"=======i = %d j =-  %d========== queue_128_chunk = %p",i,j,queue_128_chunk);

			end//}

			
		end//}

		if(unaligned==1) begin//{
			aligned_address=(ARADDR/(2**ARSIZE))*(2**ARSIZE);
			d_element=(ARADDR-aligned_address)/16;
			for(int h=0; h<d_element; h++) begin//{

				queue_128_chunk[0].delete(0);
				total_chunks--;

			end//}

		end//}


	endtask


	

	 task  run_till_last_chunk();

		int id,aligned_addr;
		
		
		//for(int k=0; k<total_chunks;k++) begin//{

		
      	if(!h_intf.ARESETn || terminate_transaction) begin//{ //{
        RVALID = 0;

		RPOISON=0;
        RRESP = 0;
        RID = 0;
        RLAST = 0;
        RDATA = 0;
		RCHUNKV=0;
		RCHUNKSTRB=0;
		RCHUNKNUM=0;

        //break;        
      end//} //}

      else begin//{ 


        memory_row = $floor((ARADDR / (`MAX_AXI5_DATA_WIDTH / 8)));  
        aligned_addr = ($floor(ARADDR / (2 ** ARSIZE))) * (2 ** ARSIZE);

        if((ARADDR+(2**ARSIZE)) >= 4096) begin//{ 
          RRESP = 3; 
          RDATA = 0; 
		  RID = ARID;


        end//} 
        
        else begin//{


		chunk_selection();
		data_placing_on_RDATA_bus();
		queue_size_zero();
		
		if(queue_128_chunk.size()==0) begin  
			if(ARIDUNQ)begin unq_id_q_rd.delete(0);end 
		end
		else RLAST=0;
	
		end//}
		end//}

	//end//}


	 endtask
	

//----random_pop=0 i.e pop_front  else pop_back
	task chunk_selection( );

		random_chunknum 	= $urandom_range(0,(queue_128_chunk.size-1));
		random_nof_chunk	= $urandom_range(1,queue_128_chunk[random_chunknum].size);
		chunk_num=random_nof_chunk+chunk_num;//============== to determine RLAST condition
		random_pop			= $urandom_range(0,1);
	//	$display($time,"====== random_chunknum = %d random_nof_chunk = %d chunk_num = %d random_pop = %d  queue_128_chunk = %d",random_chunknum,random_nof_chunk,chunk_num,random_pop,queue_128_chunk.size                           );
		if(random_pop==0)begin//{
			for(int z=0;z<random_nof_chunk;z++)begin//{
				temp_chunk=queue_128_chunk[random_chunknum].pop_front();
				temp_chunk_q.push_back(temp_chunk);
			end//}
		end//}

		else begin//{
			for(int z=0;z<random_nof_chunk;z++)begin//{
				temp_chunk=queue_128_chunk[random_chunknum].pop_back();
				temp_chunk_q.push_front(temp_chunk);
			end//}
		end//}
	//	$display($time,"queue  popping = %p",queue_128_chunk);


	endtask

	task queue_size_zero( );

		for(int i=0; i<queue_128_chunk.size();i++) begin//{
		if(queue_128_chunk[i].size()==0) begin//{
			queue_128_chunk.delete(i);
		end//}

	  end//}

	//	$display($time,"22222999999999999999999999999999999999999999999999999999999999");
	endtask

	

	
	 task data_placing_on_RDATA_bus( );

	 	bit [(4096/(`MAX_AXI5_DATA_WIDTH/8))-1:0] temp_RCHUNKNUM;
	 	bit [(`MAX_AXI5_DATA_WIDTH)-1:0] temp_RDATA;
	 	bit [(`MAX_AXI5_DATA_WIDTH/128)-1:0] temp_RCHUNKSTRB;
	 	bit [(`MAX_AXI5_DATA_WIDTH/64)-1:0] temp_RPOISON;
		

		for(int k=0; k<temp_chunk_q.size(); k++) begin//{

		temp_RCHUNKSTRB=(temp_chunk_q[k].RCHUNKSTRB|temp_RCHUNKSTRB);
		
		end//}

	 	for(int i=0; i<(`MAX_AXI5_DATA_WIDTH/128) ; i++) begin//{
		


			if(temp_RCHUNKSTRB[i]==1) begin//{
				
				temp_RDATA[(i*128)+:128]=temp_chunk_q[0].RDATA;
				temp_RCHUNKNUM=temp_chunk_q[0].RCHUNKNUM;
				temp_RPOISON[(i*2)+:2]=temp_chunk_q[0].RPOISON;
				temp_chunk_q.delete(0);

			end//}: trb checking


			 


	 end//} : no of chunks loop
	 RVALID=1;
	// RPOISON=read_poison_array[i];//------assiging rpoison value
	 RCHUNKV=1;

//	$display($time,"*************************************");
	 RRESP=0;
	 //RID=que_arid[0];
	 RID=ARID;
	 if(ARIDUNQ)begin unq_id_q_rd.delete(0);end
 	 RDATA=temp_RDATA;
	 RCHUNKNUM=temp_RCHUNKNUM;
     RCHUNKSTRB=temp_RCHUNKSTRB;
	 RPOISON=temp_RPOISON;
	 if(total_chunks==chunk_num) begin RLAST=1; end
	 else RLAST=0;	
	// wait((RREADY&&AWAKEUP)||!h_intf.ARESETn);
	// RVALID=0;RPOISON=0; temp_RPOISON=0;RLAST=0; RCHUNKV=0;
	 
//	 if(total_chunks==chunk_num) begin r_data_channel_indicator=0;  end
	 temp_RCHUNKSTRB=0;
	 temp_RDATA=0;


		//$display($time,"========2222222222222=============== RCHUNKNUM = %d",RCHUNKNUM);

	 endtask


//------------------------------------------------------------------------------------------------------------------------------------------------//
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< EXCLUSIVE ACEESS LOGIC >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> //
//------------------------------------------------------------------------------------------------------------------------------------------------//
 //-----------------Performing Exclusive Read Operation-------------------      
	task  automatic execute_exclusive_read_transaction();
//		static axi5_transaction exclusive_que[$];	//----for outstanding transactions to data stability
//-------- checking all conditions of exclusive access i.e len <= 16 beats, address alligned to total no of bytes , total no of bytes must be power of 2 --------------------- total bytes =size* length--------------------------------------------//

			ARADDR_t=ARADDR;
			ARID_t=ARID;
			ARLEN_t=ARLEN;
			ARBURST_t=ARBURST;
			ARSIZE_t=ARSIZE;

		
		if(ARLEN<=15 &&(( (ARLEN+1)*(2**ARSIZE))<=128) &&(base_addr_r == ((base_addr_r/((ARLEN+1)*(2**ARSIZE)))*	
								((ARLEN+1)*(2**ARSIZE))))&& ($countones((2**ARSIZE ) * (ARLEN+1))==1))
		begin	
			//-----Temporary storage due to values are updating in class----//
			ARADDR_t=ARADDR;
			ARID_t=ARID;
			ARLEN_t=ARLEN;
			ARBURST_t=ARBURST;
			ARSIZE_t=ARSIZE;
			//exclusive_que.push_back();
	//		for(int j=0;j<(ARLEN + 1'b1);j++) begin
		//	$display($time,"$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ j=%d==ARLEN=%d",j,ARLEN);

		//	execute_read_data_phase();
			//trans=exclusive_que.pop_front;			
			if(RRESP==1) 
			begin			
				store_attribute[ARID_t]= '{pass_fail:0,addr:base_addr_r,len:ARLEN_t,size:ARSIZE_t,burst:ARBURST_t};//storing all values for compraing at ex_write operation/
				$display($time,"FROM_SLAVE: Exclusive_Operation --> stored atributes in read:%p",store_attribute);
			end		
		//	end	
		end
		else 
		begin
			$fatal($time,"FROM_SLAVE:\t<<<<<<<<<<< exclusive operation is failed beacause of wrong configuration >>>>>>>>>>>>>  \t\n");
		end

		if(h_intf.ARESETn==0)
		begin
			store_attribute.delete(); //---------- when reset apply deleting whole monitoring id's from associative array--------//
		end
	endtask
//--------------Performing Exclusive Write Operation--------------------//
	task automatic get_exclusive_write_transaction();
		//static axi5_transaction exclusive_que_w[$];//----for outstanding transactions to data stability	
		static bit done_transaction;//-------for controling outstanding transactions
		//exclusive_que_w.push_back(trans);

/*		if(done_transaction==1)	
			wait(done_transaction==0);
		else done_transaction=1;*/

		//trans=exclusive_que_w.pop_front();


	if(AWLOCK==1) 
		begin

//$display($time," (((((((((((((((((((((((((((((( in config class get_exclusive_write_transaction pass_fail  store_attribute[%d].pass_fail = %d -------------- %p --------- ex_wr_without_ex_rd_or_diff_sgl  %d \n\n\n\n\n\n",AWID , store_attribute[AWID].pass_fail,store_attribute,ex_wr_without_ex_rd_or_diff_sgl);
			if((store_attribute[AWID].pass_fail==0)&&(ex_wr_without_ex_rd_or_diff_sgl==0))
			begin
	
				if(BRESP==0) begin BRESP=1;BID=AWID;BIDUNQ=AWIDUNQ;end
				else begin BRESP=BRESP; BID=AWID;BIDUNQ=AWIDUNQ;end
//$display($time," ((((((((((((((((((((  pass fail  if   case  (((((((((( in config class get_exclusive_write_transaction pass_fail  store_attribute[%d].pass_fail = %d -------------- %p  ============ resp  %d \n\n\n\n\n\n",AWID , store_attribute[AWID].pass_fail,store_attribute,BRESP);

			end
		end



		if(store_attribute.exists(AWID)) 
		begin
//$display($time,"=========in iff ====== in config class get_exclusive_write_transaction task  **********  AWID %d  AWADDR  %d ------ store_attribute  %p",AWID,AWADDR,store_attribute);

			if((store_attribute[AWID].addr==base_addr_w) && (store_attribute[AWID].len==AWLEN) && (store_attribute[AWID].size==AWSIZE)&&(store_attribute[AWID].burst==AWBURST))
			begin		//----------
			//	for(int i=0;i<=AWLEN;i++)
			//	get_write_data_phase();
				//execute_write_response_phase(trans);
//$display($time," $$$$$$$$$$$$$$$$$$$$$$$$$  in  compare iff in config class get_exclusive_write_transaction  $$$$$$$$$$$$$$$$$$$$$$$$ \n\n\n\n");

				if(store_attribute[AWID].pass_fail==0) begin //----Checking if respective ID is Written without any error...
					$display($time,"FROM_SLAVE:exclsive Access is done succefully with ID:%0d with ADDR: %0D :%p\n\n",AWID,base_addr_w,store_attribute);
				end
				else 
					$error($time,"FROM_SLAVE:exclsive Access is not done succefully with ID due to memory updated :%0d  :%p\n\n",AWID,store_attribute);
				store_attribute.delete(AWID);//-------deleting ID only when ex_write is passed
			end
			else 
			begin	

				ex_wr_without_ex_rd_or_diff_sgl =1;	
			//	for(int i=0;i<=AWLEN;i++)
				//get_write_data_phase();
				store_attribute[AWID].pass_fail=1;//------ asserting signal for ex_write attributes are not matched with ex_rd for failing that//
				//execute_write_response_phase(trans);	
				$error($time,"FROM_SLAVE: Execlusive operation failed due to mismatch in attributes \n Monitoring attributes with ID:%0d:%p ---> 
							   Given:addr:%0d,size:%0d,length:%0d\n ",AWID,store_attribute[AWID],base_addr_w,AWSIZE,AWLEN);
				if((store_attribute[AWID].pass_fail==0) &&(ex_wr_without_ex_rd_or_diff_sgl==0))
				begin
	
					if(BRESP==0) begin BRESP=1;BID=AWID;BIDUNQ=AWIDUNQ;end
					else begin BRESP=BRESP; BID=AWID;BIDUNQ=AWIDUNQ;end

				end
				else begin
					if(BRESP ==1) begin BRESP =0;BID=AWID;BIDUNQ=AWIDUNQ;end
					else begin BRESP=BRESP; BID=AWID;BIDUNQ=AWIDUNQ;end
					if(ex_wr_without_ex_rd_or_diff_sgl==1) ex_wr_without_ex_rd_or_diff_sgl=0;
				end


				store_attribute[AWID].pass_fail=0;//------ deasserting signal due to sequence was not completed--//
			end
		end
		else 
		begin

			ex_wr_without_ex_rd_or_diff_sgl =1;

				if((store_attribute[AWID].pass_fail==0) &&(ex_wr_without_ex_rd_or_diff_sgl==0))
				begin
	
					if(BRESP==0) begin BRESP=1;BID=AWID;BIDUNQ=AWIDUNQ;end
					else begin BRESP=BRESP; BID=AWID;BIDUNQ=AWIDUNQ;end

				end
				else begin

					if(BRESP ==1) begin BRESP =0;BID=AWID;BIDUNQ=AWIDUNQ;end
					else begin BRESP=BRESP; BID=AWID;BIDUNQ=AWIDUNQ;end
					ex_wr_without_ex_rd_or_diff_sgl = 0;
				end

		//	for(int i=0;i<=AWLEN;i++)
			//get_write_data_phase(); 
			//execute_write_response_phase(trans);
			if(RRESP ==1) begin				
			$error($time,"FROM_SLAVE: Execlusive operation failed due to execlusive read is not done with this ID....!!!!/n Monitoring ID's:%p ---> Given ID:%0d\n",store_attribute,AWID);	
			end
		end
	
		if(h_intf.ARESETn==0)
		begin
			store_attribute.delete();//----------deleting array --------//
		end
			done_transaction=0;
	endtask


//----------------------------------------------------------------------------------------------------------------------------------------------//
//	---if normal write,EX_write recieves OKAY,EX_OKAY response respectiely invoke below task for checking exclusive monitoring addresses are changed or not.....
	task checking_memory_obdate_over_ex_rd_addrs(bit[`MAX_AXI5_DATA_WIDTH-1:0] addr, bit[7:0] len,bit[2:0] size,bit[1:0]burst,bit[`MAX_AXI5_ID_WIDTH-1:0]given_id,bit awlock);
		bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] n_ex_wr_start_addr,n_ex_wr_end_addr;
		bit[`MAX_AXI5_ADDRESS_WIDTH-1:0] ex_rd_start_addr,ex_rd_end_addr;
		if(burst==1) ///-----INCR
		begin
			n_ex_wr_start_addr=addr;
			n_ex_wr_end_addr  =addr+((2**size)*(len+1));
		end		
		else if (burst==2) //----WRAP
		begin
			n_ex_wr_start_addr=($floor(addr/((2**size)*(len+1)))*((2**size)*(len+1)));
			n_ex_wr_end_addr  =n_ex_wr_start_addr+((2**size)*(len+1));
		end
		foreach(store_attribute[ID])
		begin
			if(((ID != given_id ) && awlock)||(awlock==0))//----- not checking for current exclusive_wr id-----// 
			begin
//--------------------------------------------------------------------			
			if(store_attribute[ID].burst==1)//-----INCR
			begin
				ex_rd_start_addr=store_attribute[ID].addr;
				ex_rd_end_addr	=store_attribute[ID].addr+((2**store_attribute[ID].size)*(store_attribute[ID].len+1));
			end
			else if(store_attribute[ID].burst==2)	//---WRAP
			begin
				ex_rd_start_addr=($floor(store_attribute[ID].addr/((2**store_attribute[ID].size)*(store_attribute[ID].len+1)))*((2**store_attribute[ID].size)*(store_attribute[ID].len+1)));
				ex_rd_end_addr  =ex_rd_start_addr+((2**store_attribute[ID].size)*(store_attribute[ID].len+1));
			end
		if(store_attribute[ID].pass_fail==0)
		begin//{
			for(int i=ex_rd_start_addr;i<ex_rd_end_addr;i++) 
			begin
				for(int j=n_ex_wr_start_addr;j<n_ex_wr_end_addr;j++) 
				begin
					if(i==j) 
					begin
						store_attribute[ID].pass_fail=1;
						$error($time,"FROM_SLAVE:Exclusive access is not supported for this ID:%0d  %p ----Wr_adrss:%0d to %0d Ex_read:%0d to %0d",ID,store_attribute,n_ex_wr_start_addr,n_ex_wr_end_addr,ex_rd_start_addr,ex_rd_end_addr);
						break;
					end
				end
				if(store_attribute[ID].pass_fail==1)
				break;
			end
         end//}
//--------------------------------------------
		end

		end
 	endtask




endclass


