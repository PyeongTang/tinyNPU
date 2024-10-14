
`timescale 1 ns / 1 ps

	module tinyNPU_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here
		output		wire					o_done,
		output		wire		[3 : 0]		o_state,

		output		wire					o_rst_image_ram,
		output		wire					o_en_image_ram,
		output		wire		[31 : 0]	o_image_ram_addr,
		input		wire		[31 : 0]	i_image_ram_data,

		output		wire					o_rst_filter_ram,
		output		wire					o_en_filter_ram,
		output		wire		[31 : 0]	o_filter_ram_addr,
		input		wire		[31 : 0]	i_filter_ram_data,

		output		wire					o_rst_result_ram,
		output		wire					o_en_result_ram,
		output		wire		[3 : 0]		o_result_wr_ram,
		output		wire		[31 : 0]	o_result_ram_addr,
		output		wire		[31 : 0]	o_result_ram_data,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
		wire						w_output_layer;
		wire						w_terminate;
		wire		[1 : 0]			w_op_mode;
		wire		[7 : 0]			w_image_width;
		wire		[7 : 0]			w_image_height;
		wire		[7 : 0]			w_image_channel;
		wire		[7 : 0]			w_image_slice_width;
		wire		[7 : 0]			w_image_slice_height;
		wire		[7 : 0]			w_image_slice_number;
		wire		[7 : 0]			w_filter_width;
		wire		[7 : 0]			w_filter_height;
		wire		[7 : 0]			w_filter_channel;
		wire		[7 : 0]			w_filter_number;
		wire		[7 : 0]			w_filter_slice_width;
		wire		[7 : 0]			w_filter_slice_height;
		wire		[7 : 0]			w_filter_slice_number;
		wire		[11 : 0]		w_output_depth;
		// wire		[31 : 0]		w_deq_X_s;
		// wire		[31 : 0]		w_deq_w_s;
		// wire		[31 : 0]		w_q_X_s;

// Instantiation of Axi Bus Interface S00_AXI
	tinyNPU_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) tinyNPU_v1_0_S00_AXI_inst 	(
		.o_output_layer				(w_output_layer),
		.o_terminate				(w_terminate),
		.o_op_mode					(w_op_mode),
		.o_image_width				(w_image_width),
		.o_image_height				(w_image_height),
		.o_image_channel			(w_image_channel),
		.o_image_slice_width		(w_image_slice_width),
		.o_image_slice_height		(w_image_slice_height),
		.o_image_slice_number		(w_image_slice_number),
		.o_filter_width				(w_filter_width),
		.o_filter_height			(w_filter_height),
		.o_filter_channel			(w_filter_channel),
		.o_filter_number			(w_filter_number),
		.o_filter_slice_width		(w_filter_slice_width),
		.o_filter_slice_height		(w_filter_slice_height),
		.o_filter_slice_number		(w_filter_slice_number),
		.o_output_depth				(w_output_depth),
		// .o_deq_X_s					(w_deq_X_s),
		// .o_deq_w_s					(w_deq_w_s),
		// .o_q_X_s					(w_q_X_s),

		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here

	top_tinyNPU						i_TOP_TINY_NPU(
		.i_clk						(s00_axi_aclk),
		.i_n_reset					(s00_axi_aresetn),
		.o_done						(o_done),
		.o_state					(o_state),
		.i_output_layer				(w_output_layer),
		.i_terminate				(w_terminate),
		.i_op_mode					(w_op_mode),
		.i_image_width				(w_image_width),
		.i_image_height				(w_image_height),
		.i_image_channel			(w_image_channel),
		.i_image_slice_width		(w_image_slice_width),
		.i_image_slice_height		(w_image_slice_height),
		.i_image_slice_number		(w_image_slice_number),
		.i_filter_width				(w_filter_width),
		.i_filter_height			(w_filter_height),
		.i_filter_channel			(w_filter_channel),
		.i_filter_number			(w_filter_number),
		.i_filter_slice_width		(w_filter_slice_width),
		.i_filter_slice_height		(w_filter_slice_height),
		.i_filter_slice_number		(w_filter_slice_number),
		.i_output_depth				(w_output_depth),
		// .i_deq_X_s					(w_deq_X_s),
		// .i_deq_w_s					(w_deq_w_s),
		// .i_q_X_s					(w_q_X_s),
		.o_rst_image_ram			(o_rst_image_ram),
		.o_en_image_ram				(o_en_image_ram),
		.o_image_ram_addr			(o_image_ram_addr),
		.i_image_ram_data			(i_image_ram_data),
		.o_rst_filter_ram			(o_rst_filter_ram),
		.o_en_filter_ram			(o_en_filter_ram),
		.o_filter_ram_addr			(o_filter_ram_addr),
		.i_filter_ram_data			(i_filter_ram_data),
		.o_rst_result_ram			(o_rst_result_ram),
		.o_en_result_ram			(o_en_result_ram),
		.o_result_wr_ram			(o_result_wr_ram),
		.o_result_ram_addr			(o_result_ram_addr),
		.o_result_ram_data			(o_result_ram_data)
	);
	// User logic ends

	endmodule
