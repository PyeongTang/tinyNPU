`timescale 1ns / 1ps

module tb_POOL_Block();

parameter                                   DATA_SIZE           =   8;

reg                                         i_clk               =   0;
reg                                         i_n_reset           =   1;
reg                                         i_start_pool        =   0;
reg                                         i_terminate         =   0;
reg                                         i_valid             =   0;
reg     signed      [DATA_SIZE - 1 : 0]     i_data              =   0;
wire    signed      [DATA_SIZE - 1 : 0]     o_data;
wire                                        o_en_local_buffer;
wire                                        o_wr_local_buffer;

    POOL_Block                              #(
        .DATA_SIZE                          (DATA_SIZE)
    )                                       DUT(
        .i_clk                              (i_clk),
        .i_n_reset                          (i_n_reset),
        .i_start_pool                       (i_start_pool),
        .i_terminate                        (i_terminate),
        .i_valid                            (i_valid),
        .i_data                             (i_data),
        .o_data                             (o_data),
        .o_en_local_buffer                  (o_en_local_buffer),
        .o_wr_local_buffer                  (o_wr_local_buffer)
    );

    always #5 i_clk = ~i_clk;
    initial begin
        @(posedge i_clk) i_n_reset = 0;
        @(posedge i_clk) i_n_reset = 1;
        @(posedge i_clk) i_start_pool = 1;

        #1000 i_terminate = 1; $stop();
    end

    always @(posedge i_clk) begin
        if (i_start_pool) begin
            i_data       <=      i_data + 1;
            i_valid      <=      1;
        end
        else begin
            i_data       <=      0;
            i_valid      <=      0;
        end
    end

endmodule
