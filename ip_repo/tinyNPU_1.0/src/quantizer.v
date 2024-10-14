`timescale 1ns / 1ps

module quantizer (
     // Quantize data with next layer's scale factor, i_X_s

    input      wire                     [31 : 0]       i_X_s,
    input      wire                                    rst_n,

    input      wire                     [31 : 0]       i_dequant,
    output     wire                     [7 : 0]        o_quant
);

reg     signed                          [31 : 0]       r_quant;
reg     signed                          [7 : 0]        r_quant_clip;

always @(*) begin
   if (!rst_n) begin
        r_quant     =    32'h0;
   end 
   else begin
          if (i_X_s == 0) begin
               r_quant = 0;
          end
          else begin
               r_quant     =    i_dequant / i_X_s;
          end
   end
end

always @(*) begin
     if (!rst_n) begin
          r_quant_clip   =    8'h0;
     end
     else begin
          if (i_X_s == 0) begin
               r_quant_clip   =    8'h0;
          end
          else begin
               if (r_quant > 127) begin
                    r_quant_clip = 127;
               end
               else if (r_quant < -128) begin
                    r_quant_clip = -128;
               end
               else begin
                    r_quant_clip = r_quant;
               end
          end
     end
end

assign o_quant    =       r_quant_clip;
    
endmodule
