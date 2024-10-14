`timescale 1ns / 1ps

module quantizer (
     // Quantize data with next layer's scale factor, i_X_s
    input       wire                                    i_clk,
    input       wire                                    i_n_reset,
    input       wire                     [31 : 0]       i_X_s,

    input       wire                     [31 : 0]       i_dequant,
    input       wire                                    i_valid,
    
    output      wire                     [7 : 0]        o_quant,
    output      wire                                    o_valid
);

                reg     signed           [31 : 0]       r_quant;
                reg     signed           [7 : 0]        r_quant_clip;
                reg                                     r_valid;

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_quant <= 32'h0;
    end 
    else if (i_valid) begin
        if (i_X_s == 0) begin
            r_quant <=  0;
        end
        else begin
            r_quant <= i_dequant / i_X_s;
        end
    end
    else begin
        r_quant <= 0;
    end
end

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_quant_clip <= 8'h0;
        r_valid <= 0;
    end
    else if (i_valid) begin
        if (i_X_s == 0) begin
            r_quant_clip <= 8'h0;
            r_valid <= 0;
        end
        else begin
            if (r_quant > 127) begin
                r_quant_clip <= 127;
            end
            else if (r_quant < -128) begin
                r_quant_clip <= -128;
            end
            else begin
                r_quant_clip <= r_quant;
            end
            r_valid <= 1;
        end
    end
    else begin
        r_quant_clip <= 0;
        r_valid <= 0;
    end
end

assign o_quant = r_quant_clip;
assign o_valid = r_valid;
    
endmodule
