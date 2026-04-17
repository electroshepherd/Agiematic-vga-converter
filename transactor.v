module transactor #(
	parameter IDLE = 0,
	parameter SEND_ADDR = 1,
	parameter SEND_DATA = 2,
	parameter READ_DATA = 2,
	parameter GET_RESP = 3,
	parameter PIX_SIZE = 16,
	parameter TRANSFERS_NEEDED = 2
)
	(
/*********write channel********/
	// write address channel
	output wire [1:0] awburst,
	output wire [3:0] awcache,
	output wire awvalid,
	input wire awready,
	output reg [31:0] awaddr, 
	output wire [2:0] awsize, awprot,
	output wire [7:0] awlen, 
	output wire [3:0] awqos,
	output wire awlock,
	output wire awid,
	output wire [3:0]awregion,
	/*
	* there is no awuser
	* and awlock here
	*/

	// write data channel
	output wire wvalid, wlast, 
	output reg [31:0] wdata,
	input wire wready,
	output wire [3:0] wstrb,
	/*
	* 
	*/
	
	//write responce channel
	input wire bvalid, 
	output wire bready, 
	input wire [1:0] bresp,
	input wire [1:0]bid,
	
/*******read channel**********/

//read address channel
	output wire arvalid,
	input wire arready,
	output reg [31:0] araddr,
	output wire [2:0] arsize,
	output wire [1:0] arburst, 
	output wire [3:0] arcache,
	output wire [7:0] arlen,
	output wire [2:0] arprot,
	output wire arid,
	output wire arlock,
	output wire [3:0] arqos,
	output wire [3:0] arregion,
	/*
	* there is no [x:0] aruser here;
	*/

//read data channel
	input wire rvalid, rlast,
	output wire rready,
	input wire [31:0] rdata,
	input wire rid,
	input wire [1:0] rresp,
	/*
	* there are no ruser and [1:0] resp here
	*/

/*******rgb signals******************************/	
	input wire hsync_i, vsync_i,		// 
	output wire hsync_o, vsync_o,           //
	input wire [PIX_SIZE-1:0] rgb_i,                 //
	output reg  [PIX_SIZE-1:0] rgb_o,                //
/************************************************/
	input wire resetn, clk25, aclk
/*************************************************/
);
	reg w_num_transfers, r_num_transfers; //we need 2 transfers for a line (320 words);
	wire in_active_h, in_active_v, out_active_h, out_active_v;
	wire [31:0] base1;
	wire [31:0] base2;
	reg [17:0] out_offset;
	reg [17:0] in_offset;
	reg [1:0] in_state;
	reg [9:0] in_h_cnt;
	reg [8:0] in_v_cnt;

	reg frame; //memory frame buffer pointer

	initial begin
		r_num_transfers<=1;
		w_num_transfers<=1;
		in_state<=0;
		out_offset <=0;
		in_offset <=0;
		frame <=0;
		in_h_cnt <=0;
		in_v_cnt <=0;
		awaddr <=0;
		araddr <=0;
	end
/**************************************************************/
/*********************WRITE_CHANNEL****************************/
	(* ram_style = "block" *)     //16 bit per pixel
	reg [31:0] in_buffer [0:640/(32/PIX_SIZE)-1]; //buffer for 1 line in 32-bit mode
	reg [31:0] in_wrd;
	reg [7:0] in_wr_index;
	reg [7:0] in_rd_index;
	reg [1:0] in_wr_ptr;
	integer i;
	initial begin
		in_wrd <=0;
		wdata <=0;
		for (i=0; i<640/(32/PIX_SIZE); i= i+1)
			in_buffer[i] <=0;
		in_wr_index <=0;
		in_rd_index <=0;
		in_wr_ptr<=0;
	end
/**************************************************************/
/*****************read chanenel********************************/
	(* ram_style = "block" *)
	reg [31:0] out_buffer [0:640/(32/PIX_SIZE)-1];//1 line
	reg [31:0] out_wrd;
	reg [1:0] out_state;
        reg [10:0] out_h_cnt;
        reg [10:0] out_v_cnt;
	reg [7:0]out_wr_index;
	reg [7:0]out_rd_index;
	reg [1:0]out_rd_ptr;
	initial begin 
		out_wrd <=0;
		for (i=0; i<640/(32/PIX_SIZE); i=i+1)
		out_buffer[i] <=0;
		out_state <=0;
		out_h_cnt <=0;
		out_v_cnt <=0;
		out_wr_index <=0;
		out_rd_index <=0;
		out_rd_ptr <=0;
	end
