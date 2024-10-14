`timescale 1ns / 1ps

module pe #(
    parameter                                       DATA_SIZE = 8
)(
    input       wire                                i_clk,
    input       wire                                i_n_reset,

    input       wire                                i_enable,
    input       wire                                i_valid,

    input       wire signed [DATA_SIZE - 1 : 0]     i_data_v,
    input       wire signed [DATA_SIZE - 1 : 0]     i_data_h,
    output      wire signed [DATA_SIZE*4-1 : 0]     o_data_sum,

    output      wire signed [DATA_SIZE - 1 : 0]     o_data_v,
    output      wire signed [DATA_SIZE - 1 : 0]     o_data_h
);
                reg signed  [DATA_SIZE - 1  : 0]    r_data_v;
                reg signed  [DATA_SIZE - 1  : 0]    r_data_h;
                reg signed  [DATA_SIZE*4-1  : 0]    r_data_sum;

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_data_h    <= {DATA_SIZE{1'b0}};
            r_data_v    <= {DATA_SIZE{1'b0}};
            r_data_sum  <= {DATA_SIZE*4{1'b0}};
        end
        else begin
            if (i_enable) begin
                if (i_valid) begin
                    r_data_sum  <=  r_data_sum + i_data_h * i_data_v;
                    r_data_h    <=  i_data_h;
                    r_data_v    <=  i_data_v;
                end
            end
            else begin
                r_data_h    <= {DATA_SIZE{1'b0}};
                r_data_v    <= {DATA_SIZE{1'b0}};
                r_data_sum  <= {32{1'b0}};
            end
        end
    end

    assign o_data_sum   = r_data_sum;
    assign o_data_h     = r_data_h;
    assign o_data_v     = r_data_v;

endmodule
