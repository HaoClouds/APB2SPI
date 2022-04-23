module clk_gen (
  input  wire                    clk_i,           //system clock
  input  wire                    rst_n_i,         //system reset, low active
  input  wire                    clock_en_i,      //spi clock enable

  input  wire              [7:0] clk_div_i,       //divider prescalar
  input  wire                    clk_div_vld_i,

  output reg                     clk_o,           //spi clock
  output wire                    fall_edge_o,
  output wire                    rise_edge_o
);


reg  [7:0]  cnt;             

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    cnt   <=  'd0;
  end
  else if(cnt == (clk_div_i>>1)-1'b1 || (!clock_en_i) || (!clk_div_vld_i)) begin
    cnt   <=  'd0;   
  end
  else begin
    cnt   <=   cnt + 1'b1;
  end
end  

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    clk_o   <=  'd0;
  end
  else if((!clock_en_i)||(!clk_div_vld_i)) begin
    clk_o   <=  'd0;   
  end
  else if(cnt == (clk_div_i>>1) - 1'b1)begin
    clk_o   <=   ~clk_o;
  end
end


assign rise_edge_o = (cnt == (clk_div_i>>1) - 1'b1) && (~clk_o);
assign fall_edge_o = (cnt == (clk_div_i>>1) - 1'b1) &&    clk_o;

endmodule
