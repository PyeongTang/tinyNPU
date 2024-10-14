`timescale 1ns / 1ps

module F2R_Block#(
    parameter                                                   DATA_SIZE               =   8,
    parameter                                                   MAX_SYS_PORT            =   16,
    parameter                                                   MAX_SYS_HEIGHT          =   3,
    parameter                                                   MAX_SYS_WIDTH           =   6,
    parameter                                                   MAX_DEPTH_FILTER        =   4*1,
    parameter                                                   MAX_DEPTH_SLICE         =   4*1,
    parameter                                                   MAX_DEPTH_SYS           =   MAX_SYS_HEIGHT * MAX_SYS_WIDTH,
    parameter                                                   MAX_CYCLE               =   MAX_SYS_HEIGHT + MAX_SYS_WIDTH - 1
)(
    // System
    input       wire                                            i_clk,
    input       wire                                            i_n_reset,

    // Local Control
    input       wire                                            i_set_param,
    input       wire                                            i_start_mac,
    input       wire                                            i_terminate,
    output      wire                                            o_filter_ready,
    output      wire                                            o_slice_last,
    output      wire                                            o_done,

    // AXI
    input       wire        [1 : 0]                             i_op_mode,
    input       wire        [7 : 0]                             i_filter_width,
    input       wire        [7 : 0]                             i_filter_height,
    input       wire        [7 : 0]                             i_filter_channel,
    input       wire        [7 : 0]                             i_filter_number,
    input       wire        [7 : 0]                             i_slice_width,
    input       wire        [7 : 0]                             i_slice_height,
    input       wire        [7 : 0]                             i_slice_number,

    // RAM
    output      wire                                            o_en_ram,
    output      wire                                            o_ram_read_term,
    input       wire signed [DATA_SIZE-1 : 0]                   i_ram_to_f2r_data,
    input       wire                                            i_ram_to_f2r_valid,

    // PU
    output      wire        [7 : 0]                             o_filter_slice_sys_height,
    output      wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    o_data,
    output      wire                                            o_valid
);

    // CTRL - F2R
                wire                                            w_f2r_enable;
                wire                                            w_f2r_read;
                wire                                            w_f2r_set_param;
                wire                                            w_f2r_set_param_done;
                wire                                            w_f2r_slice_last;
                wire                                            w_f2r_slice_read_done;

    // CTRL - F2S
                wire                                            w_f2s_enable;
                wire                                            w_f2s_read;
                wire                                            w_f2s_read_done;
                wire                                            w_f2s_set_param;
                wire                                            w_f2s_set_param_done;

    // F2R - F2S
                wire signed [DATA_SIZE-1 : 0]                   w_f2r_to_f2s_data;
                wire                                            w_f2r_to_f2s_valid;

    // F2R - RAM
                wire                                            w_ram_read_term;

    f2r_control                                                 F2R_CTRL(
        .i_clk                                                  (i_clk),
        .i_n_reset                                              (i_n_reset),
        .i_set_param                                            (i_set_param),
        .i_start_mac                                            (i_start_mac),
        .i_terminate                                            (i_terminate),
        .i_slice_number                                         (i_slice_number),
        .o_filter_ready                                         (o_filter_ready),
        .o_done                                                 (o_done),
        .i_f2r_set_param_done                                   (w_f2r_set_param_done),
        .o_f2r_enable                                           (w_f2r_enable),
        .o_f2r_read                                             (w_f2r_read),
        .i_f2r_slice_last                                       (w_f2r_slice_last),
        .i_f2r_slice_read_done                                  (w_f2r_slice_read_done),
        .o_f2r_set_param                                        (w_f2r_set_param),
        .o_f2s_enable                                           (w_f2s_enable),
        .o_f2s_read                                             (w_f2s_read),
        .i_f2s_read_done                                        (w_f2s_read_done),
        .o_f2s_set_param                                        (w_f2s_set_param),
        .i_f2s_set_param_done                                   (w_f2s_set_param_done),
        .i_ram_read_done                                        (w_ram_read_term),
        .o_en_ram                                               (o_en_ram)
    );

    filter2row                                                  #(
        .DATA_SIZE                                              (DATA_SIZE),
        .MAX_SYS_PORT                                           (MAX_SYS_PORT),
        .MAX_DEPTH_FILTER                                       (MAX_DEPTH_FILTER),
        .MAX_DEPTH_SLICE                                        (MAX_DEPTH_SLICE)
    )                                                           F2R(
        .i_clk                                                  (i_clk),
        .i_n_reset                                              (i_n_reset),
        .i_terminate                                            (i_terminate),
        .i_enable                                               (w_f2r_enable),
        .i_read                                                 (w_f2r_read),
        .i_set_param                                            (w_f2r_set_param),
        .i_op_mode                                              (i_op_mode),
        .i_filter_width                                         (i_filter_width),
        .i_filter_height                                        (i_filter_height),
        .i_filter_channel                                       (i_filter_channel),
        .i_filter_number                                        (i_filter_number),
        .i_slice_width                                          (i_slice_width),
        .i_slice_height                                         (i_slice_height),
        .i_slice_number                                         (i_slice_number),
        .o_set_param_done                                       (w_f2r_set_param_done),
        .o_slice_read_done                                      (w_f2r_slice_read_done),
        .o_slice_last                                           (w_f2r_slice_last),
        .i_data                                                 (i_ram_to_f2r_data),
        .i_valid                                                (i_ram_to_f2r_valid),
        .o_ram_read_term                                        (w_ram_read_term),
        .o_data                                                 (w_f2r_to_f2s_data),
        .o_valid                                                (w_f2r_to_f2s_valid)
    );

    filter2systolic                                             #(
        .DATA_SIZE                                              (DATA_SIZE),
        .MAX_SYS_PORT                                           (MAX_SYS_PORT),
        .MAX_SYS_HEIGHT                                         (MAX_SYS_HEIGHT),
        .MAX_SYS_WIDTH                                          (MAX_SYS_WIDTH),
        .MAX_DEPTH_SYS                                          (MAX_DEPTH_SYS),
        .MAX_CYCLE                                              (MAX_CYCLE)
    )                                                           F2S(
        .i_clk                                                  (i_clk),
        .i_n_reset                                              (i_n_reset),
        .i_terminate                                            (i_terminate),
        .i_enable                                               (w_f2s_enable),
        .i_read                                                 (w_f2s_read),
        .i_set_param                                            (w_f2s_set_param),
        .i_slice_width                                          (i_slice_width),
        .i_slice_height                                         (i_slice_height),
        .o_set_param_done                                       (w_f2s_set_param_done),
        .o_read_done                                            (w_f2s_read_done),
        .i_data                                                 (w_f2r_to_f2s_data),
        .i_valid                                                (w_f2r_to_f2s_valid),
        .o_filter_slice_sys_height                              (o_filter_slice_sys_height),
        .o_data                                                 (o_data),
        .o_valid                                                (o_valid)
    );

    assign o_slice_last     =   w_f2r_slice_last;
    assign o_ram_read_term  =   w_ram_read_term;

endmodule
