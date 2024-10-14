`timescale 1ns / 1ps

module DQR_Block(
    input           wire                            i_n_reset,
    input           wire                            i_output_layer,
    input           wire                [31 : 0]    i_deq_X_s,
    input           wire                [31 : 0]    i_deq_w_s,
    input           wire                [31 : 0]    i_q_X_s,
    input           wire    signed      [31 : 0]    i_data,
    output          wire                [31 : 0]    o_data
);

                    wire                [31 : 0]    w_relu_data;
                    wire                [31 : 0]    w_deq_data;
                    wire                [7 : 0]     w_q_data;

    relu                                            i_RELU(
        .i_acc                                      (i_data),
        .o_relu                                     (w_relu_data)
    );

    dequantizer                                     i_DEQ(
        .i_n_reset                                  (i_n_reset),
        .i_X_s                                      (i_deq_X_s),
        .i_w_s                                      (i_deq_w_s),
        .i_relu                                     (w_relu_data),
        .o_dequant                                  (w_deq_data)
    );

    quantizer                                       i_Q(
        .i_X_s                                      (i_q_X_s),
        .rst_n                                      (i_n_reset),
        .i_dequant                                  (w_deq_data),
        .o_quant                                    (w_q_data)
    );

    assign o_data = (i_output_layer) ? (w_relu_data) : ({24'h0, w_q_data});

endmodule
