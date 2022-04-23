// Instance: /home/cowboy/target/apb_spi/rtl/spi_master_controller.v
// Instance: /home/cowboy/target/apb_spi/rtl/spi_rf.v

module apb_spi_master (
  //APB_IF
  input  wire           pclk_i,
  input  wire           prst_n_i,

  input  wire           psel_i,
  input  wire           penable_i,
  input  wire    [31:0] paddr_i,
  input  wire           pwrite_i,
  input  wire    [31:0] pwdata_i,

  output wire    [31:0] prdata_o,
  output wire           pready_o,

  //SPI_IF
  output wire           sclk_o,
  output wire           cs_n_o,
  output wire           sdo_o,
  input  wire           sdi_i
);
wire             spi_clk_div_vld;
wire [7:0]       spi_clk_div;

wire [31:0]      spi_data_rx;
wire             spi_data_rx_vld;

wire [31:0]      stream_data;
wire             stream_data_vld;

wire             eot;
wire             spi_data_rx_rdy;

assign spi_data_rx_rdy = 1'b1;
// Instance: /home/cowboy/target/apb_spi/rtl/spi_master_controller.v
spi_master_controller spi_master_controller_i(/*autoinst*/
        //Inputs
        .spi_clk_div_vld_i (spi_clk_div_vld     ),
        .spi_data_rx_rdy_i (spi_data_rx_rdy     ),
        .spi_sdi_i         (sdi_i               ),
        .clk_i             (pclk_i              ),
        .stream_data_i     (stream_data  [31:0] ),
        .rst_n_i           (prst_n_i            ),
      
        .stream_data_vld_i (stream_data_vld     ),
        .spi_clk_div_i     (spi_clk_div[7:0]    ),
        //Outputs
        .stream_data_rdy_o (stream_data_rdy_o   ),
        .spi_clk_o         (sclk_o              ),
        .spi_data_rx_o     (spi_data_rx  [31:0] ),
        .spi_data_rx_vld_o (spi_data_rx_vld     ),
        .eot_o             (eot                 ),
        .spi_sdo_o         (sdo_o               ),
        .spi_cs_n_o        (cs_n_o              )
);
// Instance: /home/cowboy/target/apb_spi/rtl/spi_rf.v
spi_rf spi_rf_i(/*autoinst*/
        //Inputs
        .eot_i             (eot                 ),
        .spi_data_rx_vld_i (spi_data_rx_vld     ),
        .penable_i         (penable_i           ),
        .psel_i            (psel_i              ),
        .pwdata_i          (pwdata_i[31:0]      ),
        .pclk_i            (pclk_i              ),
        .pwrite_i          (pwrite_i            ),
        .prst_n_i          (prst_n_i            ),
        .spi_data_rx_i     (spi_data_rx  [31:0] ),
        .paddr_i           (paddr_i[31:0]       ),
        //Outputs
        .stream_data_vld_o (stream_data_vld     ),
        .spi_clk_div_o     (spi_clk_div[7:0]    ),
        .spi_clk_div_vld_o (spi_clk_div_vld     ),
        .pready_o          (pready_o            ),
        .prdata_o          (prdata_o[31:0]      ),
        .stream_data_o     (stream_data[31:0]   ));
  
endmodule
