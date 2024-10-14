`timescale 1ns / 1ps

module npu_control(
    input       wire                            i_clk,
    input       wire                            i_n_reset,
    input       wire            [1 : 0]         i_op_mode,
    input       wire                            i_terminate,

    output      wire                            o_im2col_set_param,
    output      wire                            o_f2r_set_param,
    output      wire                            o_pu_set_param,

    input       wire                            i_image_ready,
    input       wire                            i_filter_ready,
    input       wire                            i_pu_ready,

    input       wire                            i_i2c_slice_last,
    input       wire                            i_f2r_slice_last,

    output      wire                            o_start_mac,
    output      wire                            o_start_pool,
    
    input       wire                            i_pu_mac_done,
    input       wire                            i_pool_done,

    output      wire                            o_i2c_term,
    output      wire                            o_f2r_term,
    output      wire                            o_pu_term,
    output      wire                            o_pool_term,

    output      wire            [1 : 0]         o_sel_local_buffer,
    output      wire                            o_en_local_buffer,
    input       wire                            i_local_buffer_read_done,
    output      wire            [3 : 0]         o_state,

    output      wire                            o_done
);
    // Parameters
                localparam      [1 : 0]         MODE_NOP        =   2'b00;
                localparam      [1 : 0]         MODE_POOL       =   2'b01;
                localparam      [1 : 0]         MODE_MVM        =   2'b10;
                localparam      [1 : 0]         MODE_CONV       =   2'b11;

                localparam      [1 : 0]         BUF_SEL_NONE    =   2'b00;
                localparam      [1 : 0]         BUF_SEL_PU      =   2'b01;
                localparam      [1 : 0]         BUF_SEL_POOL    =   2'b10;
                localparam      [1 : 0]         BUF_SEL_CTRL    =   2'b11;

                localparam      [3 : 0]         IDLE            =   4'h0;
                localparam      [3 : 0]         POOL_SETUP      =   4'h1;
                localparam      [3 : 0]         MAC_SETUP       =   4'h2;
                localparam      [3 : 0]         MAC             =   4'h3;
                localparam      [3 : 0]         CHECK           =   4'h4;
                localparam      [3 : 0]         LAST            =   4'h5;
                localparam      [3 : 0]         POOL            =   4'h6;
                localparam      [3 : 0]         DATA_OUT        =   4'h7;
                localparam      [3 : 0]         DONE            =   4'h8;

    // State Register
                reg             [3 : 0]         present_state;
                reg             [3 : 0]         next_state;

    // Control Register
                reg                             r_im2col_set_param;
                reg                             r_f2r_set_param;
                reg                             r_pu_set_param;
                reg                             r_start_mac;
                reg                             r_start_pool;
                reg                             r_i2c_term;
                reg                             r_f2r_term;
                reg                             r_pu_term;
                reg                             r_pool_term;
                reg             [1 : 0]         r_sel_local_buffer;
                reg                             r_en_local_buffer;
                reg                             r_done;

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
            r_im2col_set_param      <=      0;
            r_f2r_set_param         <=      0;
            r_pu_set_param          <=      0;
            r_start_mac             <=      0;
            r_start_pool            <=      0;
            r_i2c_term              <=      0;
            r_f2r_term              <=      0;
            r_pu_term               <=      0;
            r_pool_term             <=      0;
            r_sel_local_buffer      <=      BUF_SEL_NONE;
            r_en_local_buffer       <=      0;
            r_done                  <=      0;
        end
        else begin
            case (present_state)
                IDLE    : begin
                    if (i_op_mode == MODE_POOL) begin
                        next_state              <=      POOL_SETUP;
                        r_sel_local_buffer      <=      BUF_SEL_POOL;
                        r_im2col_set_param      <=      1;
                    end
                    else if (i_op_mode == MODE_CONV || i_op_mode == MODE_MVM) begin
                        next_state              <=      MAC_SETUP;
                        r_sel_local_buffer      <=      BUF_SEL_PU;
                        r_im2col_set_param      <=      1;
                        r_f2r_set_param         <=      1;
                        r_pu_set_param          <=      1;
                    end
                    else begin
                        next_state              <=      IDLE;
                        r_sel_local_buffer      <=      BUF_SEL_NONE;
                        r_i2c_term              <=      0;
                        r_f2r_term              <=      0;
                        r_pu_term               <=      0;
                        r_pool_term             <=      0;
                    end
                end

                MAC_SETUP : begin
                    if (i_image_ready && i_filter_ready && i_pu_ready) begin
                        next_state              <=      MAC;
                        r_start_mac             <=      1;
                        r_im2col_set_param      <=      0;
                        r_f2r_set_param         <=      0;
                        r_pu_set_param          <=      0;
                    end
                    else begin
                        next_state              <=      MAC_SETUP;
                    end
                end

                POOL_SETUP : begin
                    if (i_image_ready) begin
                        next_state              <=      POOL;
                        r_start_pool            <=      1;
                        r_im2col_set_param      <=      0;
                    end
                    else begin
                        next_state              <=      POOL_SETUP;
                    end
                end

                MAC     :   begin
                    if (i_pu_mac_done) begin
                        next_state              <=      CHECK;
                        r_start_mac             <=      0;
                    end
                    else begin
                        next_state              <=      MAC;
                        r_start_mac             <=      0;
                    end
                end

                CHECK   :   begin
                    if (i_i2c_slice_last && i_f2r_slice_last) begin
                        next_state              <=      LAST;
                        r_start_mac             <=      1;
                        r_im2col_set_param      <=      0;
                        r_f2r_set_param         <=      0;
                        r_pu_set_param          <=      0;
                    end
                    else if (i_image_ready && i_filter_ready && i_pu_ready) begin
                        next_state              <=      MAC;
                        r_start_mac             <=      1;
                        r_im2col_set_param      <=      0;
                        r_f2r_set_param         <=      0;
                        r_pu_set_param          <=      0;
                    end
                    else begin
                        next_state              <=      CHECK;
                    end
                end

                LAST    :   begin
                    if (i_pu_mac_done) begin
                        next_state              <=      DATA_OUT;
                        r_sel_local_buffer      <=      BUF_SEL_CTRL;
                        r_en_local_buffer       <=      1;
                    end
                    else begin
                        next_state              <=      LAST;
                    end
                end

                POOL    :   begin
                    if (i_pool_done) begin
                        next_state              <=      DATA_OUT;
                        r_sel_local_buffer      <=      BUF_SEL_CTRL;
                        r_en_local_buffer       <=      1;
                    end
                    else begin
                        next_state              <=      POOL;
                    end
                end

                DATA_OUT : begin
                    if (i_local_buffer_read_done) begin
                        next_state              <=      DONE;
                        r_start_pool            <=      0;
                        r_en_local_buffer       <=      0;
                        r_sel_local_buffer      <=      BUF_SEL_NONE;
                        r_done                  <=      1;
                    end
                    else begin
                        next_state              <=      DATA_OUT; 
                    end
                end

                DONE    :   begin
                    if (i_terminate) begin
                        next_state              <=      IDLE;
                        r_im2col_set_param      <=      0;
                        r_f2r_set_param         <=      0;
                        r_pu_set_param          <=      0;
                        r_start_mac             <=      0;
                        r_start_pool            <=      0;
                        r_i2c_term              <=      1;
                        r_f2r_term              <=      1;
                        r_pu_term               <=      1;
                        r_pool_term             <=      1;
                        r_sel_local_buffer      <=      BUF_SEL_NONE;
                        r_en_local_buffer       <=      0;
                        r_done                  <=      0;
                    end
                    else begin
                        next_state              <=      DONE;
                    end
                end

                default : begin
                        next_state              <=      IDLE;
                        r_im2col_set_param      <=      1'bz;
                        r_f2r_set_param         <=      1'bz;
                        r_pu_set_param          <=      1'bz;
                        r_start_mac             <=      1'bz;
                        r_start_pool            <=      1'bz;
                        r_i2c_term              <=      1'bz;
                        r_f2r_term              <=      1'bz;
                        r_pu_term               <=      1'bz;
                        r_pool_term             <=      1'bz;
                        r_sel_local_buffer      <=      BUF_SEL_NONE;
                        r_en_local_buffer       <=      1'bz;
                        r_done                  <=      1'bz;
                end
            endcase
        end
    end

    assign o_im2col_set_param       =       r_im2col_set_param;
    assign o_f2r_set_param          =       r_f2r_set_param;
    assign o_pu_set_param           =       r_pu_set_param;
    assign o_start_mac              =       r_start_mac;
    assign o_start_pool             =       r_start_pool;
    assign o_i2c_term               =       r_i2c_term;
    assign o_f2r_term               =       r_f2r_term;
    assign o_pu_term                =       r_pu_term;
    assign o_pool_term              =       r_pool_term;
    assign o_sel_local_buffer       =       r_sel_local_buffer;
    assign o_en_local_buffer        =       r_en_local_buffer;
    assign o_done                   =       r_done;
    assign o_state                  =       present_state;

endmodule
