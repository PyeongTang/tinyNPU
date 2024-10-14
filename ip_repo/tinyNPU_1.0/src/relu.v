`timescale 1ns / 1ps

module relu (
    input       wire        signed      [31 : 0]        i_acc,
    output      wire                    [31 : 0]        o_relu
);

assign o_relu     =       (i_acc > 0) ? i_acc : 0;
    
endmodule
