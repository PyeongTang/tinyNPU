`timescale 1ns / 1ps

module tb_F2R_Block();

parameter                                           DATA_SIZE                   =       8;
parameter                                           MAX_SYS_PORT                =       16;
parameter                                           MAX_SYS_HEIGHT              =       3;
parameter                                           MAX_SYS_WIDTH               =       6;
parameter                                           MAX_DEPTH_FILTER            =       4*1;
parameter                                           MAX_DEPTH_SLICE             =       4*1;
parameter                                           MAX_DEPTH_SYS               =       MAX_SYS_HEIGHT * MAX_SYS_WIDTH;
parameter                                           MAX_CYCLE                   =       MAX_SYS_HEIGHT + MAX_SYS_WIDTH - 1;

reg                                                 i_clk                       =       0;
reg                                                 i_n_reset                   =       1;
reg                                                 i_set_param                 =       0;
reg                                                 i_start_mac                 =       0;

wire                                                o_filter_ready;
wire                                                o_done;

reg                                                 i_mode_conv                 =       0;
reg         [7 : 0]                                 i_filter_width              =       8'h0;
reg         [7 : 0]                                 i_filter_height             =       8'h0;
reg         [7 : 0]                                 i_filter_channel            =       8'h0;
reg         [7 : 0]                                 i_filter_number             =       8'h0;
reg         [7 : 0]                                 i_slice_width               =       8'h0;
reg         [7 : 0]                                 i_slice_height              =       8'h0;
reg         [7 : 0]                                 i_slice_number              =       8'h0;

wire                                                o_en_rom;
reg                                                 i_rom_read_done             =       1'b0;
reg signed [DATA_SIZE-1 : 0]                        i_rom_to_f2r_data           =       8'h0;
reg                                                 i_rom_to_f2r_valid          =       8'h0;

wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]        o_data;
wire                                                o_valid;

    F2R_Block                                       #(
        .DATA_SIZE                                  (DATA_SIZE),
        .MAX_SYS_PORT                               (MAX_SYS_PORT),
        .MAX_SYS_HEIGHT                             (MAX_SYS_HEIGHT),
        .MAX_SYS_WIDTH                              (MAX_SYS_WIDTH),
        .MAX_DEPTH_FILTER                           (MAX_DEPTH_FILTER),
        .MAX_DEPTH_SLICE                            (MAX_DEPTH_SLICE),
        .MAX_DEPTH_SYS                              (MAX_DEPTH_SYS),
        .MAX_CYCLE                                  (MAX_CYCLE)
    )                                               DUT(
        .i_clk                                      (i_clk),
        .i_n_reset                                  (i_n_reset),
        .i_set_param                                (i_set_param),
        .i_start_mac                                (i_start_mac),
        .o_filter_ready                             (o_filter_ready),
        .o_done                                     (o_done),
        .i_mode_conv                                (i_mode_conv),
        .i_filter_width                             (i_filter_width),
        .i_filter_height                            (i_filter_height),
        .i_filter_channel                           (i_filter_channel),
        .i_filter_number                            (i_filter_number),
        .i_slice_width                              (i_slice_width),
        .i_slice_height                             (i_slice_height),
        .i_slice_number                             (i_slice_number),
        .o_en_rom                                   (o_en_rom),
        .i_rom_read_done                            (i_rom_read_done),
        .i_rom_to_f2r_data                          (i_rom_to_f2r_data),
        .i_rom_to_f2r_valid                         (i_rom_to_f2r_valid),
        .o_data                                     (o_data),
        .o_valid                                    (o_valid)
    );

    always #5 i_clk = ~i_clk;
    initial begin
        @(posedge i_clk) i_n_reset = 1'b0;
        @(posedge i_clk) i_n_reset = 1'b1;

        @(posedge i_clk) begin
            i_set_param             <=      1;
            i_mode_conv             <=      1;
            i_filter_width          <=      2;
            i_filter_height         <=      2;
            i_filter_channel        <=      1;
            i_filter_number         <=      1;
            i_slice_width           <=      1;
            i_slice_height          <=      4;
            i_slice_number          <=      1;
        end

        @(posedge i_clk) i_set_param    <=      0;
    end

    always @(posedge i_clk) begin
        if (o_en_rom) begin
            if (i_rom_to_f2r_data >= 3) begin
                i_rom_read_done         <=      1;
            end
            else begin
                i_rom_to_f2r_data       <=      i_rom_to_f2r_data + 1;
                i_rom_to_f2r_valid      <=      1;
            end
        end
        else begin
            i_rom_to_f2r_data       <=      8'h0;
            i_rom_to_f2r_valid      <=      1'b0;
        end
    end

    initial begin
        wait(o_filter_ready);
        @(posedge i_clk) i_start_mac    <=      1;
        @(posedge i_clk) i_start_mac    <=      0;
        $stop();
    end

endmodule
