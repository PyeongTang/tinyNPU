`timescale 1ns / 1ps

module dequantizer (
    // Dequantize relu data with image scale factor, i_X_s, weight scale factor, i_w_s

    input       wire                                  i_n_reset,

    input       wire                  [31 : 0]        i_X_s,
    input       wire                  [31 : 0]        i_w_s,


    input       wire                  [31 : 0]        i_relu,
    output      wire                  [31 : 0]        o_dequant
);

reg     [31 : 0]        r_dequant;

always @(*) begin
    if (!i_n_reset) begin
        r_dequant = 0;
    end
    else begin
        r_dequant = (i_relu * i_X_s [15 : 0] * i_w_s [15 : 0]) >> 16;
    end
end

assign o_dequant  = r_dequant;
    
endmodule
