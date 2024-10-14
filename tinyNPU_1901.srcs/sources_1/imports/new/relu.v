`timescale 1ns / 1ps

module relu (
    input       wire                                i_clk,
    input       wire                                i_n_reset,
    input       wire        signed      [31 : 0]    i_acc,
    input       wire                                i_valid,
    output      wire                    [31 : 0]    o_relu,
    output      wire                                o_valid
);

                reg                     [31 : 0]    r_relu;
                reg                                 r_valid;

always @(posedge i_clk) begin
    if (!i_n_reset) begin
        r_relu <= 0;
        r_valid <= 0;
    end
    else if (i_valid) begin
        if (i_acc > 0) begin
            r_relu <= i_acc;
        end
        else begin
            r_relu <= 0;
        end
        r_valid <= 1;
    end
    else begin
        r_relu <= 0;
        r_valid <= 0;
    end
end

assign o_relu   =   r_relu;
assign o_valid  =   r_valid;
    
endmodule
