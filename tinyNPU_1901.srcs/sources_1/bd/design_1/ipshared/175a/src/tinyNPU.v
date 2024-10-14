`timescale 1ns / 1ps

module tinyNPU#(
        parameter                                                   DATA_SIZE               =   8,
        parameter                                                   MAX_SYS_PORT            =   3, // Size of Systolic Array
        parameter                                                   V_PORT_WIDTH            =   MAX_SYS_PORT,
        parameter                                                   H_PORT_WIDTH            =   MAX_SYS_PORT,

        parameter                                                   MAX_DEPTH_IMAGE         =   4*4*2, // Depth of Input Image
        parameter                                                   MAX_DEPTH_FILTER        =   4*9, // Depth of Input Filter

        parameter                                                   MAX_DEPTH_IMAGE_I2C     =   9*8, // Depth after im2col conversion
        parameter                                                   MAX_DEPTH_FILTER_F2R    =   4*9, // Depth after fil2row conversion

        parameter                                                   MAX_IMAGE_SYS_HEIGHT    =   3, // Height of image slice
        parameter                                                   MAX_IMAGE_SYS_WIDTH     =   10, // Width of image slice
        parameter                                                   MAX_DEPTH_IMAGE_SLICE   =   3*10, // Depth of image slice
        
        parameter                                                   MAX_FILTER_SYS_HEIGHT   =   9,
        parameter                                                   MAX_FILTER_SYS_WIDTH    =   2,
        parameter                                                   MAX_DEPTH_FILTER_SLICE  =   9*2, // Depth of filter slice

        parameter                                                   MAX_IMAGE_SYS_DEPTH     =   MAX_IMAGE_SYS_HEIGHT * MAX_IMAGE_SYS_WIDTH,
        parameter                                                   MAX_IMAGE_SYS_CYCLE     =   MAX_IMAGE_SYS_HEIGHT + MAX_IMAGE_SYS_WIDTH - 1,

        parameter                                                   MAX_FILTER_SYS_DEPTH    =   MAX_FILTER_SYS_HEIGHT * MAX_FILTER_SYS_WIDTH,
        parameter                                                   MAX_FILTER_SYS_CYCLE    =   MAX_FILTER_SYS_HEIGHT + MAX_FILTER_SYS_WIDTH - 1,
     
        parameter                                                   BUF_WIDTH               =   3,
        parameter                                                   BUF_HEIGHT              =   9,
        parameter                                                   RAM_DEPTH               =   BUF_WIDTH * BUF_HEIGHT
    )(
        // System
        input       wire                                            i_clk,
        input       wire                                            i_n_reset,

        // AXI
        // 11 : CONV, 10 : FC, 01 : POOL, 00 : IDLE
        input       wire                                            i_output_layer,
        input       wire                                            i_terminate,
        output      wire                                            o_done,
        output      wire        [3 : 0]                             o_state,

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

        // Image RAM
        output      wire                                            o_im2col_addressing,
        output      wire        [31 : 0]                            o_im2col_address,
        output      wire                                            o_en_image_ram,
        output      wire                                            o_image_ram_read_term,
        input       wire signed [31 : 0]                            i_ram_to_i2c_data,
        input       wire                                            i_ram_to_i2c_valid,

        // Filter RAM
        output      wire                                            o_en_filter_ram,
        output      wire                                            o_filter_ram_read_term,
        input       wire signed [31 : 0]                            i_ram_to_f2r_data,
        input       wire                                            i_ram_to_f2r_valid,

        // Result RAM
        output      wire                                            o_wr_result_ram,
        output      wire signed [31 : 0]                            o_data,
        output      wire                                            o_valid
    );
                    localparam  [1 : 0]                             MODE_NOP        =   2'b00;
                    localparam  [1 : 0]                             MODE_POOL       =   2'b01;
                    localparam  [1 : 0]                             MODE_MVM        =   2'b10;
                    localparam  [1 : 0]                             MODE_CONV       =   2'b11;

                    localparam  [1 : 0]                             BUF_SEL_NONE    =   2'b00;
                    localparam  [1 : 0]                             BUF_SEL_PU      =   2'b01;
                    localparam  [1 : 0]                             BUF_SEL_POOL    =   2'b10;
                    localparam  [1 : 0]                             BUF_SEL_CTRL    =   2'b11;

                    wire                                            w_im2col_set_param;
                    wire                                            w_f2r_set_param;
                    wire                                            w_pu_set_param;

                    wire                                            w_image_ready;
                    wire                                            w_filter_ready;
                    wire                                            w_pu_ready;

                    wire                                            w_i2c_slice_last;
                    wire                                            w_f2r_slice_last;

                    wire                                            w_start_mac;
                    wire                                            w_start_pool;

                    wire                                            w_i2c_done;
                    wire                                            w_f2r_done;
                    wire                                            w_pu_mac_done;

                    wire                                            w_i2c_term;
                    wire                                            w_f2r_term;
                    wire                                            w_pu_term;
                    wire                                            w_pool_term;

                    wire signed [DATA_SIZE-1 : 0]                   w_i2c_data;
                    wire                                            w_i2c_read_done;
                    reg                                             r_i2c_read_done_z;
        
                    wire        [7 : 0]                             w_i2s_sys_width;
                    wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    w_i2s_data;
                    wire                                            w_i2s_valid;
        
                    wire        [7 : 0]                             w_f2s_sys_height;
                    wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    w_f2s_data;
                    wire                                            w_f2s_valid;

                    wire signed [DATA_SIZE*4 - 1 : 0]               w_pu_data;
                    wire                                            w_pu_valid;

                    wire signed [DATA_SIZE - 1 : 0]                 w_pool_data;
                    wire                                            w_pool_valid;
                    
                    wire        [31 : 0]                            w_dqr_data;
                    wire                                            w_dqr_valid;

                    wire                                            w_en_local_buffer_pu;
                    wire                                            w_wr_local_buffer_pu;
                    
                    wire                                            w_en_local_buffer_pool;
                    wire                                            w_wr_local_buffer_pool;

                    wire                                            w_en_local_buffer_ctrl;

                    wire                                            w_en_local_buffer;
                    wire                                            w_wr_local_buffer;

                    wire        [1 : 0]                             w_sel_local_buffer;

                    wire signed [DATA_SIZE*4 - 1 : 0]               w_local_buffer_data_in;
                    wire signed [DATA_SIZE*4 - 1 : 0]               w_local_buffer_data_out;

                    reg         [clogb2(RAM_DEPTH) - 1 : 0]         r_local_buffer_addr_pu;
                    reg         [clogb2(RAM_DEPTH) - 1 : 0]         r_local_buffer_addr_pool;
                    reg         [clogb2(RAM_DEPTH) - 1 : 0]         r_local_buffer_addr_ctrl;
                    wire        [clogb2(RAM_DEPTH) - 1 : 0]         w_local_buffer_addr;

                    reg                                             r_local_buffer_data_valid;
                    reg                                             r_local_buffer_read_done;
                    wire                                            w_local_buffer_read_done;

                    reg                                             r_ram_to_i2c_valid_z;
                    reg                                             r_ram_to_f2r_valid_z;

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_ram_to_i2c_valid_z    <=  0;
            r_ram_to_f2r_valid_z    <=  0;
        end
        else begin
            r_ram_to_i2c_valid_z    <=  i_ram_to_i2c_valid;
            r_ram_to_f2r_valid_z    <=  i_ram_to_f2r_valid;
        end
    end

    npu_control                                                     LOCAL_CTRL(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),

        .i_op_mode                                                  (i_op_mode),
        .i_terminate                                                (i_terminate),

        .o_im2col_set_param                                         (w_im2col_set_param),
        .o_f2r_set_param                                            (w_f2r_set_param),
        .o_pu_set_param                                             (w_pu_set_param),

        .i_image_ready                                              (w_image_ready),
        .i_filter_ready                                             (w_filter_ready),
        .i_pu_ready                                                 (w_pu_ready),

        .i_i2c_slice_last                                           (w_i2c_slice_last),
        .i_f2r_slice_last                                           (w_f2r_slice_last),

        .o_start_mac                                                (w_start_mac),
        .o_start_pool                                               (w_start_pool),
        .i_pu_mac_done                                              (w_pu_mac_done),

        .i_pool_done                                                (r_i2c_read_done_z),
        .o_i2c_term                                                 (w_i2c_term),
        .o_f2r_term                                                 (w_f2r_term),
        .o_pu_term                                                  (w_pu_term),
        .o_pool_term                                                (w_pool_term),

        .o_sel_local_buffer                                         (w_sel_local_buffer),
        .o_en_local_buffer                                          (w_en_local_buffer_ctrl),
        .i_local_buffer_read_done                                   (w_local_buffer_read_done),
        .o_state                                                    (o_state),
        .o_done                                                     (o_done)
    );

    IM2COL_Block                                                    #(
        .DATA_SIZE                                                  (DATA_SIZE),
        .MAX_SYS_PORT                                               (MAX_SYS_PORT),
        .MAX_DEPTH_IMAGE                                            (MAX_DEPTH_IMAGE),
        .MAX_DEPTH_OUTPUT                                           (MAX_DEPTH_IMAGE_I2C),
        .MAX_DEPTH_SLICE                                            (MAX_DEPTH_IMAGE_SLICE),
        .MAX_SYS_HEIGHT                                             (MAX_IMAGE_SYS_HEIGHT),
        .MAX_SYS_WIDTH                                              (MAX_IMAGE_SYS_WIDTH),
        .MAX_DEPTH_SYS                                              (MAX_IMAGE_SYS_DEPTH),
        .MAX_CYCLE                                                  (MAX_IMAGE_SYS_CYCLE)
    )                                                               i_IM2COL(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),
        .i_set_param                                                (w_im2col_set_param),
        .i_start_mac                                                (w_start_mac),
        .i_start_pool                                               (w_start_pool),
        .i_terminate                                                (w_i2c_term),
        .o_image_ready                                              (w_image_ready),
        .o_slice_last                                               (w_i2c_slice_last),
        .o_done                                                     (w_i2c_done),

        .i_op_mode                                                  (i_op_mode),
        .i_image_width                                              (i_image_width),
        .i_image_height                                             (i_image_height),
        .i_image_channel                                            (i_image_channel),
        .i_filter_width                                             (i_filter_width),
        .i_filter_height                                            (i_filter_height),
        .i_slice_width                                              (i_image_slice_width),
        .i_slice_height                                             (i_image_slice_height),
        .i_slice_number                                             (i_image_slice_number),

        .o_en_ram                                                   (o_en_image_ram),
        .o_im2col_addressing                                        (o_im2col_addressing),
        .o_im2col_address                                           (o_im2col_address),

        .i_ram_to_i2c_data                                          (i_ram_to_i2c_data[7 : 0]),
        .i_ram_to_i2c_valid                                         (i_ram_to_i2c_valid),
        .o_ram_read_term                                            (o_image_ram_read_term),
        .o_image_slice_sys_width                                    (w_i2s_sys_width),
        .o_i2s_data                                                 (w_i2s_data),
        .o_i2s_valid                                                (w_i2s_valid),
        .o_i2c_data                                                 (w_i2c_data),
        .o_i2c_valid                                                (w_i2c_valid),
        .o_i2c_read_done                                            (w_i2c_read_done)
    );

    F2R_Block                                                       #(
        .DATA_SIZE                                                  (DATA_SIZE),
        .MAX_SYS_PORT                                               (MAX_SYS_PORT),
        .MAX_DEPTH_FILTER                                           (MAX_DEPTH_FILTER),
        .MAX_DEPTH_SLICE                                            (MAX_DEPTH_FILTER_SLICE),
        .MAX_SYS_HEIGHT                                             (MAX_FILTER_SYS_HEIGHT),
        .MAX_SYS_WIDTH                                              (MAX_FILTER_SYS_WIDTH),
        .MAX_DEPTH_SYS                                              (MAX_FILTER_SYS_DEPTH),
        .MAX_CYCLE                                                  (MAX_FILTER_SYS_CYCLE)
    )                                                               i_FILTER2ROW(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),

        .i_set_param                                                (w_f2r_set_param),
        .i_start_mac                                                (w_start_mac),
        .i_terminate                                                (w_f2r_term),

        .o_filter_ready                                             (w_filter_ready),
        .o_slice_last                                               (w_f2r_slice_last),
        .o_done                                                     (w_f2r_done),

        .i_op_mode                                                  (i_op_mode),
        .i_filter_width                                             (i_filter_width),
        .i_filter_height                                            (i_filter_height),
        .i_filter_channel                                           (i_filter_channel),
        .i_filter_number                                            (i_filter_number),
        .i_slice_width                                              (i_filter_slice_width),
        .i_slice_height                                             (i_filter_slice_height),
        .i_slice_number                                             (i_filter_slice_number),

        .o_en_ram                                                   (o_en_filter_ram),
        .o_ram_read_term                                            (o_filter_ram_read_term),
        .i_ram_to_f2r_data                                          (i_ram_to_f2r_data),
        .i_ram_to_f2r_valid                                         (i_ram_to_f2r_valid),
        .o_filter_slice_sys_height                                  (w_f2s_sys_height),
        .o_data                                                     (w_f2s_data),
        .o_valid                                                    (w_f2s_valid)
    );

    PU_Block                                                        #(
        .DATA_SIZE                                                  (DATA_SIZE),
        .MAX_SYS_PORT                                               (MAX_SYS_PORT),
        .V_PORT_WIDTH                                               (V_PORT_WIDTH),
        .H_PORT_WIDTH                                               (H_PORT_WIDTH)
    )                                                               i_PU(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),

        .i_set_param                                                (w_pu_set_param),
        .i_start_mac                                                (w_start_mac),
        .o_pu_ready                                                 (w_pu_ready),
        .o_mac_done                                                 (w_pu_mac_done),

        .i_terminate                                                (w_pu_term),
        .i_pu_sys_usage_height                                      (i_image_slice_height),
        .i_pu_sys_usage_width                                       (i_filter_slice_width),
        .i_pu_cycle_horizontal                                      (w_i2s_sys_width),
        .i_pu_cycle_vertical                                        (w_f2s_sys_height),
        .i_i2s_data                                                 (w_i2s_data),
        .i_i2s_valid                                                (w_i2s_valid),
        .i_f2s_data                                                 (w_f2s_data),
        .i_f2s_valid                                                (w_f2s_valid),
        .o_pu_data                                                  (w_pu_data),
        .o_valid                                                    (w_pu_valid),
        .o_en_local_buffer                                          (w_en_local_buffer_pu),
        .o_wr_local_buffer                                          (w_wr_local_buffer_pu)
    );

    POOL_Block                                                      #(
        .DATA_SIZE                                                  (DATA_SIZE)
    )                                                               i_MAXPOOL(
        .i_clk                                                      (i_clk),
        .i_n_reset                                                  (i_n_reset),

        .i_start_pool                                               (w_start_pool),
        .i_valid                                                    (w_i2c_valid),
        .i_data                                                     (w_i2c_data),
        .o_data                                                     (w_pool_data),
        .o_valid                                                    (w_pool_valid),

        .o_en_local_buffer                                          (w_en_local_buffer_pool),
        .o_wr_local_buffer                                          (w_wr_local_buffer_pool)
    );
    
    bram                                                            #(
        .RAM_WIDTH                                                  (DATA_SIZE*4),
        .RAM_DEPTH                                                  (RAM_DEPTH),
        .INIT_FILE                                                  ("")
    )                                                               LOCAL_BUFFER(
        .clka                                                       (i_clk),
        .flush                                                      (i_terminate),
        .ena                                                        (w_en_local_buffer),
        .wea                                                        (w_wr_local_buffer),
        .addra                                                      (w_local_buffer_addr),
        .dina                                                       (w_local_buffer_data_in),
        .douta                                                      (w_local_buffer_data_out)
    );

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_i2c_read_done_z <= 0;
        end
        else begin
            r_i2c_read_done_z <= w_i2c_read_done;
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_local_buffer_addr_pu <= 0;
        end
        else if (i_terminate) begin
            r_local_buffer_addr_pu <= 0;
        end
        else begin
            if (w_pu_valid && w_en_local_buffer_pu && r_local_buffer_addr_pu < RAM_DEPTH) begin
                r_local_buffer_addr_pu <= r_local_buffer_addr_pu + 1;
            end
        end
    end
    
    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_local_buffer_addr_pool <= 0;
        end
        else if (i_terminate) begin
            r_local_buffer_addr_pool <= 0;
        end
        else begin
            if (w_pool_valid && w_en_local_buffer_pool && r_local_buffer_addr_pool < RAM_DEPTH) begin
                r_local_buffer_addr_pool <= r_local_buffer_addr_pool + 1;
            end
        end
    end
    
    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_local_buffer_addr_ctrl <= 0;
            r_local_buffer_read_done <= 0;
            r_local_buffer_data_valid <= 0;
        end
        else if (i_terminate) begin
            r_local_buffer_addr_ctrl <= 0;
            r_local_buffer_read_done <= 0;
            r_local_buffer_data_valid <= 0;
        end
        else if (w_en_local_buffer_ctrl && !r_local_buffer_read_done) begin
            if (r_local_buffer_addr_ctrl >= i_output_depth) begin
                r_local_buffer_addr_ctrl <= 0;
                r_local_buffer_read_done <= 1;
                r_local_buffer_data_valid <= 0;
            end
            else begin
                r_local_buffer_addr_ctrl <= r_local_buffer_addr_ctrl + 1;
                r_local_buffer_read_done <= 0;
                r_local_buffer_data_valid <= 1;
            end
        end
    end

    assign w_en_local_buffer        =   (w_sel_local_buffer == BUF_SEL_NONE)    ?   (1'bz)                      :
                                        (w_sel_local_buffer == BUF_SEL_PU)      ?   (w_en_local_buffer_pu)      :
                                        (w_sel_local_buffer == BUF_SEL_POOL)    ?   (w_en_local_buffer_pool)    :
                                        (w_sel_local_buffer == BUF_SEL_CTRL)    ?   (w_en_local_buffer_ctrl)    :   (1'bz);

    assign w_wr_local_buffer        =   (w_sel_local_buffer == BUF_SEL_NONE)    ?   (1'bz)                      :
                                        (w_sel_local_buffer == BUF_SEL_PU)      ?   (w_wr_local_buffer_pu)      :
                                        (w_sel_local_buffer == BUF_SEL_POOL)    ?   (w_wr_local_buffer_pool)    :   (1'bz);
    
    assign w_local_buffer_addr      =   (w_sel_local_buffer == BUF_SEL_NONE)    ?   ('bz)                       :
                                        (w_sel_local_buffer == BUF_SEL_PU)      ?   (r_local_buffer_addr_pu)    :
                                        (w_sel_local_buffer == BUF_SEL_POOL)    ?   (r_local_buffer_addr_pool)  :
                                        (w_sel_local_buffer == BUF_SEL_CTRL)    ?   (r_local_buffer_addr_ctrl)  :   ('bz);

    assign w_local_buffer_data_in   =   (w_sel_local_buffer == BUF_SEL_NONE)    ?   (32'hz)                     :
                                        // (w_sel_local_buffer == BUF_SEL_PU)      ?   (w_dqr_data)                :
                                        (w_sel_local_buffer == BUF_SEL_PU)      ?   (w_pu_data )                :
                                        (w_sel_local_buffer == BUF_SEL_POOL)    ?   ({24'h0, w_pool_data})      :   (32'hz);

    assign w_local_buffer_read_done =   r_local_buffer_read_done;

    assign o_wr_result_ram          =   w_en_local_buffer_ctrl;
    assign o_data                   =   w_local_buffer_data_out;
    assign o_valid                  =   r_local_buffer_data_valid;

    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction

endmodule
