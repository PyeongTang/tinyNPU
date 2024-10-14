`timescale 1ns / 1ps

module tb_IM2COL_Block();

parameter                                       DATA_SIZE               =   8;
parameter                                       MAX_SYS_PORT            =   16;
parameter                                       FILTER_WIDTH            =   2;
parameter                                       FILTER_HEIGHT           =   2;
parameter                                       MAX_DEPTH_IMAGE         =   4*4;
parameter                                       MAX_DEPTH_OUTPUT        =   9*4;
parameter                                       MAX_DEPTH_SLICE         =   3*4;
parameter                                       MAX_SYS_HEIGHT          =   3;
parameter                                       MAX_SYS_WIDTH           =   6;
parameter                                       MAX_DEPTH_SYS           =   MAX_SYS_HEIGHT * MAX_SYS_WIDTH;
parameter                                       MAX_CYCLE               =   MAX_SYS_HEIGHT + MAX_SYS_WIDTH - 1;

reg                                             i_clk                   =   1'b0;
reg                                             i_n_reset               =   1'b1;
reg                                             i_set_param             =   1'b0;
reg                                             i_start_mac             =   1'b0;
wire                                            o_image_ready;
wire                                            o_done;

reg                                             i_mode_conv             =   1'b1;
reg         [7 : 0]                             i_image_width           =   8'h0;
reg         [7 : 0]                             i_image_height          =   8'h0;
reg         [7 : 0]                             i_image_channel         =   8'h0;
reg         [7 : 0]                             i_slice_width           =   8'h0;
reg         [7 : 0]                             i_slice_height          =   8'h0;
reg         [7 : 0]                             i_slice_number          =   8'h0;

wire                                            o_en_ram;
reg                                             i_ram_read_done         =   1'b0;
reg signed [DATA_SIZE - 1 : 0]                  i_ram_to_i2c_data       =   8'h0;
reg                                             i_ram_to_i2c_valid      =   1'b0;

wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    o_data;
wire                                            o_valid;

    IM2COL_Block                                #(
        .DATA_SIZE                              (DATA_SIZE),
        .MAX_SYS_PORT                           (MAX_SYS_PORT),
        .FILTER_WIDTH                           (FILTER_WIDTH),
        .FILTER_HEIGHT                          (FILTER_HEIGHT),
        .MAX_DEPTH_IMAGE                        (MAX_DEPTH_IMAGE),
        .MAX_DEPTH_OUTPUT                       (MAX_DEPTH_OUTPUT),
        .MAX_DEPTH_SLICE                        (MAX_DEPTH_SLICE),
        .MAX_SYS_HEIGHT                         (MAX_SYS_HEIGHT),
        .MAX_SYS_WIDTH                          (MAX_SYS_WIDTH),
        .MAX_DEPTH_SYS                          (MAX_DEPTH_SYS),
        .MAX_CYCLE                              (MAX_CYCLE)
    )                                           DUT(
        .i_clk                                  (i_clk),
        .i_n_reset                              (i_n_reset),
        .i_set_param                            (i_set_param),
        .i_start_mac                            (i_start_mac),
        .o_done                                 (o_done),
        .o_image_ready                          (o_image_ready),
        .i_mode_conv                            (i_mode_conv),
        .i_image_width                          (i_image_width),
        .i_image_height                         (i_image_height),
        .i_image_channel                        (i_image_channel),
        .i_slice_width                          (i_slice_width),
        .i_slice_height                         (i_slice_height),
        .i_slice_number                         (i_slice_number),
        .o_en_ram                               (o_en_ram),
        .i_ram_read_done                        (i_ram_read_done),
        .i_ram_to_i2c_data                      (i_ram_to_i2c_data),
        .i_ram_to_i2c_valid                     (i_ram_to_i2c_valid),
        .o_data                                 (o_data),
        .o_valid                                (o_valid)
    );

    always #5 i_clk = ~i_clk;
    initial begin
        @(posedge i_clk) i_n_reset = 1'b0;
        @(posedge i_clk) i_n_reset = 1'b1;

        @(posedge i_clk) begin
            i_set_param             <=      1;
            i_mode_conv             <=      1;
            i_image_width           <=      4;
            i_image_height          <=      4;
            i_image_channel         <=      1;
            i_slice_width           <=      4;
            i_slice_height          <=      3;
            i_slice_number          <=      3;
        end

        @(posedge i_clk) i_set_param    <=      0;
    end

    always @(posedge i_clk) begin
        if (o_en_ram) begin
            if (i_ram_to_i2c_data >= 15) begin
                i_ram_read_done         <=      1;
            end
            else begin
                i_ram_to_i2c_data       <=      i_ram_to_i2c_data + 1;
                i_ram_to_i2c_valid      <=      1;
            end
        end
        else begin
            i_ram_to_i2c_data       <=      8'h0;
            i_ram_to_i2c_valid      <=      1'b0;
        end
    end

    initial begin
        wait(o_image_ready);
        @(posedge i_clk) i_start_mac    <=      1;
        @(posedge i_clk) i_start_mac    <=      0;
        $stop();
    end

endmodule
