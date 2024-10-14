`timescale 1ns / 1ps

module dequantizer (
    // Dequantize relu data with image scale factor, i_X_s, weight scale factor, i_w_s

    input       wire                                    i_clk,
    input       wire                                    i_n_reset,

    input       wire                [15 : 0]            i_X_s,
    input       wire                [15 : 0]            i_w_s,


    input       wire                [31 : 0]            i_relu,
    input       wire                                    i_valid,

    output      wire                [31 : 0]            o_dequant,
    output      wire                                    o_valid
);
                reg                 [31 : 0]            r_relu;
                reg                 [63 : 0]            r_relu_X_s_w_s;
                reg                 [31 : 0]            r_X_s_w_s;
                reg                 [31 : 0]            r_dequant;
                reg                                     r_valid;
                reg                                     r_valid_z;
                reg                                     r_valid_zz;

// Stage 1, X_s * w_s
// Stage 2, Relu * (X_s * w_s)
// Stage 3, Relu * (X_s * w_s) >> 16

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_relu <= 0;
        r_X_s_w_s <= 0;
    end
    else if (i_valid) begin
        r_relu <= i_relu;
        r_X_s_w_s <= i_X_s * i_w_s;
    end
end

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_relu_X_s_w_s <= 0;
    end
    else if (r_valid) begin
        r_relu_X_s_w_s <= r_relu * r_X_s_w_s;
    end
end

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_dequant <= 0;
    end
    else if (r_valid_z) begin
        r_dequant <= r_relu_X_s_w_s >> 16;
    end
end

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_valid <= 0;
        r_valid_z <= 0;
        r_valid_zz <= 0;
    end
    else begin
        r_valid <= i_valid;
        r_valid_z <= r_valid;
        r_valid_zz <= r_valid_z;
    end
end

assign o_dequant = r_dequant;
assign o_valid = r_valid_zz;
    
endmodule
