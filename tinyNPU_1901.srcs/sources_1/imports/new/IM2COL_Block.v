`timescale 1ns / 1ps

module IM2COL_Block #(
        parameter                                                   DATA_SIZE               =   8,
        parameter                                                   MAX_SYS_PORT            =   16,
        parameter                                                   MAX_DEPTH_IMAGE         =   12*4,
        parameter                                                   MAX_DEPTH_OUTPUT        =   12*4,
        parameter                                                   MAX_DEPTH_SLICE         =   3*4,
        parameter                                                   MAX_SYS_HEIGHT          =   16,
        parameter                                                   MAX_SYS_WIDTH           =   16,
        parameter                                                   MAX_DEPTH_SYS           =   MAX_SYS_HEIGHT * MAX_SYS_WIDTH,
        parameter                                                   MAX_CYCLE               =   MAX_SYS_HEIGHT + MAX_SYS_WIDTH - 1
)(
        // System
        input       wire                                            i_clk,
        input       wire                                            i_n_reset,

        // Local Control
        input       wire                                            i_set_param,
        input       wire                                            i_start_mac,
        input       wire                                            i_start_pool,
        input       wire                                            i_terminate,
        output      wire                                            o_image_ready,
        output      wire                                            o_slice_last,
        output      wire                                            o_done,

        // AXI4
        input       wire        [1 : 0]                             i_op_mode,
        
        input       wire        [7 : 0]                             i_image_width,
        input       wire        [7 : 0]                             i_image_height,
        input       wire        [7 : 0]                             i_image_channel,
        
        input       wire        [7 : 0]                             i_filter_width,
        input       wire        [7 : 0]                             i_filter_height,
        
        input       wire        [7 : 0]                             i_slice_width,
        input       wire        [7 : 0]                             i_slice_height,
        input       wire        [7 : 0]                             i_slice_number,

        // ram_rd
        output      wire                                            o_en_ram,
        output      wire                                            o_ram_read_term,
        input       wire signed [DATA_SIZE-1 : 0]                   i_ram_to_i2c_data,
        input       wire                                            i_ram_to_i2c_valid,

        // PU
        output      wire        [7 : 0]                             o_image_slice_sys_width,
        output      wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    o_i2s_data,
        output      wire                                            o_i2s_valid,

        // POOL
        output      wire signed [DATA_SIZE-1 : 0]                   o_i2c_data,
        output      wire                                            o_i2c_valid,
        output      wire                                            o_i2c_read_done
    );

        // CTRL - I2C
                    wire                                            w_i2c_enable;
                    wire                                            w_i2c_convert_done;
                    wire                                            w_i2c_read;
                    wire                                            w_i2c_read_done;
                    wire                                            w_i2c_set_param;
                    wire                                            w_i2c_set_param_done;
                    wire                                            w_i2c_slice_last;
                    wire                                            w_i2c_slice_read_done;

        // CTRL - I2S
                    wire                                            w_i2s_enable;
                    wire                                            w_i2s_read;
                    wire                                            w_i2s_read_done;
                    wire                                            w_i2s_set_param;
                    wire                                            w_i2s_set_param_done;

        // I2C - I2S
                    wire signed [DATA_SIZE-1 : 0]                   w_i2c_to_i2s_data;
                    wire                                            w_i2c_to_i2s_valid;

        // I2C - RAM
                    wire                                            w_ram_read_term;


    im2col_control                                                  CTRL(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),

        .i_set_param                                                (i_set_param),
        .i_op_mode                                                  (i_op_mode),
        .i_start_mac                                                (i_start_mac),
        .i_start_pool                                               (i_start_pool),
        .i_terminate                                                (i_terminate),
        .i_slice_number                                             (i_slice_number),
        .o_image_ready                                              (o_image_ready),
        .o_done                                                     (o_done),

        .i_i2c_set_param_done                                       (w_i2c_set_param_done),
        .o_i2c_enable                                               (w_i2c_enable),
        .i_i2c_convert_done                                         (w_i2c_convert_done),
        .o_i2c_read                                                 (w_i2c_read),
        .i_i2c_read_done                                            (w_i2c_read_done),
        .i_i2c_slice_last                                           (w_i2c_slice_last),
        .i_i2c_slice_read_done                                      (w_i2c_slice_read_done),
        .o_i2c_set_param                                            (w_i2c_set_param),
        
        .o_i2s_enable                                               (w_i2s_enable),
        .o_i2s_read                                                 (w_i2s_read),
        .i_i2s_read_done                                            (w_i2s_read_done),

        .o_i2s_set_param                                            (w_i2s_set_param),
        .i_i2s_set_param_done                                       (w_i2s_set_param_done),

        .o_en_ram                                                   (o_en_ram),
        .i_ram_read_done                                            (w_ram_read_term)
    );

    im2col                                                          #(
        .DATA_SIZE                                                  (DATA_SIZE),
        .MAX_SYS_PORT                                               (MAX_SYS_PORT),
        .MAX_DEPTH_IMAGE                                            (MAX_DEPTH_IMAGE),
        .MAX_DEPTH_OUTPUT                                           (MAX_DEPTH_OUTPUT),
        .MAX_DEPTH_SLICE                                            (MAX_DEPTH_SLICE)
    )                                                               I2C(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),
        .i_terminate                                                (i_terminate),

        .i_enable                                                   (w_i2c_enable),
        .i_read                                                     (w_i2c_read),
        .o_convert_done                                             (w_i2c_convert_done),
        .i_set_param                                                (w_i2c_set_param),
        
        .i_op_mode                                                  (i_op_mode),
        .i_image_width                                              (i_image_width),
        .i_image_height                                             (i_image_height),
        .i_image_channel                                            (i_image_channel),
        .i_filter_width                                             (i_filter_width),
        .i_filter_height                                            (i_filter_height),
        .i_slice_width                                              (i_slice_width),
        .i_slice_height                                             (i_slice_height),
        .i_slice_number                                             (i_slice_number),

        .o_set_param_done                                           (w_i2c_set_param_done),
        .o_read_done                                                (w_i2c_read_done),
        .o_slice_read_done                                          (w_i2c_slice_read_done),
        .o_slice_last                                               (w_i2c_slice_last),
        .i_data                                                     (i_ram_to_i2c_data),
        .i_valid                                                    (i_ram_to_i2c_valid),
        .o_ram_read_term                                            (w_ram_read_term),

        .o_data                                                     (w_i2c_to_i2s_data),
        .o_valid                                                    (w_i2c_to_i2s_valid)
    );

    im2systolic                                                     #(
        .DATA_SIZE                                                  (DATA_SIZE),
        .MAX_SYS_PORT                                               (MAX_SYS_PORT),
        .MAX_SYS_HEIGHT                                             (MAX_SYS_HEIGHT),
        .MAX_SYS_WIDTH                                              (MAX_SYS_WIDTH),
        .MAX_DEPTH_SYS                                              (MAX_DEPTH_SYS),
        .MAX_CYCLE                                                  (MAX_CYCLE)
    )                                                               I2S(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),
        .i_terminate                                                (i_terminate),

        .i_enable                                                   (w_i2s_enable),
        .i_read                                                     (w_i2s_read),
        .i_set_param                                                (w_i2s_set_param),
        
        .i_slice_width                                              (i_slice_width),
        .i_slice_height                                             (i_slice_height),

        .o_set_param_done                                           (w_i2s_set_param_done),
        .o_read_done                                                (w_i2s_read_done),
        .i_valid                                                    (w_i2c_to_i2s_valid),
        .i_data                                                     (w_i2c_to_i2s_data),
        .o_image_slice_sys_width                                    (o_image_slice_sys_width),
        .o_data                                                     (o_i2s_data),
        .o_valid                                                    (o_i2s_valid)
    );

    assign o_slice_last         =       w_i2c_slice_last;
    assign o_i2c_data           =       w_i2c_to_i2s_data;
    assign o_i2c_valid          =       w_i2c_to_i2s_valid;
    assign o_i2c_read_done      =       w_i2c_read_done;
    assign o_ram_read_term      =       w_ram_read_term;

endmodule
