`timescale 1ns / 1ps

module f2r_control(
        // System
        input       wire                        i_clk,
        input       wire                        i_n_reset,

        // Local Control
        input       wire                        i_set_param,
        input       wire                        i_start_mac,
        input       wire                        i_terminate,
        input       wire        [15 : 0]        i_slice_number,
        output      wire                        o_filter_ready,
        output      wire                        o_done,

        // Filter 2 Row
        input       wire                        i_f2r_set_param_done,
        output      wire                        o_f2r_enable,
        output      wire                        o_f2r_read,
        input       wire                        i_f2r_slice_last,
        input       wire                        i_f2r_slice_read_done,
        output      wire                        o_f2r_set_param,

        // Filter 2 Systolic
        output      wire                        o_f2s_enable,
        output      wire                        o_f2s_read,
        input       wire                        i_f2s_read_done,

        output      wire                        o_f2s_set_param,
        input       wire                        i_f2s_set_param_done,

        // ram
        input       wire                        i_ram_read_done,
        output      wire                        o_en_ram
    );

    // Paramaeters
                    localparam      [2 : 0]     IDLE        =   3'h0;
                    localparam      [2 : 0]     SET_PARAM   =   3'h1;
                    localparam      [2 : 0]     CONVERT     =   3'h2;
                    localparam      [2 : 0]     SYS         =   3'h3;
                    localparam      [2 : 0]     WAIT        =   3'h4;
                    localparam      [2 : 0]     READ        =   3'h5;
                    localparam      [2 : 0]     CHECK       =   3'h6;
                    localparam      [2 : 0]     DONE        =   3'h7;

    // State Register
                    reg             [2 : 0]     present_state;
                    reg             [2 : 0]     next_state;

    // Local Control
                    reg                         r_filter_ready;
                    reg                         r_done;

    // Filter 2 Row
                    reg                         r_f2r_enable;
                    reg                         r_f2r_read;
                    reg                         r_f2r_set_param;
    
    // Filter 2 Systolic
                    reg                         r_f2s_enable;
                    reg                         r_f2s_read;
                    reg                         r_f2s_set_param;

    // RAM
                    reg                         r_en_ram;

    always @(negedge i_clk) begin : STATE_TRANSITION
        if (!i_n_reset) begin
            present_state <= IDLE;
        end
        else begin
            present_state <= next_state;
        end
    end

    always @(posedge i_clk) begin
        if (!i_n_reset) begin
            next_state          <=      IDLE;
            r_f2r_set_param     <=      0;
            r_f2s_set_param     <=      0;
            r_filter_ready      <=      0;
            r_done              <=      0;
            r_f2r_enable        <=      0;
            r_f2r_read          <=      0;
            r_f2s_enable        <=      0;
            r_f2s_read          <=      0;
            r_en_ram            <=      0;
        end
        else begin
            case (present_state)
                IDLE    : begin
                    if (i_set_param) begin
                        next_state          <=      SET_PARAM;
                        r_f2r_set_param     <=      1;
                        r_f2s_set_param     <=      1;
                    end
                    else begin
                        next_state          <=      IDLE;
                    end
                end

                SET_PARAM : begin
                    if (i_f2r_set_param_done && i_f2s_set_param_done) begin
                        next_state          <=      CONVERT;
                        r_f2r_set_param     <=      0;
                        r_f2s_set_param     <=      0;
                        r_en_ram            <=      1;
                        r_f2r_enable        <=      1;
                    end
                    else begin
                        next_state          <=      SET_PARAM;
                    end
                end

                CONVERT : begin
                    if (i_ram_read_done) begin
                        next_state          <=      SYS;
                        r_en_ram            <=      0;
                        r_f2r_read          <=      1;
                        r_f2s_enable        <=      1;
                    end
                    else begin
                        next_state          <=      CONVERT;
                    end
                end

                SYS : begin
                    if (i_f2r_slice_read_done) begin
                        next_state          <=      WAIT;
                        r_f2r_read          <=      0;
                        r_f2s_enable        <=      0;
                        r_filter_ready      <=      1;
                    end
                    else begin
                        next_state          <=      SYS;
                    end
                end

                WAIT : begin
                    if (i_start_mac) begin
                        next_state          <=      READ;
                        r_f2s_read          <=      1;
                        r_filter_ready      <=      0;
                    end
                    else begin
                        next_state          <=      WAIT;
                    end
                end

                READ : begin
                    if (i_f2s_read_done) begin
                        next_state          <=      CHECK;
                        r_f2s_read          <=      0;
                        r_done              <=      1;
                    end
                    else begin
                        next_state          <=      READ;
                    end
                end

                CHECK : begin
                    if (i_slice_number > 1 && i_f2r_slice_last) begin
                        next_state          <=      DONE;
                    end
                    else begin
                        next_state          <=      SYS;
                        r_f2r_read          <=      1;
                        r_f2s_enable        <=      1;
                        r_done              <=      0;
                    end
                end

                DONE : begin
                    if (i_terminate) begin
                        next_state          <=      IDLE;
                        r_f2r_set_param     <=      0;
                        r_f2s_set_param     <=      0;
                        r_filter_ready      <=      0;
                        r_done              <=      0;
                        r_f2r_enable        <=      0;
                        r_f2r_read          <=      0;
                        r_f2s_enable        <=      0;
                        r_f2s_read          <=      0;
                        r_en_ram            <=      0;
                    end
                    else begin
                        next_state          <=      DONE;
                    end
                end

                default : begin
                        next_state          <=      IDLE;
                        r_f2r_set_param     <=      0;
                        r_f2s_set_param     <=      0;
                        r_filter_ready      <=      0;
                        r_done              <=      0;
                        r_f2r_enable        <=      0;
                        r_f2r_read          <=      0;
                        r_f2s_enable        <=      0;
                        r_f2s_read          <=      0;
                        r_en_ram            <=      0;
                end
            endcase
        end
    end

    // Local Control
    assign  o_filter_ready          =           r_filter_ready;
    assign  o_done                  =           r_done;

    // Filter 2 Row
    assign  o_f2r_enable            =           r_f2r_enable;
    assign  o_f2r_read              =           r_f2r_read;

    // Filter 2 Systolic
    assign  o_f2s_enable            =           r_f2s_enable;
    assign  o_f2s_read              =           r_f2s_read;

    // f2r f2s parameters
    assign  o_f2r_set_param         =           r_f2r_set_param;
    assign  o_f2s_set_param         =           r_f2s_set_param;

    // ram
    assign  o_en_ram                =           r_en_ram;

  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule
