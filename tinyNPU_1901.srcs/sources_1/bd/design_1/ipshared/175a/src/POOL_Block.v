`timescale 1ns / 1ps

module POOL_Block #(
    parameter                                           DATA_SIZE = 8
)(
    input       wire                                    i_clk,
    input       wire                                    i_n_reset,
    input       wire                                    i_start_pool,

    input       wire                                    i_valid,
    input       wire    signed  [DATA_SIZE - 1 : 0]     i_data,

    output      wire                                    o_valid,
    output      wire    signed  [DATA_SIZE - 1 : 0]     o_data,

    output      wire                                    o_en_local_buffer,
    output      wire                                    o_wr_local_buffer
);

    comparator                                          #(
        .DATA_SIZE                                      (DATA_SIZE)
    )                                                   MAX_POOL(
        .i_clk                                          (i_clk),
        .i_n_reset                                      (i_n_reset),
        .i_enable                                       (i_start_pool),
        .i_data                                         (i_data),
        .i_valid                                        (i_valid),
        .o_data                                         (o_data),
        .o_valid                                        (o_valid)
    );

    assign {o_en_local_buffer, o_wr_local_buffer} = {o_valid, o_valid};

endmodule
