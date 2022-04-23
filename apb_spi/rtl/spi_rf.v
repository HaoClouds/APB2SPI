`define CMD     4'd0  //0x00
`define ADDR    4'd1  //0x04
`define LEN     4'd2  //0x08
`define WDATA   4'd3  //0x0c
`define RDATA   4'd4  //0x10
`define CTRL    4'd5  //0x14


module spi_rf (

  //APB interface
  input  wire                   pclk_i,
  input  wire                   prst_n_i,
  
  input  wire                   psel_i,
  input  wire                   penable_i,
  input  wire  [31:0]           paddr_i,
  input  wire                   pwrite_i,  //high: write; low:read
  input  wire  [31:0]           pwdata_i,

  output reg   [31:0]           prdata_o,
  output reg                    pready_o,

  //rdata
  input  wire  [31:0]           spi_data_rx_i, 
  input  wire                   spi_data_rx_vld_i,

  //eot
  input                         eot_i,

  //control signals
  output wire  [31:0]           stream_data_o,  
  output wire                   stream_data_vld_o,

  //configuration
  output wire  [7:0]            spi_clk_div_o,
  output wire                   spi_clk_div_vld_o
);

//--------------------reg & wire definition -----------------//
reg  [31:0] regs [0:5];
wire        wr_en;
wire        rd_en;
wire [2:0]  addr_offset;   //address index

assign pready_o    = 1'b1;                             //no wait
assign wr_en       = psel_i & penable_i & pwrite_i;    //write enable
assign rd_en       = psel_i & penable_i & (~pwrite_i); //read enable
assign addr_offset = paddr_i [31:2];                   //address divided by 4

//-----------------------------write domain----------------------------//
always @(posedge pclk_i or negedge prst_n_i) begin
  if (!prst_n_i) begin
    regs[`CMD  ] <= 'h0;
    regs[`ADDR ] <= 'h0;
    regs[`LEN  ] <= 'h0;
    regs[`WDATA] <= 'h0;
    regs[`RDATA] <= 'h0;
    regs[`CTRL ] <= 'h0;
  end
  else if (eot_i) begin
    regs[`CTRL][0]  <= 1'b0;
  end
  else if(wr_en) begin
    case (addr_offset)
     `CMD             : begin
                          regs[`CMD]   <=  pwdata_i; 
                        end
     `ADDR            : begin
                          regs[`ADDR]  <=  pwdata_i; 
                        end
     `LEN             : begin
                          regs[`LEN]   <=  pwdata_i; 
                        end
     `WDATA           : begin
                          regs[`WDATA] <=  pwdata_i; 
                        end
     `CTRL            : begin
                          regs[`CTRL]  <=  pwdata_i; 
                        end
     default          : begin

                        end
    endcase
  end
end 

//output to spi
assign stream_data_o     =  {regs[`CMD][3:0],regs[`ADDR][3:0],regs[`LEN][7:0],regs[`WDATA][15:0]}; 
assign stream_data_vld_o =   regs[`CTRL][0];
//clock divider 
assign spi_clk_div_o     =   regs[`CTRL][15:8];
assign spi_clk_div_vld_o =   1'b1;


//----------------------------read domain---------------------------//

//read preparation
always @(posedge pclk_i or negedge prst_n_i) begin
  if (!prst_n_i) begin
    regs[`RDATA]   <=  'h0;
  end
  else if(spi_data_rx_vld_i) begin
    regs[`RDATA]   <=   spi_data_rx_i;   
  end
end
//register operation
always @(posedge pclk_i or negedge prst_n_i) begin
  if (!prst_n_i) begin
    prdata_o   <=  32'h0bad_da7a;
  end
  else if(rd_en) begin
     case (addr_offset) 
       `CMD             : begin
                             prdata_o  <= regs[`CMD];
                          end
       `ADDR            : begin
                             prdata_o  <= regs[`ADDR];
                          end                          
       `LEN             : begin
                             prdata_o  <= regs[`LEN];
                          end
       `RDATA           : begin
                             prdata_o  <= regs[`RDATA];
                          end        
       `WDATA           : begin
                             prdata_o  <= regs[`WDATA];
                          end
       `CTRL            : begin
                             prdata_o  <= regs[`CTRL];
                          end        
        default         : begin
          
                          end
    endcase
  end
end

endmodule
//Do I need write it more advanced?

//always @(posedge pclk_i or negedge prst_n_i) begin
//  if (!prst_n_i) begin
//    stream_data_o      <=  'd0;
//    stream_data_vld_o  <=  'd0;
//  end
//  else if(eot_i && pwrite_i) begin
//    stream_data_o      <= {cmd_reg,addr_reg,len_reg,wdata_reg};
//    stream_data_vld_o  <=  'd1;
//  end
//end 
//
//always @(posedge pclk_i or negedge prst_n_i) begin
//  if (!prst_n_i) begin
//    spi_clk_div_o     <=   'd0;
//    spi_clk_div_vld_o  <=  'd0;
//  end
//  else if(eot_i && pwrite_i) begin
//    spi_clk_div_o      <=   ctrl_reg;
//    spi_clk_div_vld_o  <=  'd1;
//  end
//end 
//
// When do I push out the data? wait the end of register select?
// Or just in following way?
//assign pwdata_en         = psel_i & pwrite_i & penable_i & eot_i;
//assign stream_data_o     = pwdata_en ?  {cmd_reg,addr_reg,len_reg,wdata_reg} : stream_data_o;
//assign stream_data_vld_o = pwdata_en ?  1 : 0;
//
//assign spi_clk_div_o     = pwdata_en ?  ctrl_reg : spi_clk_div_o;
//assign spi_clk_div_vld_o = pwdata_en ?  1 : 0;
//
////---------------------------read data---------------------------//
//
//assign 
//
//endmodule
