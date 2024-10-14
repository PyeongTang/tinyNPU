`timescale 1ns / 1ps

module tb_PU_Block();

parameter                                       DATA_SIZE               =   8;
parameter                                       MAX_SYS_PORT            =   16;

reg                                             i_clk                   =   0;
reg                                             i_n_reset               =   1;
reg                                             i_set_param             =   0;
reg                                             i_start_mac             =   0;
reg                                             i_mac_again             =   0;
reg                                             i_flush                 =   0;

wire                                            o_pu_ready;
wire                                            o_mac_done;

reg         [7 : 0]                             i_pu_sys_usage_height   =   0;
reg         [7 : 0]                             i_pu_sys_usage_width    =   0;
reg         [8 : 0]                             i_pu_cycle_horizontal   =   0;
reg         [8 : 0]                             i_pu_cycle_vertical     =   0;

reg signed  [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    i_i2s_data              =   {DATA_SIZE*MAX_SYS_PORT{1'b0}};
reg                                             i_i2s_valid             =   0;

reg signed  [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    i_f2s_data              =   {DATA_SIZE*MAX_SYS_PORT{1'b0}};
reg                                             i_f2s_valid             =   0;

wire signed [DATA_SIZE*4 - 1 : 0]               o_pu_data;
reg signed  [DATA_SIZE - 1 : 0]                 i_dqr_data              =   8'h0;

wire signed [DATA_SIZE - 1 : 0]                 o_data;
wire                                            o_valid;

    PU_Block                                    #(
        .DATA_SIZE                              (DATA_SIZE),
        .MAX_SYS_PORT                           (MAX_SYS_PORT)
    )                                           DUT(
        .i_clk                                  (i_clk),
        .i_n_reset                              (i_n_reset),
        .i_set_param                            (i_set_param),
        .i_start_mac                            (i_start_mac),
        .o_pu_ready                             (o_pu_ready),
        .o_mac_done                             (o_mac_done),
        .i_mac_again                            (i_mac_again),
        .i_flush                                (i_flush),
        .i_pu_sys_usage_height                  (i_pu_sys_usage_height),
        .i_pu_sys_usage_width                   (i_pu_sys_usage_width),
        .i_pu_cycle_horizontal                  (i_pu_cycle_horizontal),
        .i_pu_cycle_vertical                    (i_pu_cycle_vertical),
        .i_i2s_data                             (i_i2s_data),
        .i_i2s_valid                            (i_i2s_valid),
        .i_f2s_data                             (i_f2s_data),
        .i_f2s_valid                            (i_f2s_valid),
        .o_pu_data                              (o_pu_data),
        .i_dqr_data                             (i_dqr_data),
        .o_data                                 (o_data),
        .o_valid                                (o_valid)
    );

    always #5 i_clk = ~i_clk;
    initial begin
        @(posedge i_clk) i_n_reset = 1'b0;
        @(posedge i_clk) i_n_reset = 1'b1;

        @(posedge i_clk) begin
            i_set_param                 <=      1;
            i_pu_sys_usage_height       <=      3;
            i_pu_sys_usage_width        <=      1;
            i_pu_cycle_horizontal       <=      6;
            i_pu_cycle_vertical         <=      4;
        end

        @(posedge i_clk) i_set_param    <=      0;
    end

    always @(posedge i_clk) begin
        if (o_pu_ready) begin
            i_start_mac <= 1;
        end
        else begin
            i_start_mac <= 0;
        end
    end

    initial begin
        wait(i_start_mac)
        @(posedge i_clk)    i_i2s_valid <=  1;  i_i2s_data  <=  {8'h1};
                            i_f2s_valid <=  1;  i_f2s_data  <=  {8'h1};

        @(posedge i_clk)    i_i2s_valid <=  1;  i_i2s_data  <=  {8'h2, 8'h2};
                            i_f2s_valid <=  1;  i_f2s_data  <=  {8'h1, 8'h2};

        @(posedge i_clk)    i_i2s_valid <=  1;  i_i2s_data  <=  {8'h3, 8'h3, 8'h5};
                            i_f2s_valid <=  1;  i_f2s_data  <=  {8'h1, 8'h2, 8'h3};

        @(posedge i_clk)    i_i2s_valid <=  1;  i_i2s_data  <=  {8'h4, 8'h6, 8'h6};
                            i_f2s_valid <=  1;  i_f2s_data  <=  {8'h2, 8'h3, 8'h3};

        @(posedge i_clk)    i_i2s_valid <=  1;  i_i2s_data  <=  {8'h7, 8'h7, 8'h0};
                            i_f2s_valid <=  1;  i_f2s_data  <=  {8'h3, 8'h3, 8'h0};

        @(posedge i_clk)    i_i2s_valid <=  1;  i_i2s_data  <=  {8'h0, 8'h8, 8'h0, 8'h0};
                            i_f2s_valid <=  1;  i_f2s_data  <=  {8'h3, 8'h0, 8'h0};
    end

endmodule
