`timescale 1ns / 1ps

module filter2row#(
    parameter                                                       DATA_SIZE               =   8,
    parameter                                                       MAX_SYS_PORT            =   16,
    parameter                                                       MAX_DEPTH_FILTER        =   4*1,
    parameter                                                       MAX_DEPTH_SLICE         =   4*1
)(
    // System
    input       wire                                                i_clk,
    input       wire                                                i_n_reset,
    input       wire                                                i_terminate,

    // f2r_control
    input       wire                                                i_enable,
    input       wire                                                i_read,
    input       wire                                                i_set_param,

    input       wire        [1 : 0]                                 i_op_mode,
    input       wire        [7 : 0]                                 i_filter_width,
    input       wire        [7 : 0]                                 i_filter_height,
    input       wire        [7 : 0]                                 i_filter_channel,
    input       wire        [7 : 0]                                 i_filter_number,

    input       wire        [7 : 0]                                 i_slice_width,
    input       wire        [7 : 0]                                 i_slice_height,
    input       wire        [7 : 0]                                 i_slice_number,

    output      wire                                                o_set_param_done,
    output      wire                                                o_slice_read_done,
    output      wire                                                o_slice_last,

    // RAM
    input       wire signed [DATA_SIZE-1 : 0]                       i_data,
    input       wire                                                i_valid,
    output      wire                                                o_ram_read_term,

    // filter2systolic
    output      wire signed [DATA_SIZE-1 : 0]                       o_data,
    output      wire                                                o_valid
);
    // Parameters
                localparam  [1 : 0]                                 MODE_NOP        =   2'b00;
                localparam  [1 : 0]                                 MODE_POOL       =   2'b01;
                localparam  [1 : 0]                                 MODE_MVM        =   2'b10;
                localparam  [1 : 0]                                 MODE_CONV       =   2'b11;

    // Control Signals
                reg                                                 r_slice_read_done;
                reg                                                 r_slice_last;
                reg                                                 r_all_filter_count;

    // Index For Constructing Output Buffer
                integer                                             i;
                
    // Filter Data Buffer
                reg         [DATA_SIZE - 1 : 0]                     r_output_filter [0 : MAX_DEPTH_FILTER - 1];
                
    // Count Value of Output Filter
                reg         [7 : 0]                                 r_filter_width_count;
                reg         [7 : 0]                                 r_filter_height_count;
                reg         [7 : 0]                                 r_filter_channel_count;
                reg         [7 : 0]                                 r_filter_number_count;

    // Count Threshold & Parameters
                reg         [1 : 0]                                 r_op_mode;
                reg                                                 r_set_param_done;
                reg         [7 : 0]                                 r_filter_width;
                reg         [7 : 0]                                 r_filter_height;
                reg         [7 : 0]                                 r_filter_channel;
                reg         [7 : 0]                                 r_filter_number;

    // Count Value of Output Filter
                reg         [7 : 0]                                 r_slice_width_count;
                reg         [7 : 0]                                 r_slice_height_count;
                reg         [7 : 0]                                 r_slice_number_count;

    // Count Threshold of Output Filter
                reg         [7 : 0]                                 r_slice_width;
                reg         [7 : 0]                                 r_slice_height;
                reg         [7 : 0]                                 r_slice_number;
                wire        [7 : 0]                                 w_slice_data_addr;


    // Determine Output Filter
                reg signed  [DATA_SIZE - 1 : 0]                     r_data;
                reg                                                 r_valid;


    //////////////////////////////////////////////////////////////////////////////
    // Input Data Control
    //
    always @(posedge i_clk) begin   : SETUP_PARAMETERS
        if (!i_n_reset) begin
            r_set_param_done    <=      0;
            r_op_mode           <=      0;
            r_filter_width      <=      0;
            r_filter_height     <=      0;
            r_filter_channel    <=      0;
            r_filter_number     <=      0;
            r_slice_width       <=      0;
            r_slice_height      <=      0;
            r_slice_number      <=      0;
        end
        else if (i_set_param) begin
            r_set_param_done    <=      1;
            r_op_mode           <=      i_op_mode;
            r_filter_width      <=      i_filter_width;
            r_filter_height     <=      i_filter_height;
            r_filter_channel    <=      i_filter_channel;
            r_filter_number     <=      i_filter_number;
            r_slice_width       <=      i_slice_width;
            r_slice_height      <=      i_slice_height;
            r_slice_number      <=      i_slice_number;
        end
        else if (i_terminate) begin
            r_set_param_done    <=      0;
            r_op_mode           <=      0;
            r_filter_width      <=      0;
            r_filter_height     <=      0;
            r_filter_channel    <=      0;
            r_filter_number     <=      0;
            r_slice_width       <=      0;
            r_slice_height      <=      0;
            r_slice_number      <=      0;
        end
        else begin
            r_set_param_done    <=      0;
            r_op_mode           <=      r_op_mode;
            r_filter_width      <=      r_filter_width;
            r_filter_height     <=      r_filter_height;
            r_filter_channel    <=      r_filter_channel;
            r_filter_number     <=      r_filter_number;
            r_slice_width       <=      r_slice_width;
            r_slice_height      <=      r_slice_height;
            r_slice_number      <=      r_slice_number;
        end
    end

    always @(posedge i_clk) begin : DETERMINE_OUTPUT_FILTER
       if (!i_n_reset) begin
            for (i = 0; i < MAX_DEPTH_FILTER; i = i + 1) begin
                r_output_filter[i] <= {DATA_SIZE{1'b0}};
            end
       end 
       else if (i_set_param || i_terminate) begin
            for (i = 0; i < MAX_DEPTH_FILTER; i = i + 1) begin
                r_output_filter[i] <= {DATA_SIZE{1'b0}};
            end
       end
       else begin
            if (i_enable) begin
                if (i_valid && !r_all_filter_count) begin
                    if (r_op_mode == MODE_CONV) begin
                        r_output_filter[(r_filter_width_count + r_filter_height_count*r_filter_width + r_filter_channel_count*r_filter_width*r_filter_height)*r_filter_number + r_filter_number_count] <= i_data;
                    end
                    else begin
                        r_output_filter[r_filter_width_count+r_filter_height_count*r_filter_width] <= i_data;
                    end
                end
            end
       end
    end

    //////////////////////////////////////////////////////////////////////////////
    // Conversion Control
    //
    always @(posedge i_clk) begin : COUNTING_FOR_CONVERSION
        if (!i_n_reset) begin
            r_filter_number_count       <=      0;
            r_filter_channel_count      <=      0;
            r_filter_height_count       <=      0;
            r_filter_width_count        <=      0;
            r_all_filter_count          <=      0;
        end
        else if (i_set_param || i_terminate) begin
            r_filter_number_count       <=      0;
            r_filter_channel_count      <=      0;
            r_filter_height_count       <=      0;
            r_filter_width_count        <=      0;
            r_all_filter_count          <=      0;
        end
        else begin
            if (i_enable) begin
                if (i_valid && !r_all_filter_count) begin
                    if (r_filter_width_count >= r_filter_width - 1 ) begin
                        r_filter_width_count <= 0;
                        if (r_filter_height_count >= r_filter_height - 1) begin
                            r_filter_height_count <= 0;
                            if (r_filter_channel_count >= r_filter_channel - 1) begin
                                r_filter_channel_count <= 0;
                                if (r_filter_number_count >= r_filter_number - 1) begin
                                    r_filter_number_count <= 0;
                                    r_all_filter_count <= 1;
                                end
                                else begin
                                    r_filter_number_count <= r_filter_number_count + 1;
                                end
                            end
                            else begin
                                r_filter_channel_count <= r_filter_channel_count + 1;
                            end
                        end
                        else begin
                            r_filter_height_count <= r_filter_height_count + 1;
                        end
                    end
                    else begin
                        r_filter_width_count <= r_filter_width_count + 1;
                    end
                end
                else begin
                end
            end
            else begin
                r_filter_number_count       <=      0;
                r_filter_channel_count      <=      0;
                r_filter_height_count       <=      0;
                r_filter_width_count        <=      0;
                r_all_filter_count          <=      0;
            end
        end
    end 

    //////////////////////////////////////////////////////////////////////////////
    // Output Data Control
    // 
    always @(posedge i_clk) begin   : OUTPUT_SLICE_COUNT
        if (!i_n_reset) begin
            r_slice_width_count <= 0;
            r_slice_height_count <= 0;
            r_slice_number_count <= 0;
            r_slice_read_done <= 0;
            r_slice_last <= 0;
        end
        else if (i_terminate) begin
            r_slice_width_count <= 0;
            r_slice_height_count <= 0;
            r_slice_number_count <= 0;
            r_slice_read_done <= 0;
            r_slice_last <= 0;
        end
        else if (i_read && !r_slice_read_done) begin
            if (r_slice_width_count >= r_slice_width - 1) begin
                r_slice_width_count <= 0;
                if (r_slice_height_count >= r_slice_height - 1) begin
                    r_slice_height_count <= 0;
                    r_slice_read_done <= 1;
                    if (r_slice_number_count >= r_slice_number - 1) begin
                        r_slice_number_count <= 0;
                        r_slice_last <= 1;
                    end
                    else begin
                        r_slice_number_count <= r_slice_number_count + 1;
                        r_slice_last <= 0;
                    end
                end
                else begin
                    r_slice_height_count <= r_slice_height_count + 1;
                    r_slice_read_done <= 0;
                end
            end
            else begin
                r_slice_width_count <= r_slice_width_count + 1;
                r_slice_read_done <= 0;
            end
        end
        else begin
            r_slice_width_count     <=  0;
            r_slice_height_count    <=  0;
            r_slice_read_done       <=  0;
        end
    end

    always @(posedge i_clk) begin : DETERMINE_OUTPUT_DATA
        if (!i_n_reset) begin
            r_data <= 0;
            r_valid <= 0;
        end
        else if (i_terminate) begin
            r_data <= 0;
            r_valid <= 0;
        end
        else begin
            if (i_read && !r_slice_read_done) begin
                r_data <= r_output_filter[w_slice_data_addr];
                r_valid <= 1;
            end
            else begin
                r_data <= 0;
                r_valid <= 0;
            end
        end
    end

    assign w_slice_data_addr        =       (r_op_mode == MODE_CONV) ?  ((r_slice_number_count * r_slice_width) + (r_slice_height_count * r_slice_width * r_slice_number) +  (r_slice_width_count)) :
                                                                        ((r_slice_number_count * r_slice_width) + (r_slice_height_count * r_filter_width) +  (r_slice_width_count));
    // assign w_slice_data_addr        =       ((r_slice_number_count * r_slice_width) + (r_slice_height_count * r_filter_width) +  (r_slice_width_count));                                                                    
    assign o_set_param_done         =       r_set_param_done;
    assign o_ram_read_term          =       r_all_filter_count;
    assign o_data                   =       r_data;
    assign o_valid                  =       r_valid;
    assign o_slice_read_done        =       r_slice_read_done;
    assign o_slice_last             =       r_slice_last;

  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule
