`timescale 1ns / 1ps

module bram #(
  parameter RAM_WIDTH = 8,
  parameter RAM_DEPTH = 16 * 3,
  parameter RAM_PERFORMANCE = "LOW_LATENCY",
  parameter INIT_FILE = ""
) (
  input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,           // RAM input data
  input clka,                           // Clock
  input wea,                            // Write enable
  input ena,                            // RAM Enable, for additional power savings, disable port when not in use
  input flush,
  output [RAM_WIDTH-1:0] douta          // RAM output data
);

  reg [RAM_WIDTH-1:0] r_BRAM [0 : RAM_DEPTH-1];
  reg [RAM_WIDTH-1:0] ram_data = {RAM_WIDTH{1'b0}};
  integer i;

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      integer ram_index;
      initial begin
        $readmemh(INIT_FILE, r_BRAM, 0, 1023);
        for (ram_index = 1024; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          r_BRAM[ram_index] = {RAM_WIDTH{1'b0}};
      end
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          r_BRAM[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  always @(posedge clka) begin
    if (flush) begin
      for (i = 0; i < RAM_DEPTH; i = i + 1)
        r_BRAM[i] = {RAM_WIDTH{1'b0}};
      ram_data <= 0;
    end
    else begin
      if (ena)
        if (wea)
          r_BRAM[addra] <= dina;
        else
          ram_data <= r_BRAM[addra];
    end
  end
    assign douta = ram_data;

  //  The following function calculates the address width based on specified RAM depth
  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule
