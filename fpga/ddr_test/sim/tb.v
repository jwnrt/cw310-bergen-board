/* 
ChipWhisperer Bergen Target - Simple testbench to check for signs of life.

Copyright (c) 2021, NewAE Technology Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted without restriction. Note that modules within
the project may have additional restrictions, please carefully inspect
additional licenses.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of NewAE Technology Inc.
*/

`timescale 1ns / 1ns
`default_nettype none 

`include "cw310_defines.v"

module tb();
    parameter pADDR_WIDTH = 20;
    parameter pBYTECNT_SIZE = 7;
    parameter pUSB_CLOCK_PERIOD = 10;
    parameter pPLL_CLOCK_PERIOD = 6;
    parameter pSEED = 1;
    parameter pTIMEOUT = 30000;
    parameter pVERBOSE = 0;
    parameter pDUMP = 0;

    reg usb_clk;
    reg usb_clk_enable;
    wire [7:0] usb_data;
    reg [7:0] usb_wdata;
    reg [pADDR_WIDTH-1:0] usb_addr;
    reg usb_rdn;
    reg usb_wrn;
    reg usb_cen;
    reg usb_trigger;

    reg j16_sel;
    reg k16_sel;
    reg pushbutton;
    reg pll_clk1;
    wire tio_clkin;
    wire trig_out;

    wire [7:0] leds;

    wire tio_trigger;
    wire tio_clkout;

    int seed;
    int errors;
    int warnings;
    int i;
    
    reg [31:0] write_data;

    wire clk = pll_clk1;  // shorthand for testbench

   int cycle;
   int total_time;

   reg [127:0] read_data;
   reg [127:0] expected_cipher = 128'h8a278bf8fa2812bc39e52c76205af377;


   initial begin
      seed = pSEED;
      errors = 0;
      warnings = 0;
      $display("Running with seed=%0d", seed);
      $urandom(seed);
      if (pDUMP) begin
         $dumpfile("results/tb.fst");
         $dumpvars(0, tb);
      end
      usb_clk = 1'b1;
      usb_clk_enable = 1'b1;
      pll_clk1 = 1'b1;

      usb_wdata = 0;
      usb_addr = 0;
      usb_rdn = 1;
      usb_wrn = 1;
      usb_cen = 1;
      usb_trigger = 0;

      j16_sel = 1;
      k16_sel = 0;
      pushbutton = 1;
      pll_clk1 = 0;

      #(pUSB_CLOCK_PERIOD*2) pushbutton = 0;
      #(pUSB_CLOCK_PERIOD*2) pushbutton = 1;
      #(pUSB_CLOCK_PERIOD*10);


      $display("done!");
      #(pUSB_CLOCK_PERIOD*10);
      if (errors)
         $display("SIMULATION FAILED (%0d errors, %0d warnings).", errors, warnings);
      else
         $display("Simulation passed (%0d warnings).", warnings);
      $finish;

   end

   // maintain a cycle counter
   always @(posedge clk) begin
      if (pushbutton == 0)
         cycle <= 0;
      else
         cycle <= cycle + 1;
   end


   // timeout thread:
   initial begin
      #(pUSB_CLOCK_PERIOD*pTIMEOUT);
      errors += 1;
      $display("ERROR: global timeout");
      $display("SIMULATION FAILED (%0d errors).", errors);
      $finish;
   end


   reg read_select;

   assign usb_data = read_select? 8'bz : usb_wdata;
   assign tio_clkin = pll_clk1;

   always @(*) begin
      if (usb_wrn == 1'b0)
         read_select = 1'b0;
      else if (usb_rdn == 1'b0)
         read_select = 1'b1;
   end

   `include "tb_cw305_reg_tasks.v"

   always #(pUSB_CLOCK_PERIOD/2) usb_clk = !usb_clk;
   always #(pPLL_CLOCK_PERIOD/2) pll_clk1 = !pll_clk1;

   wire #1 usb_rdn_out = usb_rdn;
   wire #1 usb_wrn_out = usb_wrn;
   wire #1 usb_cen_out = usb_cen;
   wire #1 usb_trigger_out = usb_trigger;

   wire trigger; // TODO: use it?

   cw310_top #(
      .pBYTECNT_SIZE            (pBYTECNT_SIZE),
      .pUSB_ADDR_WIDTH          (pADDR_WIDTH)
   ) U_dut (
      .usb_clk                  (usb_clk & usb_clk_enable),
      .USB_D                    (usb_data),
      .USB_A                    (usb_addr),
      .USB_nRD                  (usb_rdn_out),
      .USB_nWR                  (usb_wrn_out),
      .USB_nCE                  (usb_cen_out),
      .usb_trigger              (usb_trigger_out),
      .USRDIP                   ({6'b0, k16_sel, j16_sel}),
      .USRSW2                   (pushbutton),
      .USRLED                   (leds),
      .PLL_CLK1                 (usb_clk),
      .CWIO_IO4                 (trigger),
      .CWIO_HS1                 (),             // unused
      .CWIO_HS2                 (tio_clkin),
      .vauxp0                   (1'b0),
      .vauxn0                   (1'b0),
      .vauxp1                   (1'b0),
      .vauxn1                   (1'b0),
      .vauxp8                   (1'b0),
      .vauxn8                   (1'b0),
      .LVDS_XO_200M_ENA         (),

      .SYSCLK_P                 (1'b0),
      .SYSCLK_N                 (1'b0),

      .vddr_pgood               (1'b0)
   );


endmodule

`default_nettype wire