/**************************************************************/
/*********************ASSIGNы FOR AXI*************************/

	assign awsize = 3'b010; //4 bytes because of 32-bit data bus
	assign arsize = 3'b010; //4 bytes
	assign wstrb = 4'hf;
	assign arburst = 2'b01;
	assign awburst = 2'b01;
	assign awlen = 159;//1/2 line in 32-bit mode
	assign arlen = 159;//2 transfers needed for 1 line

	assign base1 = 32'h1000_0000;
	assign base2 = 32'h1009_6000;
/************************************************************************/
/*****************RGB out channel****************************************/
	assign out_active_h = (out_h_cnt <640);
	assign out_active_v = (out_v_cnt >=31 && out_v_cnt <511);

	always @(posedge clk25) begin
		if (resetn) begin
			if(out_h_cnt <800) out_h_cnt <= out_h_cnt +1;
			else begin
			       	out_h_cnt <=0;
				if (vsync_i) out_v_cnt <=0;
				else out_v_cnt <= out_v_cnt +1;
			end
			if (out_active_h && out_active_v)begin
				rgb_o <=out_wrd [out_rd_ptr*PIX_SIZE+:PIX_SIZE];
				if (out_rd_ptr == (32/PIX_SIZE-1)) begin
					out_rd_ptr <=0;
					out_rd_index <= out_rd_index +1;
					out_wrd <= out_buffer[out_rd_index];
				end
				else out_rd_ptr <= out_rd_ptr +1;
			end
			else begin
				out_rd_ptr <=0;
				out_rd_index<=0;
				rgb_o <=0;
			end
			if (out_h_cnt == 640) begin //640 instead of 656
				if (out_active_v)
					out_offset <= out_offset +640*(PIX_SIZE/8);
				else out_offset <=0;
			end
			if(frame) araddr <= base1+out_offset;
			else araddr <= base2 + out_offset;
		end
		else begin
			out_rd_ptr <=0;
			out_rd_index<=0;
			rgb_o <=0;
			out_h_cnt <=0;
			out_rd_ptr <=0;
			out_v_cnt <=0;
		end
	end
	assign hsync_o = (out_h_cnt >=656 && out_h_cnt <752);
	assign vsync_o = vsync_i;
/**********************************************************************/
/*****************RGB in channel***************************************/
	assign in_active_h = (in_h_cnt >=64 && in_h_cnt <704);
	assign in_active_v = (in_v_cnt >= 10 && in_v_cnt <410);
	reg hsync_i_reg, vsync_i_reg;

	always @(posedge aclk) begin
		hsync_i_reg <=hsync_i;
		vsync_i_reg <= vsync_i;
		if (resetn) begin
			if (hsync_i)
			       	in_h_cnt <= 0;
			else in_h_cnt <= in_h_cnt +1;
			if(in_active_h && in_active_v)begin
				in_wrd[in_wr_ptr*PIX_SIZE+:PIX_SIZE]<=rgb_i;
				if(in_wr_ptr == (32/PIX_SIZE-1))begin
					in_wr_ptr <= 0;
				end
				else begin
					in_wr_ptr <= in_wr_ptr +1;
				end
				if(in_wr_ptr == 0)begin
					in_wr_index <=in_wr_index +1;
					if(in_wr_index!=0) in_buffer[in_wr_index-1]<=in_wrd;
				end
			end
			else begin
			     in_wr_ptr<=0;
			     in_wr_index <= 0;
			end 
			if(frame) awaddr <= base2 + in_offset;
			else awaddr <= base1 + in_offset;
			if (hsync_i && ~ hsync_i_reg) begin
				if (vsync_i) in_v_cnt <= 0;
				else in_v_cnt <= in_v_cnt +1;
				if (in_active_v) 
					in_offset <= in_offset + 640*(PIX_SIZE/8);
				else in_offset <=0;
			end
		end
		else begin
			in_h_cnt <=0;
		end
	end

