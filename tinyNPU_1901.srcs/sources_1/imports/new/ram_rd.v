`timescale 1ns / 1ps

module ram_rd # (
    parameter                               WIDTH       =   32
)(
    input       wire                        i_clk,
    input       wire                        i_n_reset,
    input       wire                        i_read,
    input       wire                        i_term,

    output      wire                        o_en_ram,
    output      wire    [WIDTH - 1 : 0]     o_ram_addr,
    input       wire    [WIDTH - 1 : 0]     i_ram_data,
    output      wire    [WIDTH - 1 : 0]     o_ram_data,
    output      wire                        o_ram_valid
);
                reg                         r_en_ram;

                reg     [WIDTH - 1 : 0]     r_ram_addr;
                reg                         r_ram_valid;
                reg                         r_ram_valid_z;

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_en_ram        <=      0;
            r_ram_addr      <=      0;
        end
        else if (i_term) begin
            r_en_ram        <=      0;
            r_ram_addr      <=      0;
        end
        else if (i_read) begin
            r_en_ram        <=      1;
            r_ram_addr      <=      r_ram_addr + 1;
        end
        else begin
            r_en_ram        <=      0;
            r_ram_addr      <=      0;
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_ram_valid         <=      0;
            r_ram_valid_z       <=      0;
        end
        else if (i_term) begin
            r_ram_valid         <=      0;
            r_ram_valid_z       <=      0;
        end
        else if (i_read) begin
            r_ram_valid         <=      1;
            r_ram_valid_z       <=      r_ram_valid;
        end
        else begin
            r_ram_valid         <=      0;
            r_ram_valid_z       <=      0;
        end
    end

    assign o_en_ram     =   i_read & ~i_term;
    assign o_ram_addr   =   r_ram_addr;
    assign o_ram_data   =   i_ram_data;
    assign o_ram_valid  =   r_ram_valid;

endmodule
