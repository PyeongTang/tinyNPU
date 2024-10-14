`timescale 1ns / 1ps

module im2col #(
        parameter                                                   DATA_SIZE               =   8,
        parameter                                                   MAX_SYS_PORT            =   16,
        parameter                                                   MAX_DEPTH_IMAGE         =   12*4,
        parameter                                                   MAX_DEPTH_OUTPUT        =   12*4,
        parameter                                                   MAX_DEPTH_SLICE         =   3*4
)(
        // System
        input       wire                                            i_clk,
        input       wire                                            i_n_reset,
        input       wire                                            i_terminate,

        // IMAGE RAM RD
        output      wire        [31 : 0]                            o_im2col_address,

        // im2col_control
        input       wire                                            i_enable,
        input       wire                                            i_read,
        output      wire                                            o_convert_done,
        input       wire                                            i_set_param,
        output      wire                                            o_set_param_done,
        output      wire                                            o_read_done,
        output      wire                                            o_slice_read_done,
        output      wire                                            o_slice_last,
        
        // AXI4
        input       wire        [1 : 0]                             i_op_mode,

        //  -   IMAGE PARAM
        input       wire        [7 : 0]                             i_image_width,          // To Conversion
        input       wire        [7 : 0]                             i_image_height,         // To Conversion
        input       wire        [7 : 0]                             i_image_channel,        // To Conversion

        //  -   FILTER PARAM
        input       wire        [7 : 0]                             i_filter_width,
        input       wire        [7 : 0]                             i_filter_height,
      
        //  -   SLICE PARAM
        input       wire        [7 : 0]                             i_slice_width,          // To Construct Systolic Array
        input       wire        [7 : 0]                             i_slice_height,         // To Construct Systolic Array
        input       wire        [7 : 0]                             i_slice_number,         // To Construct Systolic Array

        // ram_rd
        input       wire signed [DATA_SIZE-1 : 0]                   i_data,
        input       wire                                            i_valid,
        output      wire                                            o_ram_read_term,

        // im2systolic
        // maxpool
        output      wire signed [DATA_SIZE-1 : 0]                   o_data,
        output      wire                                            o_valid
);
    // Parameters
                localparam      [1 : 0]                             MODE_NOP        =   2'b00;
                localparam      [1 : 0]                             MODE_POOL       =   2'b01;
                localparam      [1 : 0]                             MODE_MVM        =   2'b10;
                localparam      [1 : 0]                             MODE_CONV       =   2'b11;

    // Control Signals
                    reg                                             r_convert_done;
                    reg                                             r_convert_done_z;
                    reg                                             r_convert_done_zz;
                    reg                                             r_convert_done_zzz;
                    reg                                             r_slice_read_done;
                    reg                                             r_slice_last;
                    reg                                             r_all_img_count;

    // Indices For Constructing Original Buffer
                    integer                                         i;
                    integer                                         j;

    // Image Data Buffer
                    reg         [DATA_SIZE - 1 : 0]                 r_output_image      [0 : MAX_DEPTH_OUTPUT - 1];

    // Buffer Addressing Wire
                    wire        [clogb2(MAX_DEPTH_IMAGE) - 1 : 0]   w_original_image_addr;
                    reg         [clogb2(MAX_DEPTH_IMAGE) - 1 : 0]   r_original_image_addr;
                    reg         [clogb2(MAX_DEPTH_IMAGE) - 1 : 0]   r_original_image_addr_z;

                    wire        [clogb2(MAX_DEPTH_OUTPUT) - 1 : 0]  w_output_image_addr;
                    reg         [clogb2(MAX_DEPTH_OUTPUT) - 1 : 0]  r_output_image_addr;
                    reg         [clogb2(MAX_DEPTH_OUTPUT) - 1 : 0]  r_output_image_addr_z;
                    reg         [clogb2(MAX_DEPTH_OUTPUT) - 1 : 0]  r_output_image_addr_zz;

                    wire        [clogb2(MAX_DEPTH_OUTPUT) - 1 : 0]  w_slice_data_addr;

    // Count Value of Input Image
                    reg         [7 : 0]                             r_channel_count;
                    reg         [7 : 0]                             r_num_patch_height_count;
                    reg         [7 : 0]                             r_num_patch_width_count;
                    reg         [7 : 0]                             r_filter_height_count;
                    reg         [7 : 0]                             r_filter_width_count;
                    reg         [clogb2(MAX_DEPTH_IMAGE) - 1 : 0]   r_image_count;

    // Count Threshold & Parameters
                    reg         [1 : 0]                             r_op_mode;
                    reg                                             r_set_param_done;
                    reg                                             r_set_param_done_z;
                    reg                                             r_set_param_done_zz;
                    reg         [7 : 0]                             r_image_width;
                    reg         [7 : 0]                             r_image_height;
                    reg         [7 : 0]                             r_image_channel;
                    reg         [7 : 0]                             r_filter_width;
                    reg         [7 : 0]                             r_filter_height;
                    reg         [15: 0]                             r_filter_depth;
                    wire        [7 : 0]                             w_num_patch_width;
                    wire        [7 : 0]                             w_num_patch_height;
                    reg         [15: 0]                             r_patch_depth;
                    reg         [MAX_DEPTH_OUTPUT - 1 : 0]          r_output_depth;

    // Count Value of Output Image
                    reg         [7 : 0]                             r_slice_width_count;
                    reg         [7 : 0]                             r_slice_height_count;
                    reg         [7 : 0]                             r_slice_number_count;

    // Pooling Read Counter
                    reg         [clogb2(MAX_DEPTH_OUTPUT) - 1 : 0]  r_read_count;
                    reg                                             r_read_done;

    // Count Threshold of Output Image
                    reg         [7 : 0]                             r_slice_width;
                    reg         [7 : 0]                             r_slice_height;
                    reg         [7 : 0]                             r_slice_number;

    // Determining Output Image
                    reg                                             r_valid;
                    reg signed  [DATA_SIZE - 1 : 0]                 r_data;


    //////////////////////////////////////////////////////////////////////////////
    // Input Data Control
    //
    always @(posedge i_clk) begin   : SETUP_PARAMETERS
        if (!i_n_reset) begin
            r_set_param_done    <=      0;
            r_op_mode           <=      0;
            r_image_width       <=      0;
            r_image_height      <=      0;
            r_image_channel     <=      0;
            r_filter_width      <=      0;
            r_filter_height     <=      0;
            r_slice_width       <=      0;
            r_slice_height      <=      0;
            r_slice_number      <=      0;
        end
        else begin
            if (i_set_param) begin
                r_set_param_done    <=      1'b1;
                r_op_mode           <=      i_op_mode;
                r_image_width       <=      i_image_width;
                r_image_height      <=      i_image_height;
                r_image_channel     <=      i_image_channel;
                r_filter_width      <=      i_filter_width;
                r_filter_height     <=      i_filter_height;
                r_slice_width       <=      i_slice_width;
                r_slice_height      <=      i_slice_height;
                r_slice_number      <=      i_slice_number;
            end
            else if (i_terminate) begin
                r_set_param_done    <=      0;
                r_op_mode           <=      0;
                r_image_width       <=      0;
                r_image_height      <=      0;
                r_image_channel     <=      0;
                r_filter_width      <=      0;
                r_filter_height     <=      0;
                r_slice_width       <=      0;
                r_slice_height      <=      0;
                r_slice_number      <=      0;
            end
            else begin
                r_set_param_done    <=      1'b0;
                r_op_mode           <=      r_op_mode;
                r_image_width       <=      r_image_width;
                r_image_height      <=      r_image_height;
                r_image_channel     <=      r_image_channel;
                r_filter_width      <=      r_filter_width;
                r_filter_height     <=      r_filter_height;
                r_slice_width       <=      r_slice_width;
                r_slice_height      <=      r_slice_height;
                r_slice_number      <=      r_slice_number;
            end
        end
    end

    always @(posedge i_clk) begin   : PIPELINE
        if (!i_n_reset) begin
                r_filter_depth      <=      0;
                r_patch_depth       <=      0;
                r_output_depth      <=      0;
        end
        else begin
            if (i_set_param) begin
                r_filter_depth      <=      r_filter_width * r_filter_height;
                r_patch_depth       <=      w_num_patch_height * w_num_patch_width;
                r_output_depth      <=      r_filter_depth * r_patch_depth;
            end
            else if (i_terminate) begin
                r_filter_depth      <=      0;
                r_patch_depth       <=      0;
                r_output_depth      <=      0;
            end
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_set_param_done <= 0;
            r_set_param_done_z <= 0;
            r_set_param_done_zz <= 0;
        end
        else begin
            r_set_param_done <= i_set_param;
            r_set_param_done_z <= r_set_param_done;
            r_set_param_done_zz <= r_set_param_done_z;
        end
    end

    always @(posedge i_clk) begin   : COUNTING_ORIGINAL_IMAGE
        if (!i_n_reset) begin
            r_image_count <= 0;
            r_all_img_count <= 0;
        end
        else if (i_set_param || i_terminate) begin
            r_image_count <= 0;
            r_all_img_count <= 0;
        end
        else begin
            if (i_enable && !r_all_img_count) begin
                if (i_valid) begin
                    if (r_image_count >= (r_image_channel * r_image_height * r_image_width) - 1) begin
                        r_image_count <= 0;
                        r_all_img_count <= 1;
                    end
                    else begin
                        r_image_count <= r_image_count + 1'b1; 
                        r_all_img_count <= r_all_img_count;
                    end
                end
                else begin
                    r_image_count <= r_image_count;
                    r_all_img_count <= r_all_img_count;
                end
            end 
            else begin
                r_image_count <= r_image_count;
                r_all_img_count <= r_all_img_count;
            end
        end  
    end

    //////////////////////////////////////////////////////////////////////////////
    // Conversion Control
    //
    always @(posedge i_clk) begin   : CONSTRUCT_OUTPUT_IMAGE_BUFFER
        if (!i_n_reset) begin
            for (j = 0; j < MAX_DEPTH_OUTPUT; j = j + 1) begin
                r_output_image[j] <= {DATA_SIZE{1'b0}};
            end
        end
        else if (i_set_param || i_terminate) begin
            for (j = 0; j < MAX_DEPTH_OUTPUT; j = j + 1) begin
                r_output_image[j] <= {DATA_SIZE{1'b0}};
            end
        end
        else if (i_enable && i_valid && ~o_convert_done) begin
            if (r_op_mode == MODE_CONV || r_op_mode == MODE_POOL) begin
                r_output_image[r_output_image_addr_zz] <= i_data;
            end
            else if (r_op_mode == MODE_MVM) begin
                r_output_image[r_image_count] <= i_data;
            end
        end
    end

    always @(posedge i_clk) begin   : COUNTING_FOR_CONVERSION
        if (!i_n_reset) begin
            r_channel_count                 <=      0;
            r_num_patch_height_count        <=      0;
            r_num_patch_width_count         <=      0;
            r_filter_height_count           <=      0;
            r_filter_width_count            <=      0;
            r_convert_done                  <=      0;
        end
        else if (i_set_param || i_terminate) begin
            r_channel_count                 <=      0;
            r_num_patch_height_count        <=      0;
            r_num_patch_width_count         <=      0;
            r_filter_height_count           <=      0;
            r_filter_width_count            <=      0;
            r_convert_done                  <=      0;
        end
        else if (r_op_mode == MODE_MVM || r_op_mode == MODE_CONV || r_op_mode == MODE_POOL) begin
            if (i_enable && !o_convert_done) begin
                if (r_filter_width_count == r_filter_width - 1) begin
                    r_filter_width_count <= 0;
                    if (r_filter_height_count == r_filter_height - 1) begin
                        r_filter_height_count <= 0;
                        if (r_num_patch_width_count == w_num_patch_width - 1) begin
                            r_num_patch_width_count <= 0;
                            if (r_num_patch_height_count == w_num_patch_height - 1) begin
                                r_num_patch_height_count <= 0;
                                if (r_channel_count == r_image_channel - 1) begin
                                    r_channel_count <= 0;
                                    r_convert_done <= 1;
                                end
                                else begin
                                    r_channel_count <= r_channel_count + 1;
                                end
                            end
                            else begin
                                r_num_patch_height_count <= r_num_patch_height_count + 1;
                            end
                        end
                        else begin
                            r_num_patch_width_count <= r_num_patch_width_count + 1;
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
                r_channel_count                 <=      r_channel_count;
                r_num_patch_height_count        <=      r_num_patch_height_count;
                r_num_patch_width_count         <=      r_num_patch_width_count;
                r_filter_height_count           <=      r_filter_height_count;
                r_filter_width_count            <=      r_filter_width_count;
                r_convert_done                  <=      r_convert_done;
            end
        end
    end

    always @(posedge i_clk) begin   : DETERMINE_OUTPUT_DATA
        if (!i_n_reset) begin
            r_data <= 0;
            r_valid <= 0;
        end
        else if (i_set_param || i_terminate) begin
            r_data <= 0;
            r_valid <= 0;
        end
        else begin
            if (i_read && r_op_mode == MODE_POOL) begin
                r_data <= r_output_image[r_read_count];
                r_valid <= 1;
            end
            else if (i_read && !r_slice_read_done) begin
                if (!r_slice_last) begin
                    if (r_op_mode == MODE_CONV || r_op_mode == MODE_MVM) begin
                        r_data <= r_output_image[w_slice_data_addr];
                        r_valid <= 1;
                    end
                end
                else begin
                    r_data <= 0;
                    r_valid <= 0;
                end
            end
            else begin
                r_data <= 0;
                r_valid <= 0;
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

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_read_count        <=      0;
            r_read_done         <=      0;
        end
        else if (i_terminate) begin
            r_read_count        <=      0;
            r_read_done         <=      0;
        end
        else begin
            if (i_read && r_op_mode == MODE_POOL) begin
                if (!r_read_done) begin
                    if (r_read_count >= r_output_depth - 1) begin
                        r_read_count <= 0;
                        r_read_done <= 1;
                    end
                    else begin
                        r_read_count <= r_read_count + 1;
                    end
                end
            end
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_output_image_addr_z <= 0;
            r_output_image_addr_zz <= 0;
            r_original_image_addr_z <= 0;
            r_convert_done_z <= 0;
            r_convert_done_zz <= 0;
            r_convert_done_zzz <= 0;
        end
        else begin
            r_output_image_addr_z <= r_output_image_addr;
            r_output_image_addr_zz <= r_output_image_addr_z;
            r_original_image_addr_z <= r_original_image_addr;
            r_convert_done_z <= r_convert_done;
            r_convert_done_zz <= r_convert_done_z;
            r_convert_done_zzz <= r_convert_done_zz;
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            r_original_image_addr <= 0;
            r_output_image_addr <= 0;
        end
        else begin
            r_original_image_addr <= (r_channel_count*r_image_height+r_filter_height_count+r_num_patch_height_count)*r_image_width+r_filter_width_count+r_num_patch_width_count;
            r_output_image_addr <= (r_num_patch_width_count+(r_num_patch_height_count*w_num_patch_width))*(r_image_channel*r_filter_height*r_filter_width)+(r_filter_width_count+(r_filter_height_count*r_filter_width)+(r_channel_count*r_filter_height*r_filter_width));
        end
    end

    // Addressing
    assign w_original_image_addr    =       (r_channel_count*r_image_height+r_filter_height_count+r_num_patch_height_count)*r_image_width+r_filter_width_count+r_num_patch_width_count;
    assign w_output_image_addr      =       (r_num_patch_width_count+(r_num_patch_height_count*w_num_patch_width))*(r_image_channel*r_filter_height*r_filter_width)+(r_filter_width_count+(r_filter_height_count*r_filter_width)+(r_channel_count*r_filter_height*r_filter_width));
    assign w_slice_data_addr        =       (r_slice_number_count * r_slice_height * r_slice_width) + (r_slice_height_count * r_slice_width) + (r_slice_width_count);

    assign o_set_param_done         =       r_set_param_done_zz;
    assign o_data                   =       r_data;
    
    assign o_convert_done           =       (r_op_mode == MODE_CONV)    ?   (r_convert_done_zzz)    : 
                                            (r_op_mode == MODE_POOL)    ?   (r_convert_done_zzz)    :
                                            (r_op_mode == MODE_MVM)     ?   (r_all_img_count)   :   1'b0;

    assign o_ram_read_term          =       (r_op_mode == MODE_CONV)    ?   (r_convert_done_zzz)    : 
                                            (r_op_mode == MODE_POOL)    ?   (r_convert_done_zzz)    :
                                            (r_op_mode == MODE_MVM)     ?   (r_all_img_count)   :   1'b0;
                                            
    assign o_slice_last             =       r_slice_last;
    assign o_slice_read_done        =       r_slice_read_done;
    assign o_valid                  =       r_valid;
    assign w_num_patch_height       =       ((r_op_mode == MODE_CONV || r_op_mode == MODE_POOL) && r_image_height > 0) ? (r_image_height - r_filter_height + 1)  : 0;
    assign w_num_patch_width        =       ((r_op_mode == MODE_CONV || r_op_mode == MODE_POOL) && r_image_width > 0)  ? (r_image_width  - r_filter_width + 1)   : 0;
    assign o_read_done              =       r_read_done;
    // assign o_im2col_address         =       r_original_image_addr_z;
    assign o_im2col_address         =       r_original_image_addr;

  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction
  
endmodule
