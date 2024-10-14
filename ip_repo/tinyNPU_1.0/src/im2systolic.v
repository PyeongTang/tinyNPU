`timescale 1ns / 1ps

module im2systolic #(
        parameter                                                   DATA_SIZE       =   8,
        parameter                                                   MAX_SYS_PORT    =   16,
        parameter                                                   MAX_SYS_HEIGHT  =   3,
        parameter                                                   MAX_SYS_WIDTH   =   6,
        parameter                                                   MAX_DEPTH_SYS   =   MAX_SYS_HEIGHT * MAX_SYS_WIDTH,
        parameter                                                   MAX_CYCLE       =   MAX_SYS_HEIGHT + MAX_SYS_WIDTH - 1
)(
        // System
        input       wire                                            i_clk,
        input       wire                                            i_n_reset,
        input       wire                                            i_terminate,

        // im2col Control
        input       wire                                            i_enable,
        input       wire                                            i_read,
        input       wire                                            i_set_param,
        
        input       wire        [7 : 0]                             i_slice_width,
        input       wire        [7 : 0]                             i_slice_height,
        output      wire                                            o_set_param_done,
        output      wire                                            o_read_done,

        // Image 2 Column
        input       wire                                            i_valid,
        input       wire signed [DATA_SIZE - 1 : 0]                 i_data,

        // PU
        output      wire        [7 : 0]                             o_image_slice_sys_width,
        output      wire signed [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    o_data,
        output      wire                                            o_valid
    );

    // Systolic register
                    reg         [DATA_SIZE - 1 : 0]                 r_systolic_array    [0 : MAX_DEPTH_SYS - 1];

    // Data through PU input port
                    reg signed  [DATA_SIZE*MAX_SYS_PORT - 1 : 0]    r_data;
                    reg                                             r_valid;

                    reg         [7 : 0]                             r_row_count;
                    reg         [7 : 0]                             r_col_count;
                    reg         [7 : 0]                             r_sys_cycle_count;
                    reg                                             r_cycle_one_round;

                    reg                                             r_set_param_done;
                    reg         [7 : 0]                             r_slice_width;
                    reg         [7 : 0]                             r_slice_height;
                    reg         [7 : 0]                             r_systolic_width;
                    reg         [7 : 0]                             r_systolic_height;
                    wire        [clogb2(MAX_DEPTH_SYS) - 1 : 0]     w_systolic_array_addr;

    // Index For Constructing Output Buffer
                    integer                                         i;
                    integer                                         j;

    always @(posedge i_clk) begin : SETUP_PARAMETERS
        if (!i_n_reset) begin
            r_slice_width               <=      0;
            r_slice_height              <=      0;
            r_systolic_width            <=      0;
            r_systolic_height           <=      0;
            r_set_param_done            <=      0;
        end
        else if (i_set_param) begin
            r_slice_width               <=      i_slice_width;
            r_slice_height              <=      i_slice_height;
            r_systolic_width            <=      i_slice_width + i_slice_height - 1;
            r_systolic_height           <=      i_slice_height;
            r_set_param_done            <=      1;
        end
        else if (i_terminate) begin
            r_slice_width               <=      0;
            r_slice_height              <=      0;
            r_systolic_width            <=      0;
            r_systolic_height           <=      0;
            r_set_param_done            <=      0;
        end
        else begin
            r_slice_width               <=      r_slice_width;
            r_slice_height              <=      r_slice_height;
            r_systolic_width            <=      r_systolic_width;
            r_systolic_height           <=      r_systolic_height;
            r_set_param_done            <=      0;
        end
    end

    always @(posedge i_clk) begin : CONSTRUCT_SYSTOLIC_ARRAY
        if (!i_n_reset) begin
            for (i = 0; i < MAX_DEPTH_SYS; i = i + 1) begin
                r_systolic_array[i] <= 0;
            end
        end
        else if (i_set_param || i_terminate) begin
            for (i = 0; i < MAX_DEPTH_SYS; i = i + 1) begin
                r_systolic_array[i] <= 0;
            end
        end
        else begin
            if (i_enable) begin
                if (i_valid) begin
                    r_systolic_array[w_systolic_array_addr] <= i_data;
                end
            end
        end
    end

    always @(posedge i_clk) begin : COUNTING_SYSTOLIC_INDEX
        if (!i_n_reset) begin
            r_col_count <= 0;
            r_row_count <= 0;
        end
        else if (i_set_param || i_terminate) begin
            r_col_count <= 0;
            r_row_count <= 0;
        end
        else begin
            if (i_enable) begin
                if (i_valid) begin
                    if (r_col_count >= r_slice_width - 1) begin
                        r_col_count <= 0;
                        if (r_row_count >= r_slice_height - 1) begin
                            r_row_count <= 0;
                        end
                        else begin
                            r_row_count <= r_row_count + 1;
                        end
                    end
                    else begin
                        r_col_count <= r_col_count + 1;
                    end
                end
                else begin
                    r_col_count <= r_col_count;
                    r_row_count <= r_row_count;
                end
            end
            else begin
                r_col_count <= 0;
                r_row_count <= 0;
            end
        end 
    end

    always @(posedge i_clk) begin : COUNTING_SYSTOLIC_OUTPUT
        if (!i_n_reset) begin
            r_sys_cycle_count <= 0;
            r_cycle_one_round <= 0;
        end
        else if (i_set_param || i_terminate) begin
            r_sys_cycle_count <= 0;
            r_cycle_one_round <= 0;
        end
        else begin
                if (i_read) begin
                    if (!r_cycle_one_round) begin
                        if (r_sys_cycle_count == r_systolic_width) begin
                            r_sys_cycle_count <= 0;
                            r_cycle_one_round <= 1;
                        end
                        else begin
                            r_sys_cycle_count <= r_sys_cycle_count + 1;
                            r_cycle_one_round <= r_cycle_one_round;
                        end
                    end
                    else begin
                        r_sys_cycle_count <= r_sys_cycle_count;
                        r_cycle_one_round <= r_cycle_one_round;
                    end
                end
                else begin
                    r_sys_cycle_count <= 0;
                    r_cycle_one_round <= 0;
                end
        end
    end

    always @(posedge i_clk) begin : DETERMINE_OUTPUT_DATA
        if (!i_n_reset) begin
            r_data      <=      0;
            r_valid     <=      0;
            j           <=      0;
        end
        else if (i_set_param || i_terminate) begin
            r_data      <=      0;
            r_valid     <=      0;
            j           <=      0;
        end
        else begin
            if (i_read) begin
                r_valid <= 1;
                if (r_cycle_one_round) begin
                    r_data <= 0;
                end
                else begin
                    for (j = 0; j < MAX_SYS_PORT; j = j + 1) begin
                        if (j >= r_systolic_height || r_sys_cycle_count >= r_systolic_width) begin
                            r_data[DATA_SIZE*j +: DATA_SIZE] <= 0;
                        end
                        else begin
                            r_data[DATA_SIZE*j +: DATA_SIZE] <= r_systolic_array[j*r_systolic_width + r_sys_cycle_count];
                        end
                    end
                end
            end
            else begin
                r_data <= 0;
                r_valid <= 0;
            end
        end
    end

    assign o_valid                  =   r_valid;
    assign o_data                   =   r_data; // zero fill

    assign w_systolic_array_addr    =   r_row_count * r_systolic_width + r_col_count + r_row_count;

    assign o_read_done              =   r_cycle_one_round;
    assign o_set_param_done         =   r_set_param_done;
    assign o_image_slice_sys_width  =   r_systolic_width;

  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule
