`timescale 1ns / 1ps

module tb_tinyNPU();

    parameter                                       DATA_SIZE                   =   8;
    parameter                                       MAX_SYS_PORT                =   3; // Size of Systolic Array
    parameter                                       V_PORT_WIDTH                =   MAX_SYS_PORT;
    parameter                                       H_PORT_WIDTH                =   MAX_SYS_PORT;

    parameter                                       MAX_DEPTH_IMAGE             =   4*4*2; // Depth of Input Image
    parameter                                       MAX_DEPTH_FILTER            =   4*9; // Depth of Input Filter

    parameter                                       MAX_DEPTH_IMAGE_I2C         =   9*8; // Depth after im2col conversion
    parameter                                       MAX_DEPTH_FILTER_F2R        =   4*9; // Depth after fil2row conversion

    parameter                                       MAX_IMAGE_SYS_HEIGHT        =   3; // Height of image slice
    parameter                                       MAX_IMAGE_SYS_WIDTH         =   10; // Width of image slice
    parameter                                       MAX_DEPTH_IMAGE_SLICE       =   3*10; // Depth of image slice
    
    parameter                                       MAX_FILTER_SYS_HEIGHT       =   9;
    parameter                                       MAX_FILTER_SYS_WIDTH        =   2;
    parameter                                       MAX_DEPTH_FILTER_SLICE      =   9*2; // Depth of filter slice

    parameter                                       MAX_IMAGE_SYS_DEPTH         =   MAX_IMAGE_SYS_HEIGHT * MAX_IMAGE_SYS_WIDTH;
    parameter                                       MAX_IMAGE_SYS_CYCLE         =   MAX_IMAGE_SYS_HEIGHT + MAX_IMAGE_SYS_WIDTH - 1;

    parameter                                       MAX_FILTER_SYS_DEPTH        =   MAX_FILTER_SYS_HEIGHT * MAX_FILTER_SYS_WIDTH;
    parameter                                       MAX_FILTER_SYS_CYCLE        =   MAX_FILTER_SYS_HEIGHT + MAX_FILTER_SYS_WIDTH - 1;
    
    parameter                                       BUF_WIDTH                   =   3;
    parameter                                       BUF_HEIGHT                  =   9;
    parameter                                       RAM_DEPTH                   =   BUF_WIDTH * BUF_HEIGHT;

    localparam  [1 : 0]                             MODE_NOP                    =   2'b00;
    localparam  [1 : 0]                             MODE_POOL                   =   2'b01;
    localparam  [1 : 0]                             MODE_MVM                    =   2'b10;
    localparam  [1 : 0]                             MODE_CONV                   =   2'b11;

    reg                                             i_clk                       =   0;
    reg                                             i_n_reset                   =   1;
    reg         [1 : 0]                             i_op_mode                   =   MODE_NOP;
    reg                                             i_terminate                 =   0;
    reg                                             i_output_layer              =   1;
    wire                                            o_done;
    wire        [3 : 0]                             o_state;

    reg         [7 : 0]                             i_image_width               =   0;
    reg         [7 : 0]                             i_image_height              =   0;
    reg         [7 : 0]                             i_image_channel             =   0;
    reg         [7 : 0]                             i_image_slice_width         =   0;
    reg         [7 : 0]                             i_image_slice_height        =   0;
    reg         [7 : 0]                             i_image_slice_number        =   0;
    reg         [7 : 0]                             i_filter_width              =   0;
    reg         [7 : 0]                             i_filter_height             =   0;
    reg         [7 : 0]                             i_filter_channel            =   0;
    reg         [7 : 0]                             i_filter_number             =   0;
    reg         [7 : 0]                             i_filter_slice_width        =   0;
    reg         [7 : 0]                             i_filter_slice_height       =   0;
    reg         [7 : 0]                             i_filter_slice_number       =   0;
    reg         [11 : 0]                            i_output_depth              =   0;

    wire                                            o_im2col_addressing;
    wire        [31 : 0]                            o_im2col_address;
    wire                                            o_rst_image_ram;
    wire                                            o_en_image_ram;
    wire                                            o_image_ram_read_term;
    reg signed  [DATA_SIZE*4 - 1 : 0]               i_ram_to_i2c_data           =   0;
    reg signed  [DATA_SIZE*4 - 1 : 0]               i_ram_to_i2c_data_z         =   0;
    reg                                             i_ram_to_i2c_valid          =   0;
    reg                                             i_ram_to_i2c_valid_z        =   0;

    wire                                            o_rst_filter_ram;
    wire                                            o_en_filter_ram;
    wire                                            o_filter_ram_read_term;
    reg signed  [DATA_SIZE*4 - 1 : 0]               i_ram_to_f2r_data           =   0;
    reg                                             i_ram_to_f2r_valid          =   0;
    reg signed  [DATA_SIZE*4 - 1 : 0]               i_ram_to_f2r_data_z         =   0;
    reg                                             i_ram_to_f2r_valid_z        =   0;

    wire                                            o_wr_result_ram;
    wire signed [DATA_SIZE*4 -1 : 0]                o_data;
    wire                                            o_valid;

    wire                                            o_rst_result_ram;
    wire                                            w_wr_result_ram;
    wire        [3 : 0]                             o_result_wr_ram;
    wire        [31 : 0]                            o_result_ram_addr;
    wire        [31 : 0]                            o_result_ram_data;

    tinyNPU                                         #(
        .DATA_SIZE                                  (DATA_SIZE),
        .MAX_SYS_PORT                               (MAX_SYS_PORT),
        .V_PORT_WIDTH                               (V_PORT_WIDTH),
        .H_PORT_WIDTH                               (H_PORT_WIDTH),
        .MAX_DEPTH_IMAGE                            (MAX_DEPTH_IMAGE),
        .MAX_DEPTH_FILTER                           (MAX_DEPTH_FILTER),
        .MAX_DEPTH_IMAGE_I2C                        (MAX_DEPTH_IMAGE_I2C),
        .MAX_DEPTH_IMAGE_SLICE                      (MAX_DEPTH_IMAGE_SLICE),
        .MAX_DEPTH_FILTER_F2R                       (MAX_DEPTH_FILTER_F2R),
        .MAX_DEPTH_FILTER_SLICE                     (MAX_DEPTH_FILTER_SLICE),
        .MAX_IMAGE_SYS_HEIGHT                       (MAX_IMAGE_SYS_HEIGHT),
        .MAX_IMAGE_SYS_WIDTH                        (MAX_IMAGE_SYS_WIDTH),
        .MAX_FILTER_SYS_HEIGHT                      (MAX_FILTER_SYS_HEIGHT),
        .MAX_FILTER_SYS_WIDTH                       (MAX_FILTER_SYS_WIDTH),
        .MAX_IMAGE_SYS_DEPTH                        (MAX_IMAGE_SYS_DEPTH),
        .MAX_IMAGE_SYS_CYCLE                        (MAX_IMAGE_SYS_CYCLE),
        .MAX_FILTER_SYS_DEPTH                       (MAX_FILTER_SYS_DEPTH),
        .MAX_FILTER_SYS_CYCLE                       (MAX_FILTER_SYS_CYCLE),
        .BUF_WIDTH                                  (BUF_WIDTH),
        .BUF_HEIGHT                                 (BUF_HEIGHT),
        .RAM_DEPTH                                  (RAM_DEPTH)
    )                                               DUT(
        // System
        .i_clk                                      (i_clk),
        .i_n_reset                                  (i_n_reset),

        // AXI
        // 11 : CONV, 10 : FC, 01 : POOL, 00 : IDLE
        .i_terminate                                (i_terminate),
        .i_output_layer                             (i_output_layer),
        .o_done                                     (o_done),
        .o_state                                    (o_state),
        .i_op_mode                                  (i_op_mode),

        .i_image_width                              (i_image_width),
        .i_image_height                             (i_image_height),
        .i_image_channel                            (i_image_channel),

        .i_image_slice_width                        (i_image_slice_width),
        .i_image_slice_height                       (i_image_slice_height),
        .i_image_slice_number                       (i_image_slice_number),

        .i_filter_width                             (i_filter_width),
        .i_filter_height                            (i_filter_height),
        .i_filter_channel                           (i_filter_channel),
        .i_filter_number                            (i_filter_number),

        .i_filter_slice_width                       (i_filter_slice_width),
        .i_filter_slice_height                      (i_filter_slice_height),
        .i_filter_slice_number                      (i_filter_slice_number),
        .i_output_depth                             (i_output_depth),

        // Image RAM
        .o_im2col_addressing                        (o_im2col_addressing),
        .o_im2col_address                           (o_im2col_address),
        .o_en_image_ram                             (o_en_image_ram),
        .o_image_ram_read_term                      (o_image_ram_read_term),
        .i_ram_to_i2c_data                          (i_ram_to_i2c_data_z),
        .i_ram_to_i2c_valid                         (i_ram_to_i2c_valid_z),
        
        // Filter RAM
        .o_en_filter_ram                            (o_en_filter_ram),
        .o_filter_ram_read_term                     (o_filter_ram_read_term),
        .i_ram_to_f2r_data                          (i_ram_to_f2r_data_z),
        .i_ram_to_f2r_valid                         (i_ram_to_f2r_valid_z),

        // Result RAM
        .o_wr_result_ram                            (w_wr_result_ram),
        .o_data                                     (o_data),
        .o_valid                                    (o_valid)
    );

    ram_wr                                          #(
        .WIDTH                                      (32)
    )                                               i_RESULT_RAM_WRITER(
        .i_clk                                      (i_clk),
        .i_n_reset                                  (i_n_reset),
        .i_write                                    (w_wr_result_ram),
        .i_data                                     (o_data),
        .i_data_valid                               (o_valid),
        .o_rst_ram                                  (o_rst_result_ram),
        .o_en_ram                                   (o_wr_result_ram),
        .o_wr_ram                                   (o_result_wr_ram),
        .o_ram_addr                                 (o_result_ram_addr),
        .o_ram_data                                 (o_result_ram_data)
    );

    always #5 i_clk = ~i_clk;
    initial begin
        @(posedge i_clk) i_n_reset = 0;
        @(posedge i_clk) i_n_reset = 1;

        @(posedge i_clk) i_op_mode = MODE_CONV;
        // @(posedge i_clk) i_op_mode = MODE_MVM;
        // @(posedge i_clk) i_op_mode = MODE_POOL;

        @(posedge o_done) #100; $stop();
        @(posedge i_clk) i_terminate = 1; i_op_mode = MODE_NOP;
        @(posedge i_clk) i_terminate = 0;
    end

    // Number of Filter = 1, Channel of Image = 1
    initial begin
        // // Convolve Image   (4 x 4) with Filter     (2 x 2)
        // // MVM      Im2Col  (9 x 4) with Filter2Row (4 x 1)
        // i_image_width               =       4;
        // i_image_height              =       4;
        // i_image_channel             =       1;
        // i_image_slice_width         =       4;
        // i_image_slice_height        =       3;
        // i_image_slice_number        =       3;
        // i_filter_width              =       2;
        // i_filter_height             =       2;
        // i_filter_channel            =       1;
        // i_filter_number             =       1;
        // i_filter_slice_width        =       1;
        // i_filter_slice_height       =       4;
        // i_filter_slice_number       =       1;
        // i_output_depth              =       9;
        
        // // MVM      Vector  (1 x 4) with Matrix (4 x 9)
        // i_image_width               =       4;
        // i_image_height              =       1;
        // i_image_channel             =       1;

        // i_image_slice_width         =       4;
        // i_image_slice_height        =       1;
        // i_image_slice_number        =       1;

        // i_filter_width              =       9;
        // i_filter_height             =       4;
        // i_filter_channel            =       1;
        // i_filter_number             =       1;

        // i_filter_slice_width        =       3;
        // i_filter_slice_height       =       4;
        // i_filter_slice_number       =       3;

        // i_output_depth              =       9;
        
        // // Image     (4 x 4)
        // // Im2Col    (9 x 4)
        // // POOL      (4 x 1)
        // i_image_width               =       4;
        // i_image_height              =       4;
        // i_image_channel             =       1;

        // i_filter_width              =       2;
        // i_filter_height             =       2;
        // i_filter_channel            =       1;
        // i_filter_number             =       1;
        
        // i_output_depth              =       9;
    end
    
    // Number of Filter = 3, Channel of Image = 1
    initial begin
        // // Convolve Image   (4 x 4) with Filter     (3 x 1 x 2 x 2)
        // // MVM      Im2Col  (9 x 4) with Filter2Row (4 x 3)
        // i_image_width               =       4;
        // i_image_height              =       4;
        // i_image_channel             =       1;
        // i_image_slice_width         =       4;
        // i_image_slice_height        =       3;
        // i_image_slice_number        =       3;
        // i_filter_width              =       2;
        // i_filter_height             =       2;
        // i_filter_channel            =       1;
        // i_filter_number             =       3;
        // i_filter_slice_width        =       3;
        // i_filter_slice_height       =       4;
        // i_filter_slice_number       =       1;
        // i_output_depth              =       27;
    end
    
    // Number of Filter = 2, Channel of Image = 2
    initial begin
        // Convolve Image   (1 x 2 x 4 x 4) with Filter     (2 x 2 x 2 x 2)
        // MVM      Im2Col  (4 x 8)         with Filter2Row (8 x 2)
        i_image_width               =       4;
        i_image_height              =       4;
        i_image_channel             =       2;
        
        i_image_slice_width         =       8;
        i_image_slice_height        =       3;
        i_image_slice_number        =       3;

        i_filter_width              =       2;
        i_filter_height             =       2;
        i_filter_channel            =       2;
        i_filter_number             =       2;
        
        i_filter_slice_width        =       2;
        i_filter_slice_height       =       8;
        i_filter_slice_number       =       1;
        
        i_output_depth              =       18;
    end

    integer i;
    reg [7 : 0] IMAGE_RAM [0 : 99];
    reg [7 : 0] FILTER_RAM [0 : 99];

    initial begin
        for (i = 0; i < 100; i = i + 1) begin
            IMAGE_RAM[i] = i + 1;
            FILTER_RAM[i] = i + 1;
        end
    end

    always @(posedge i_clk) begin
        i_ram_to_i2c_data_z <= i_ram_to_i2c_data;
        i_ram_to_i2c_valid_z <= i_ram_to_i2c_valid;
        i_ram_to_f2r_data_z <= i_ram_to_f2r_data;
        i_ram_to_f2r_valid_z <= i_ram_to_f2r_valid;
    end

    always @(posedge i_clk) begin
        if (o_en_image_ram) begin
            if (o_im2col_addressing) begin
                i_ram_to_i2c_data           <=      IMAGE_RAM[o_im2col_address];
            end
            else begin
                i_ram_to_i2c_data           <=      i_ram_to_i2c_data + 1;
            end
            i_ram_to_i2c_valid          <=      1;
        end
        else begin
            i_ram_to_i2c_data <= 0;
            i_ram_to_i2c_valid <= 0;
        end
    end

    always @(posedge i_clk) begin
        if (o_en_filter_ram) begin
            i_ram_to_f2r_data           <=      i_ram_to_f2r_data + 1;
            i_ram_to_f2r_valid          <=      1;
        end
        else begin
            i_ram_to_f2r_data  <= 0;
            i_ram_to_f2r_valid <= 0;
        end
    end


endmodule
