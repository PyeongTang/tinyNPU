`timescale 1ns / 1ps

module PU_Block #(
        parameter                                                   DATA_SIZE       =   8,
        parameter                                                   MAX_SYS_PORT    =   16,
        parameter                                                   V_PORT_WIDTH    =   16,
        parameter                                                   H_PORT_WIDTH    =   16
)(
        // System
        input       wire                                            i_clk,
        input       wire                                            i_n_reset,

        // Local control
        input       wire                                            i_set_param,
        input       wire                                            i_start_mac,
        output      wire                                            o_pu_ready,
        output      wire                                            o_mac_done,
        input       wire                                            i_terminate,

        // AXI
        input       wire        [7 : 0]                             i_pu_sys_usage_height,
        input       wire        [7 : 0]                             i_pu_sys_usage_width,
        input       wire        [7 : 0]                             i_pu_cycle_horizontal,
        input       wire        [7 : 0]                             i_pu_cycle_vertical,

        // I2S
        input       wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    i_i2s_data,
        input       wire                                            i_i2s_valid,

        // F2S
        input       wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    i_f2s_data,
        input       wire                                            i_f2s_valid,

        // BRAM
        output      wire signed [DATA_SIZE*4 - 1 : 0]               o_pu_data,
        output      wire                                            o_valid,
        output      wire                                            o_en_local_buffer,
        output      wire                                            o_wr_local_buffer
    );

    // Local Control
                    wire                                            w_mac_done;

    // pu_control - pu
                    wire                                            w_pu_enable;
                    wire                                            w_pu_set_param;
                    wire                                            w_pu_set_param_done;
                    wire                                            w_pu_read;
                    wire                                            w_read_done;


    // pu_control - local buffer
                    wire                                            w_en_buf;
                    wire                                            w_wr_buf;

    // i2s, f2s
                    wire                                            w_i2s_f2s_valid;

    pu_control                                                      PU_CTRL(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),
        .i_terminate                                                (i_terminate),

        .i_set_param                                                (i_set_param),
        .i_start_mac                                                (i_start_mac),
        .o_pu_ready                                                 (o_pu_ready),
        .o_mac_done                                                 (o_mac_done),

        .o_set_param                                                (w_pu_set_param),
        .o_enable                                                   (w_pu_enable),
        .o_read                                                     (w_pu_read),
        .i_set_param_done                                           (w_pu_set_param_done),

        .i_mac_done                                                 (w_mac_done),
        .i_read_done                                                (w_read_done),

        .o_en_local_buffer                                          (o_en_local_buffer),
        .o_wr_local_buffer                                          (o_wr_local_buffer)
    );

    pu                                                              #(
        .DATA_SIZE                                                  (DATA_SIZE),
        .V_PORT_WIDTH                                               (V_PORT_WIDTH),
        .H_PORT_WIDTH                                               (H_PORT_WIDTH)
    )                                                               PROCESSING_UNIT(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),
        .i_terminate                                                (i_terminate),

        .i_set_param                                                (w_pu_set_param),
        .i_enable                                                   (w_pu_enable),
        .i_read                                                     (w_pu_read),
        .o_set_param_done                                           (w_pu_set_param_done),

        .i_pu_cycle_horizontal                                      (i_pu_cycle_horizontal),
        .i_pu_cycle_vertical                                        (i_pu_cycle_vertical),
        .i_pu_sys_usage_width                                       (i_pu_sys_usage_width),
        .i_pu_sys_usage_height                                      (i_pu_sys_usage_height),

        .o_mac_done                                                 (w_mac_done),
        .o_read_done                                                (w_read_done),

        .i_valid                                                    (w_i2s_f2s_valid),
        .i_data_v                                                   (i_f2s_data),
        .i_data_h                                                   (i_i2s_data),
        .o_data_s                                                   (o_pu_data),
        .o_valid                                                    (o_valid)
    );

    assign w_i2s_f2s_valid = i_i2s_valid | i_f2s_valid;

endmodule
