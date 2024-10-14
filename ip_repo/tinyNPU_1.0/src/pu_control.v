`timescale 1ns / 1ps

module pu_control(
    // System
    input       wire                        i_clk,
    input       wire                        i_n_reset,
    input       wire                        i_terminate,

    // Local control
    input       wire                        i_set_param,
    input       wire                        i_start_mac,
    output      wire                        o_pu_ready,
    input       wire                        i_mac_done,
    output      wire                        o_mac_done,

    // PU
    input       wire                        i_set_param_done,
    output      wire                        o_set_param,

    output      wire                        o_enable,
    output      wire                        o_read,
    input       wire                        i_read_done,

    // Local Buffer
    output      wire                        o_en_local_buffer,
    output      wire                        o_wr_local_buffer
);

                localparam      [2 : 0]     IDLE        =   3'h0;
                localparam      [2 : 0]     SET_PARAM   =   3'h1;
                localparam      [2 : 0]     WAIT        =   3'h2;
                localparam      [2 : 0]     MAC         =   3'h3;
                localparam      [2 : 0]     READ        =   3'h4;
                localparam      [2 : 0]     CHECK       =   3'h5;
                localparam      [2 : 0]     DONE        =   3'h6;

                reg             [2 : 0]     present_state;
                reg             [2 : 0]     next_state;

    // Local Control
                reg                         r_pu_ready;
                reg                         r_mac_done;

    // PU
                reg                         r_enable;
                reg                         r_read;

    // Param
                reg                         r_set_param;

    // Local buffer
                reg                         r_en_local_buffer;
                reg                         r_wr_local_buffer;
                reg                         r_en_local_buffer_z;
                reg                         r_wr_local_buffer_z;

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
            next_state                  <=      IDLE;
            r_pu_ready                  <=      0;
            r_mac_done                  <=      0;
            r_enable                    <=      0;
            r_read                      <=      0;
            r_set_param                 <=      0;
            r_en_local_buffer           <=      0;
            r_wr_local_buffer           <=      0;
       end 
       else if (i_terminate) begin
            next_state                  <=      IDLE;
            r_pu_ready                  <=      0;
            r_mac_done                  <=      0;
            r_enable                    <=      0;
            r_read                      <=      0;
            r_set_param                 <=      0;
            r_en_local_buffer           <=      0;
            r_wr_local_buffer           <=      0;
       end
       else begin
            case (present_state)
                IDLE    : begin
                    if (i_set_param) begin
                        next_state                  <=      SET_PARAM;
                        r_set_param                 <=      1;
                    end
                    else begin
                        next_state                  <=      IDLE;
                    end
                end
                SET_PARAM : begin
                    if (i_set_param_done) begin
                        next_state                  <=      WAIT;
                        r_set_param                 <=      0;
                        r_pu_ready                  <=      1;
                    end
                    else begin
                        next_state                  <=      SET_PARAM;
                    end
                end
                WAIT : begin
                    if (i_start_mac) begin
                        next_state                  <=      MAC;
                        r_enable                    <=      1;
                        r_pu_ready                  <=      0;
                        r_mac_done                  <=      0;
                    end
                    else begin
                        next_state                  <=      WAIT;
                    end
                end
                MAC : begin
                    if (i_mac_done) begin
                        next_state                  <=      READ;
                        r_read                      <=      1;
                        r_en_local_buffer           <=      1;
                        r_wr_local_buffer           <=      1;
                    end
                    else begin
                        next_state                  <=      MAC;
                    end
                end
                READ : begin
                    if (i_read_done) begin
                        next_state                  <=      CHECK;
                        r_enable                    <=      0;
                        r_read                      <=      0;
                        r_mac_done                  <=      1;
                        r_en_local_buffer           <=      0;
                        r_wr_local_buffer           <=      0;
                    end
                    else begin
                        next_state                  <=      READ;
                    end
                end
                CHECK : begin
                    if (i_terminate) begin
                        next_state                  <=      DONE;
                        r_pu_ready                  <=      0;
                        r_mac_done                  <=      0;
                        r_enable                    <=      0;
                        r_read                      <=      0;
                        r_set_param                 <=      0;
                        r_en_local_buffer           <=      0;
                        r_wr_local_buffer           <=      0;
                    end
                    else begin
                        next_state                  <=      WAIT;
                        r_pu_ready                  <=      1;
                        r_enable                    <=      0;
                        r_mac_done                  <=      0;
                    end
                end
                DONE : begin
                    next_state <= IDLE;
                end
                default : next_state <= IDLE;
            endcase
       end
    end

    always @(posedge i_clk) begin : DELAY_ENABLING_LOCAL_BUFFER
        if (!i_n_reset) begin
            r_en_local_buffer_z         <=      0;
            r_wr_local_buffer_z         <=      0;
        end
        else if (i_terminate) begin
            r_en_local_buffer_z         <=      0;
            r_wr_local_buffer_z         <=      0;
        end
        else begin
            r_en_local_buffer_z         <=      r_en_local_buffer;
            r_wr_local_buffer_z         <=      r_wr_local_buffer;
        end
    end

    assign  o_pu_ready                  =   r_pu_ready;
    assign  o_mac_done                  =   r_mac_done;
    assign  o_enable                    =   r_enable;
    assign  o_read                      =   r_read;
    assign  o_set_param                 =   r_set_param;

    // Local Buffer
    assign  o_en_local_buffer           =   r_en_local_buffer & r_en_local_buffer_z;
    assign  o_wr_local_buffer           =   r_wr_local_buffer & r_wr_local_buffer_z;

endmodule
