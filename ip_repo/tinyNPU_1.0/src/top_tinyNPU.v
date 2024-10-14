`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: -
// Engineer: Lee JaePyeong
// 
// Create Date: 2024/09/16 01:11:19
// Design Name: 
// Module Name: top_tinyNPU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_tinyNPU(
        // System
        input       wire                                            i_clk,
        input       wire                                            i_n_reset,
        output      wire                                            o_done,
        output      wire        [3 : 0]                             o_state,

        // AXI
        // 11 : CONV, 10 : FC, 01 : POOL, 00 : IDLE
        input       wire                                            i_output_layer,
        input       wire                                            i_terminate,
        input       wire        [1 : 0]                             i_op_mode,
        input       wire        [7 : 0]                             i_image_width,
        input       wire        [7 : 0]                             i_image_height,
        input       wire        [7 : 0]                             i_image_channel,
        input       wire        [7 : 0]                             i_image_slice_width,
        input       wire        [7 : 0]                             i_image_slice_height,
        input       wire        [7 : 0]                             i_image_slice_number,
        input       wire        [7 : 0]                             i_filter_width,
        input       wire        [7 : 0]                             i_filter_height,
        input       wire        [7 : 0]                             i_filter_channel,
        input       wire        [7 : 0]                             i_filter_number,
        input       wire        [7 : 0]                             i_filter_slice_width,
        input       wire        [7 : 0]                             i_filter_slice_height,
        input       wire        [7 : 0]                             i_filter_slice_number,
        input       wire        [11 : 0]                            i_output_depth,

        // IMAGE RAM READER
        output      wire                                            o_rst_image_ram,
        output      wire                                            o_en_image_ram,
        output      wire        [31 : 0]                            o_image_ram_addr,
        input       wire        [31 : 0]                            i_image_ram_data,
        
        // FILTER RAM READER
        output      wire                                            o_rst_filter_ram,
        output      wire                                            o_en_filter_ram,
        output      wire        [31 : 0]                            o_filter_ram_addr,
        input       wire        [31 : 0]                            i_filter_ram_data,

        // RESULT RAM WRITER
        output      wire                                            o_rst_result_ram,
        output      wire                                            o_en_result_ram,
        output      wire        [3 : 0]                             o_result_wr_ram,
        output      wire        [31 : 0]                            o_result_ram_addr,
        output      wire        [31 : 0]                            o_result_ram_data
    );

        // NPU - IMAGE RAM
        wire                                                        w_im2col_addressing;
        wire                    [31 : 0]                            w_im2col_address;
        wire                                                        w_image_ram_read;
        wire                                                        w_image_ram_read_term;
        wire        signed      [31 : 0]                            w_image_ram_data;
        wire                                                        w_image_ram_valid;

        // NPU - FILTER RAM
        wire                                                        w_filter_ram_read;
        wire                                                        w_filter_ram_read_term;
        wire        signed      [31 : 0]                            w_filter_ram_data;
        wire                                                        w_filter_ram_valid;

        // NPU - RESULT RAM
        wire                                                        w_result_ram_write;
        wire                    [31 : 0]                            w_result_ram_data;
        wire                                                        w_result_ram_valid;

        tinyNPU                                                     i_NPU(
            .i_clk                                                  (i_clk),
            .i_n_reset                                              (i_n_reset),
            .i_output_layer                                         (i_output_layer),
            .i_terminate                                            (i_terminate),
            .o_state                                                (o_state),
            .o_done                                                 (o_done),
            .i_op_mode                                              (i_op_mode),
            .i_image_width                                          (i_image_width),
            .i_image_height                                         (i_image_height),
            .i_image_channel                                        (i_image_channel),
            .i_image_slice_width                                    (i_image_slice_width),
            .i_image_slice_height                                   (i_image_slice_height),
            .i_image_slice_number                                   (i_image_slice_number),
            .i_filter_width                                         (i_filter_width),
            .i_filter_height                                        (i_filter_height),
            .i_filter_channel                                       (i_filter_channel),
            .i_filter_number                                        (i_filter_number),
            .i_filter_slice_width                                   (i_filter_slice_width),
            .i_filter_slice_height                                  (i_filter_slice_height),
            .i_filter_slice_number                                  (i_filter_slice_number),
            .i_output_depth                                         (i_output_depth),

            .o_en_image_ram                                         (w_image_ram_read),
            
            .o_im2col_addressing                                    (w_im2col_addressing),
            .o_im2col_address                                       (w_im2col_address),

            .o_image_ram_read_term                                  (w_image_ram_read_term),
            .i_ram_to_i2c_data                                      (w_image_ram_data[7 : 0]),
            .i_ram_to_i2c_valid                                     (w_image_ram_valid),

            .o_en_filter_ram                                        (w_filter_ram_read),
            .o_filter_ram_read_term                                 (w_filter_ram_read_term),
            .i_ram_to_f2r_data                                      (w_filter_ram_data[7 : 0]),
            .i_ram_to_f2r_valid                                     (w_filter_ram_valid),

            .o_wr_result_ram                                        (w_result_ram_write),
            .o_data                                                 (w_result_ram_data),
            .o_valid                                                (w_result_ram_valid)
        );

        ram_rd                                                      #(
            .WIDTH                                                  (32)
        )                                                           i_IMAGE_RAM_READER(
            .i_clk                                                  (i_clk),
            .i_n_reset                                              (i_n_reset),
            .i_read                                                 (w_image_ram_read),
            .i_term                                                 (w_image_ram_read_term),
            .i_addressing                                           (w_im2col_addressing),
            .o_rst_ram                                              (o_rst_image_ram),
            .o_en_ram                                               (o_en_image_ram),
            .i_ram_addr                                             (w_im2col_address),
            .o_ram_addr                                             (o_image_ram_addr),
            .i_ram_data                                             (i_image_ram_data),
            .o_ram_data                                             (w_image_ram_data),
            .o_ram_valid                                            (w_image_ram_valid)
        );

        ram_rd                                                      #(
            .WIDTH                                                  (32)
        )                                                           i_FILTER_RAM_READER(
            .i_clk                                                  (i_clk),
            .i_n_reset                                              (i_n_reset),
            .i_read                                                 (w_filter_ram_read),
            .i_term                                                 (w_filter_ram_read_term),
            .i_addressing                                           (1'b0),
            .o_rst_ram                                              (o_rst_filter_ram),
            .o_en_ram                                               (o_en_filter_ram),
            .i_ram_addr                                             (32'h0),
            .o_ram_addr                                             (o_filter_ram_addr),
            .i_ram_data                                             (i_filter_ram_data),
            .o_ram_data                                             (w_filter_ram_data),
            .o_ram_valid                                            (w_filter_ram_valid)
        );

        ram_wr                                                      #(
            .WIDTH                                                  (32)
        )                                                           i_RESULT_RAM_WRITER(
            .i_clk                                                  (i_clk),
            .i_n_reset                                              (i_n_reset),
            .i_write                                                (w_result_ram_write),
            .i_data                                                 (w_result_ram_data),
            .i_data_valid                                           (w_result_ram_valid),
            .o_rst_ram                                              (o_rst_result_ram),
            .o_en_ram                                               (o_en_result_ram),
            .o_wr_ram                                               (o_result_wr_ram),
            .o_ram_addr                                             (o_result_ram_addr),
            .o_ram_data                                             (o_result_ram_data)
        );

        
endmodule
