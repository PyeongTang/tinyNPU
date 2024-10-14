`timescale 1ns / 1ps

module tb_comparator();

    parameter                                       DATA_SIZE   =   8;
    reg                                             i_clk       =   0;
    reg                                             i_n_reset   =   1;
    reg                                             i_enable    =   0;
    reg         signed      [DATA_SIZE - 1 : 0]     i_data      =   4;
    wire        signed      [DATA_SIZE - 1 : 0]     o_data;
    wire                                            o_valid;

    comparator                                      DUT(
        .i_clk                                      (i_clk),
        .i_n_reset                                  (i_n_reset),
        .i_enable                                   (i_enable),
        .i_data                                     (i_data),
        .o_data                                     (o_data),
        .o_valid                                    (o_valid)
    );

    always #5 i_clk = ~i_clk;
    initial begin
        @(posedge i_clk) i_n_reset = 0;
        @(posedge i_clk) i_n_reset = 1;
        @(posedge i_clk) i_enable = 1;
    end

    always @(posedge i_clk) begin
        if (i_enable) begin
            i_data <= $urandom%100;
        end
    end

endmodule
