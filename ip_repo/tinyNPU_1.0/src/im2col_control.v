`timescale 1ns / 1ps

module im2col_control (
        // System
        input       wire                        i_clk,
        input       wire                        i_n_reset,

        // Local Control
        input       wire                        i_set_param,
        input       wire        [1 : 0]         i_op_mode,
        input       wire                        i_start_mac,
        input       wire                        i_start_pool,
        input       wire                        i_terminate,
        input       wire        [15 : 0]        i_slice_number,
        output      wire                        o_image_ready,
        output      wire                        o_done,

        // im2col
        input       wire                        i_i2c_set_param_done,
        output      wire                        o_i2c_enable,
        input       wire                        i_i2c_convert_done,
        output      wire                        o_i2c_read,
        input       wire                        i_i2c_read_done,
        input       wire                        i_i2c_slice_last,
        input       wire                        i_i2c_slice_read_done,
        output      wire                        o_i2c_set_param,
        input       wire                        i_ram_read_done,

        // im2systolic
        output      wire                        o_i2s_enable,
        output      wire                        o_i2s_read,
        input       wire                        i_i2s_read_done,

        output      wire                        o_i2s_set_param,
        input       wire                        i_i2s_set_param_done,

        // ram_rd
        output      wire                        o_en_ram,
        output      wire                        o_im2col_addressing
    );

    // Parameters
                localparam      [1 : 0]         MODE_NOP        =   2'b00;
                localparam      [1 : 0]         MODE_POOL       =   2'b01;
                localparam      [1 : 0]         MODE_MVM        =   2'b10;
                localparam      [1 : 0]         MODE_CONV       =   2'b11;

                localparam      [3 : 0]         IDLE            =   4'h0;
                localparam      [3 : 0]         SET_PARAM       =   4'h1;
                localparam      [3 : 0]         CONVERT         =   4'h2;
                localparam      [3 : 0]         POOL            =   4'h3;
                localparam      [3 : 0]         SYS             =   4'h4;
                localparam      [3 : 0]         WAIT            =   4'h5;
                localparam      [3 : 0]         READ            =   4'h6;
                localparam      [3 : 0]         CHECK           =   4'h7;
                localparam      [3 : 0]         DONE            =   4'h8;

    // State Register
                    reg         [3 : 0]         present_state;
                    reg         [3 : 0]         next_state;

    // Local Control
                    reg                         r_image_ready;
                    reg                         r_done;

    // Image 2 Column
                    reg                         r_i2c_enable;
                    reg                         r_i2c_read;
                    reg                         r_i2c_set_param;

    // Image 2 Systolic
                    reg                         r_i2s_enable;
                    reg                         r_i2s_read;
                    reg                         r_i2s_set_param;

    // RAM
                    reg                         r_en_ram;
                    reg                         r_im2col_addressing;

    always @(negedge i_clk) begin : STATE_TRANSITION
        if (!i_n_reset) begin
            present_state <= IDLE;
        end
        else begin
            present_state <= next_state;
        end
    end

    always @(posedge i_clk) begin : DETERMINE_STATE_AND_OUTPUT
        if (!i_n_reset) begin
            next_state              <=      IDLE;
            r_i2c_set_param         <=      0;
            r_i2s_set_param         <=      0;
            r_image_ready           <=      0;
            r_done                  <=      0;
            r_i2c_enable            <=      0;
            r_i2c_read              <=      0;
            r_i2s_enable            <=      0;
            r_i2s_read              <=      0;
            r_en_ram                <=      0;
            r_im2col_addressing     <=      0;
        end
        else begin
            case (present_state)
                IDLE : begin
                    if ((i_set_param && i_op_mode == MODE_CONV) || (i_set_param && i_op_mode == MODE_MVM)) begin
                        next_state          <=      SET_PARAM;
                        r_i2c_set_param     <=      1;
                        r_i2s_set_param     <=      1;
                    end
                    else if (i_set_param && i_op_mode == MODE_POOL) begin
                        next_state          <=      SET_PARAM;
                        r_i2c_set_param     <=      1;
                    end
                    else begin
                        next_state          <=      IDLE;
                    end
                end

                SET_PARAM : begin
                    if (i_i2c_set_param_done) begin
                        next_state          <=      CONVERT;
                        r_i2c_set_param     <=      0;
                        r_i2s_set_param     <=      0;
                        r_en_ram            <=      1;
                        r_i2c_enable        <=      1;
                        if (i_op_mode == MODE_CONV || i_op_mode == MODE_POOL) begin
                            r_im2col_addressing <=  1;
                        end
                    end
                    else begin
                        next_state          <=      SET_PARAM;
                    end
                end

                CONVERT : begin
                    if (i_i2c_convert_done) begin
                        if      (i_op_mode == MODE_POOL) begin
                            next_state          <=      WAIT;
                            r_image_ready       <=      1;
                        end
                        else if (i_op_mode == MODE_CONV || i_op_mode == MODE_MVM) begin
                            next_state          <=      SYS;
                            r_i2c_read          <=      1;
                            r_i2s_enable        <=      1;
                        end
                        r_en_ram            <=      0;
                    end
                    else begin
                        next_state          <=      CONVERT;
                    end
                end

                SYS : begin
                    if (i_i2c_slice_read_done) begin
                        next_state          <=      WAIT;
                        r_i2c_read          <=      0;
                        r_i2s_enable        <=      0;
                        r_image_ready       <=      1;
                    end
                    else begin
                        next_state          <=      SYS;
                    end
                end

                WAIT : begin
                    if (i_terminate) begin
                        next_state              <=      IDLE;
                        r_i2c_set_param         <=      0;
                        r_i2s_set_param         <=      0;
                        r_image_ready           <=      0;
                        r_done                  <=      0;
                        r_i2c_enable            <=      0;
                        r_i2c_read              <=      0;
                        r_i2s_enable            <=      0;
                        r_i2s_read              <=      0;
                        r_en_ram                <=      0;
                        r_im2col_addressing     <=      0;
                    end
                    else if (i_start_mac) begin
                        next_state          <=      READ;
                        r_i2s_read          <=      1;
                        r_image_ready       <=      0;
                    end
                    else if (i_start_pool) begin
                        next_state          <=      POOL;
                        r_i2c_read          <=      1;
                        r_image_ready       <=      0;
                    end
                    else begin
                        next_state          <=      WAIT;
                    end
                end

                READ : begin
                    if (i_i2s_read_done) begin
                        next_state          <=      CHECK;
                        r_i2s_read          <=      0;
                        r_done              <=      1;
                    end
                    else begin
                        next_state          <=      READ;
                    end
                end

                CHECK : begin
                    if (i_slice_number > 1 && i_i2c_slice_last) begin
                        next_state          <=      DONE;
                    end
                    else begin
                        next_state          <=      SYS;
                        r_i2c_read          <=      1;
                        r_i2s_enable        <=      1;
                        r_done              <=      0;
                    end
                end

                POOL    :    begin
                    if (i_i2c_read_done) begin
                        next_state          <=      DONE;
                        r_i2c_read          <=      0;
                    end
                    else begin
                        next_state          <=      POOL;
                    end
                end

                DONE : begin
                    if (i_terminate) begin
                        next_state              <=      IDLE;
                        r_i2c_set_param         <=      0;
                        r_i2s_set_param         <=      0;
                        r_image_ready           <=      0;
                        r_done                  <=      0;
                        r_i2c_enable            <=      0;
                        r_i2c_read              <=      0;
                        r_i2s_enable            <=      0;
                        r_i2s_read              <=      0;
                        r_en_ram                <=      0;
                        r_im2col_addressing     <=      0;
                    end
                    else begin
                        next_state              <=      DONE;
                    end
                end

                default : begin
                    next_state              <=      IDLE;
                    r_i2c_set_param         <=      0;
                    r_i2s_set_param         <=      0;
                    r_image_ready           <=      0;
                    r_done                  <=      0;
                    r_i2c_enable            <=      0;
                    r_i2c_read              <=      0;
                    r_i2s_enable            <=      0;
                    r_i2s_read              <=      0;
                    r_en_ram                <=      0;
                    r_im2col_addressing     <=      0;
                end
            endcase
        end
    end

    // Local Control
    assign  o_image_ready           =   r_image_ready;
    assign  o_done                  =   r_done;

    // Image 2 Column
    assign  o_i2c_enable            =   r_i2c_enable;
    assign  o_i2c_read              =   r_i2c_read;

    // Image 2 Systolic
    assign  o_i2s_enable            =   r_i2s_enable;
    assign  o_i2s_read              =   r_i2s_read;

    // i2c i2s parameters
    assign  o_i2c_set_param         =   r_i2c_set_param;
    assign  o_i2s_set_param         =   r_i2s_set_param;

    // RAM
    assign  o_en_ram                =   r_en_ram;
    assign  o_im2col_addressing     =   r_im2col_addressing;

  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule
