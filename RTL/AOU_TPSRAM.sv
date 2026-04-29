/*
Two port SRAM
   Port A : Read port
   Port B : Write port

*/

module AOU_TPSRAM #(
    parameter RAM_DATA_WIDTH = 32,
    parameter RAM_ADDR_WIDTH = 16
) (
    // Read Port 
    input  wire                      CLKA,
    input  wire                      CENA,
    input  wire [RAM_ADDR_WIDTH-1:0] AA,
    output reg  [RAM_DATA_WIDTH-1:0] QA,
    
    // Write Port
    input  wire                      CLKB,
    input  wire                      CENB,
    input  wire [RAM_ADDR_WIDTH-1:0] AB,
    input  wire [RAM_DATA_WIDTH-1:0] DB
);

   reg [RAM_DATA_WIDTH-1:0] mem [(2**RAM_ADDR_WIDTH)-1:0];

   always @(posedge CLKA) begin 
      if (!CENA) QA <= mem[AA];
      //else       QA <= 'hz; 
   end

   always @(posedge CLKB) begin 
      if (!CENB) mem[AB] <= DB;
   end

endmodule