/*
		       784 = 39,2us
|<---------------------------------------------------------->|
|     ___________           _________________________________|
|    |           |         |                                 |
|    |           |         |                                 |
|____|           |_________|                                 |
|<-->|<--------->|<------->|<------------------------------->|
| 10 | 70=3,5 us |64=3,2 us|           640=32us              |
line timings for Agiematic CD, measured in aclk (20MHz) cycles.

	vsync pulse is 320us long, so it contains ~8 lines
	425-8 = 417; I think it will be
       	10 lines offset after pulse and 7 before it;*/

	always @(posedge vsync_i) begin
		frame <= ~frame;
	end
	//TODO^ remove this fuckin shit and do better
/*	always @(posedge hsync_i)begin
		if (resetn) begin
			if (vsync_i) in_v_cnt <= 0;
			else in_v_cnt <= in_v_cnt +1;
			if (in_active_v)
				in_offset <= in_offset + 640;
			else in_offset <=0;
		end
		else begin
			in_offset <=0;
			in_v_cnt <=0;
		end
	end */

/******************************************************************/
/**************************AXI*************************************/
	/*-WRITE-*/
	assign awvalid = (in_state == SEND_ADDR);
	assign wlast = (in_rd_index == 159);// && wready && wvalid);
	assign wvalid = (in_state == SEND_DATA || in_state == SEND_ADDR);
	assign bready = (in_state == GET_RESP);

	/*-READ-*/
	assign rready =(out_state == READ_DATA);
	assign arvalid = (out_state == SEND_ADDR);

	always @(posedge aclk) begin
		if (resetn) begin
			/*---WRITE---*/
			case (in_state)
				IDLE:begin
					w_num_transfers<=TRANSFERS_NEEDED-1;
					if (in_h_cnt >0 && in_h_cnt <64 && in_active_v) begin
						in_state <= SEND_ADDR;
					end
					in_rd_index <=0;
				end
				SEND_ADDR:begin
					if (awready) begin
						in_state <= SEND_DATA;
					end
				end
				SEND_DATA:begin
					if (wlast) in_state <= GET_RESP;
				end
				GET_RESP:begin
					if (bvalid)begin
						if(w_num_transfers>0) begin
							w_num_transfers<=w_num_transfers-1;
						       	in_state<=SEND_ADDR;
						end
						else begin 
							in_state <= IDLE;
							in_rd_index <=0;
						end
					end

				end
				default: in_state <= IDLE;
			endcase

			if (wready && wvalid) in_rd_index <= in_rd_index +1;
			if (wvalid) wdata <= in_buffer[in_rd_index];
			/*---READ---*/
			case (out_state)
				IDLE:begin
					r_num_transfers<=TRANSFERS_NEEDED-1;
					out_wr_index <=0;
					if (out_active_v && hsync_o)
						out_state <= SEND_ADDR;
				end
				SEND_ADDR:begin
					if (arready)begin
						out_state  <= READ_DATA;
					end
					if (out_h_cnt == 0) out_state <= IDLE;
				end
				READ_DATA:begin
					if (rvalid)begin
						out_buffer[out_wr_index]<=rdata;
						out_wr_index <= out_wr_index+1;
					end
					if (rlast)begin
						if(r_num_transfers>0) begin
							r_num_transfers<= r_num_transfers-1;
							out_state <= SEND_ADDR;
						end
						else begin
							out_state <= IDLE;
						end
					end
				end
				default: out_state <= IDLE;
			endcase
		end
		else begin
			in_state <=0;
			out_state <=0;
		end
	end

/**********trash ports****************/
	assign awprot = 3'b010;
	assign arprot = 3'b010;
	assign awid = 1;
	assign arid = 0;
	assign awcache = 4'b0011;
	assign arcache = 4'b0011;
	assign arqos = 0;
	assign awqos = 0;
	assign awlock = 0;
	assign arlock = 0;
	assign awregion = 0;
	assign arregion = 0;
/*************************************/

endmodule
