`timescale 1ns / 1ps

module ram_wr # (
    parameter                               WIDTH       =   32
)(
    input       wire                        i_clk,
    input       wire                        i_n_reset,
    input       wire                        i_write,

    input       wire    [WIDTH - 1 : 0]     i_data,
    input       wire                        i_data_valid,

    output      wire                        o_en_ram,
    output      wire    [3 : 0]             o_wr_ram,
    output      wire    [WIDTH - 1 : 0]     o_ram_addr,
    output      wire    [WIDTH - 1 : 0]     o_ram_data
);
                reg     [WIDTH - 1 : 0]     r_ram_addr;

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_ram_addr      <=      0;
        end
        else if (i_write && i_data_valid) begin
            r_ram_addr      <=      r_ram_addr + 4;
        end
        else if (i_write) begin
            r_ram_addr      <=      0;
        end
    end
    
    assign o_en_ram     =   i_data_valid;
    assign o_wr_ram     =   {4{i_data_valid}};
    assign o_ram_addr   =   r_ram_addr;
    assign o_ram_data   =   i_data;

endmodule