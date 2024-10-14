`timescale 1ns / 1ps

module pu #(
    parameter                                                                       DATA_SIZE       = 8,
    parameter                                                                       V_PORT_WIDTH    = 16,
    parameter                                                                       H_PORT_WIDTH    = 16
)(
    // System
    input       wire                                                                i_clk,
    input       wire                                                                i_n_reset,
    input       wire                                                                i_terminate,

    // PU Control
    input       wire                                                                i_set_param,
    input       wire                                                                i_enable,
    input       wire                                                                i_read,
    output      wire                                                                o_set_param_done,

    input       wire        [7 : 0]                                                 i_pu_cycle_horizontal,
    input       wire        [7 : 0]                                                 i_pu_cycle_vertical,
    input       wire        [7 : 0]                                                 i_pu_sys_usage_width,
    input       wire        [7 : 0]                                                 i_pu_sys_usage_height,

    output      wire                                                                o_mac_done,
    output      wire                                                                o_read_done,

    // I2S, F2S, Local Buffer
    input       wire                                                                i_valid,
    input       wire signed [DATA_SIZE*V_PORT_WIDTH - 1 :   0]                      i_data_v,
    input       wire signed [DATA_SIZE*H_PORT_WIDTH - 1 :   0]                      i_data_h,
    output      wire signed [31          :                  0]                      o_data_s,
    output      wire                                                                o_valid
);

                localparam  S_PORT_WIDTH = V_PORT_WIDTH*H_PORT_WIDTH;

    // Calculate cycle count
                reg         [clogb2(S_PORT_WIDTH/2+1) : 0]                          r_pe_count;
                reg                                                                 r_mac_done;

    // Parameter
                reg                                                                 r_set_param_done;
                reg         [7 : 0]                                                 r_pu_cycle_horizontal;
                reg         [7 : 0]                                                 r_pu_cycle_vertical;
                reg         [7 : 0]                                                 r_pu_sys_usage_height;
                reg         [7 : 0]                                                 r_pu_sys_usage_width;
                wire        [7 : 0]                                                 w_pu_cycle;

    // Read count
                reg         [7 : 0]                                                 r_pu_sys_usage_width_count;
                reg         [7 : 0]                                                 r_pu_sys_usage_height_count;
                reg                                                                 r_read_done;
                wire        [DATA_SIZE*(V_PORT_WIDTH+1)*(H_PORT_WIDTH) - 1 : 0]     w_pe_h;
                wire        [DATA_SIZE*(H_PORT_WIDTH+1)*(V_PORT_WIDTH) - 1 : 0]     w_pe_v;
                wire        [32*S_PORT_WIDTH - 1 : 0]                               w_data_s;
                reg  signed [31 : 0]                                                r_data_s;
                reg                                                                 r_valid;


    genvar h, v;
    generate
        for (v = 0; v < V_PORT_WIDTH; v = v + 1) begin
            for (h = 0; h < H_PORT_WIDTH; h = h + 1) begin
                pe #(
                    .DATA_SIZE  (DATA_SIZE)
                ) i_pe (
                    .i_clk      (i_clk),
                    .i_n_reset  (i_n_reset),
                    .i_enable   (i_enable),
                    .i_valid    (i_valid),
                    .i_data_v   (w_pe_v     [DATA_SIZE*((V_PORT_WIDTH + 1) * h + v)     +: DATA_SIZE]),
                    .i_data_h   (w_pe_h     [DATA_SIZE*((H_PORT_WIDTH + 1) * v + h)     +: DATA_SIZE]),
                    .o_data_sum (w_data_s   [32*(H_PORT_WIDTH * v + h)                  +: 32]),
                    .o_data_v   (w_pe_v     [DATA_SIZE*((V_PORT_WIDTH + 1) * h + v + 1) +: DATA_SIZE]),
                    .o_data_h   (w_pe_h     [DATA_SIZE*((H_PORT_WIDTH + 1) * v + h + 1) +: DATA_SIZE])
                );
            end
        end
    endgenerate

    genvar i;
    generate
        for (i = 0; i < H_PORT_WIDTH; i = i + 1) begin
            assign w_pe_h[DATA_SIZE*((V_PORT_WIDTH + 1) * i) +: DATA_SIZE] = i_data_h[DATA_SIZE*i +: DATA_SIZE];
        end
        for (i = 0; i < V_PORT_WIDTH; i = i + 1) begin
            assign w_pe_v[DATA_SIZE*((H_PORT_WIDTH + 1) * i) +: DATA_SIZE] = i_data_v[DATA_SIZE*i +: DATA_SIZE];
        end
    endgenerate

    always @(posedge i_clk) begin : SET_PARAMETERS
        if (!i_n_reset) begin
            r_set_param_done                <=      0;
            r_pu_sys_usage_height           <=      1;
            r_pu_sys_usage_width            <=      1;
            r_pu_cycle_horizontal           <=      1;
            r_pu_cycle_vertical             <=      1;
        end
        else if (i_terminate) begin
            r_set_param_done                <=      0;
            r_pu_sys_usage_height           <=      1;
            r_pu_sys_usage_width            <=      1;
            r_pu_cycle_horizontal           <=      1;
            r_pu_cycle_vertical             <=      1;
        end
        else begin
            if (i_set_param) begin
                r_pu_sys_usage_height       <=      i_pu_sys_usage_height;
                r_pu_sys_usage_width        <=      i_pu_sys_usage_width;
                r_pu_cycle_horizontal       <=      i_pu_cycle_horizontal;
                r_pu_cycle_vertical         <=      i_pu_cycle_vertical;
                r_set_param_done            <=      1;
            end
            else begin
                r_pu_sys_usage_height       <=      r_pu_sys_usage_height;
                r_pu_sys_usage_width        <=      r_pu_sys_usage_width;
                r_pu_cycle_horizontal       <=      r_pu_cycle_horizontal;
                r_pu_cycle_vertical         <=      r_pu_cycle_vertical;
                r_set_param_done            <=      0;
            end
        end
    end 

    always @(posedge i_clk) begin : COUNTING_PU_USED_PORT
        if (!i_n_reset) begin
            r_pu_sys_usage_width_count      <=  0;
            r_pu_sys_usage_height_count     <=  0;
            r_read_done                     <=  0;
        end
        else if (i_terminate) begin
            r_pu_sys_usage_width_count      <=  0;
            r_pu_sys_usage_height_count     <=  0;
            r_read_done                     <=  0;
        end
        else begin
            if (i_enable) begin
                if (i_read && !o_read_done) begin
                    if (r_pu_sys_usage_width_count >= r_pu_sys_usage_width - 1) begin
                        r_pu_sys_usage_width_count <= 0;
                        if (r_pu_sys_usage_height_count >= r_pu_sys_usage_height - 1) begin
                            r_pu_sys_usage_height_count     <=  0;
                            r_read_done                     <=  1;
                        end 
                        else begin
                            r_pu_sys_usage_height_count     <=  r_pu_sys_usage_height_count + 1;
                            r_read_done                     <=  0;
                        end
                    end
                    else begin
                        r_pu_sys_usage_width_count      <=  r_pu_sys_usage_width_count + 1;
                        r_pu_sys_usage_height_count     <=  r_pu_sys_usage_height_count;
                        r_read_done                     <=  0;
                    end
                end
                else begin
                    r_pu_sys_usage_width_count      <=  r_pu_sys_usage_width_count;
                    r_pu_sys_usage_height_count     <=  r_pu_sys_usage_height_count;
                    r_read_done                     <=  0;
                end
            end
            else begin
                r_pu_sys_usage_width_count          <=  0;
                r_pu_sys_usage_height_count         <=  0;
                r_read_done                         <=  0;
            end
        end
    end

    always @(posedge i_clk) begin : COUNTING_RESULT_VALUES
        if (!i_n_reset) begin
            r_pe_count <= 0;
            r_mac_done <= 0;
        end
        else if (i_terminate) begin
            r_pe_count <= 0;
            r_mac_done <= 0;
        end
        else begin
            if (i_enable && !i_read) begin
                if (r_pe_count >= w_pu_cycle) begin
                    r_pe_count <= 0;
                    r_mac_done <= 1;
                end
                else begin
                    r_pe_count <= r_pe_count + 1;
                    r_mac_done <= 0;
                end
            end
            else begin
                r_pe_count <= 0;
                r_mac_done <= 0;
            end
        end
    end

    always @(posedge i_clk) begin : DETERMINE_OUTPUT_DATA
        if (!i_n_reset) begin
            r_data_s    <=  0;
            r_valid     <=  0;
        end 
        else if (i_terminate) begin
            r_data_s    <=  0;
            r_valid     <=  0;
        end
        else begin
            if (i_enable) begin
                if (i_read && !o_read_done) begin
                    r_data_s <= w_data_s[32*(r_pu_sys_usage_height_count * V_PORT_WIDTH + r_pu_sys_usage_width_count) +: 32];
                    r_valid <= 1;
                end
                else begin
                    r_data_s <= 0;
                    r_valid <= 0;
                end
            end
            else begin
                r_data_s <= 0;
                r_valid <= 0;
            end 
        end
    end

    assign o_data_s             =       r_data_s;
    assign o_valid              =       r_valid;
    assign w_pu_cycle           =       (r_pu_cycle_horizontal >= r_pu_cycle_vertical) ? r_pu_cycle_horizontal + 1 : r_pu_cycle_vertical + 1;
    assign o_set_param_done     =       r_set_param_done;
    assign o_mac_done           =       (w_pu_cycle == 0) ? 0 : r_mac_done;
    assign o_read_done          =       (r_pu_sys_usage_width == 0)     ? 0 :
                                        (r_pu_sys_usage_height == 0)    ? 0 : r_read_done;

  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule
