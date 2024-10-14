`timescale 1ns / 1ps

module comparator #(
    parameter                                                   DATA_SIZE = 8
)(
    input       wire                                            i_clk,
    input       wire                                            i_n_reset,
    input       wire                                            i_enable,
    input       wire        signed      [DATA_SIZE - 1 : 0]     i_data,
    input       wire                                            i_valid,
    output      wire        signed      [DATA_SIZE - 1 : 0]     o_data,
    output      wire                                            o_valid
    );

                reg                     [1 : 0]                 r_count;
                reg         signed      [DATA_SIZE - 1 : 0]     r_reference;
                reg                                             r_valid;

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_reference <= 0;
        end
        else if (i_enable && i_valid) begin
            if (r_count == 0) begin
                r_reference <= i_data;
            end
            else if (i_data > r_reference) begin
                r_reference <= i_data;
            end
            else begin
                r_reference <= r_reference;
            end
        end
        else begin
            r_reference <= 0;
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_count <= 0;
            r_valid <= 0;
        end
        else if (i_enable && i_valid) begin
            if (r_count >= 3) begin
                r_count <= 0;
                r_valid <= 1;
            end
            else begin
                r_count <= r_count + 1;
                r_valid <= 0;
            end
        end
        else begin
            r_count <= 0;
            r_valid <= 0;
        end
    end

    assign o_data = r_reference;
    assign o_valid = r_valid;

endmodule
