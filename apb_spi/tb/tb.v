// Instance: /home/cowboy/target/apb_spi/rtl/apb_spi_master.v
module tb; 
  reg         psel_i;
  reg         pwrite_i;
  reg [31:0]  paddr_i;
  reg [31:0]  pwdata_i;
  reg         pclk_i;
  reg         prst_n_i;
  reg         penable_i;
  reg [15:0]  actual_data;
  wire        sclk_o;
  wire [31:0] prdata_o;
  always #5 pclk_i = ~pclk_i;

  initial begin
    pclk_i   = 0;
    prst_n_i = 0;
    #15;
    prst_n_i = 1;
  end

  initial begin
    psel_i    =  0;
    pwrite_i  =  0;
    paddr_i   =  'h0;
    pwdata_i  =  'h0;
    penable_i =  0;
    #10;
    @(posedge prst_n_i);
    apb_write(32'h0014,32'h0800);
    apb_write(32'h0000,32'h0b);
    @(posedge pclk_i);
    apb_write(32'h0004,32'h03);
    @(posedge pclk_i);
    apb_write(32'h0008,32'h10);
    @(posedge pclk_i);
    apb_write(32'h000c,32'h1234);
    @(posedge pclk_i);
    apb_write(32'h0014,32'h0801);
    #100;
    wait(tb.apb_spi_master_i.spi_master_controller_i.eot_o == 1);
    wait(tb.apb_spi_master_i.spi_master_controller_i.eot_o == 0);
    apb_write(32'h0014,32'h0800);
    @(posedge pclk_i); 
    apb_write(32'h0000,32'h0a);
    @(posedge pclk_i);
    apb_write(32'h0004,32'h03);
    @(posedge pclk_i);
    apb_write(32'h0008,32'h10);
    @(posedge pclk_i);
    apb_write(32'h0014,32'h0801);
    wait(tb.apb_spi_master_i.spi_master_controller_i.eot_o == 1);
    @(posedge pclk_i);
    apb_read(32'h10);

  end

initial begin
  #1;
  forever begin
    actual_data = 16'h1234;
    wait (tb.apb_spi_master_i.spi_master_controller_i.spi_rx_en == 1);
    repeat(15)begin
      @(negedge sclk_o);
      actual_data = {actual_data[15:0],1'b1};
    end
  end
end

apb_spi_master apb_spi_master_i(/*autoinst*/
        //Inputs
        .penable_i (penable_i      ),
        .psel_i    (psel_i         ),
        .pwdata_i  (pwdata_i       ),
        .pclk_i    (pclk_i         ),
        .pwrite_i  (pwrite_i       ),
        .prst_n_i  (prst_n_i       ),
        .paddr_i   (paddr_i        ),
        .sdi_i     (actual_data[15] ),
        //Outputs
        .pready_o  (pready_o       ),
        .sdo_o     (sdo_o          ),
        .sclk_o    (sclk_o         ),
        .cs_n_o    (cs_n_o         ),
        .prdata_o  (prdata_o       ));

task apb_write(input [31:0]addr,input [31:0]data);
 fork
  psel_i   = 1;
  pwrite_i = 1;
  paddr_i  = addr;
  pwdata_i = data;
 join
  @(posedge pclk_i);
  penable_i = 1;
  @(posedge pclk_i);
  penable_i = 0;
  psel_i    = 0;
endtask

task apb_read(input [31:0]addr);
 fork
  psel_i   = 1;
  pwrite_i = 0;
  paddr_i  = addr;
 join
  @(posedge pclk_i);
  penable_i = 1;
  @(posedge pclk_i);
  penable_i = 0;
  psel_i    = 0;
endtask

initial begin
  $fsdbDumpfile("tb.fsdb");
  $fsdbDumpvars(0,"tb");
  $fsdbDumpMDA(0,"tb");
end
endmodule
