module spi_rx (
  input  wire                    clk_i,
  input  wire                    rst_n_i,

  input  wire                    en_i,

  input  wire                    rx_edge_i,

  input  wire                    sdi_i,              //SPI interface
  output wire                    rx_done_o, 

  input  wire             [15:0] rx_length_i,
  input  wire                    rx_length_updt_i,

  output wire             [31:0] rx_data_o,          //maybe partial data valid
  output wire                    rx_data_vld_o,
  input  wire                    rx_data_rdy_i
);

/*************************regs & wires declare********************/
enum logic [0:0] {IDLE = 1'b0,RECIEVE} rx_fsm;

  wire        go_idle;
  wire        go_recieve;

  wire        bit_en;
  wire        bit_clr;

  reg  [31:0] rx_data;
  reg  [15:0] rx_counter;      //bits counter

  reg  [15:0] rx_length_trgt;  // target counter

  wire        word_done;

//*********************counter condition**************************//
always @(posedge clk_i or negedge rst_n_i) begin
  if (~rst_n_i) begin
    rx_length_trgt  <=  'd0;
  end
  else if(rx_length_updt_i) begin
    rx_length_trgt  <=  rx_length_i; 
  end
end

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    rx_counter   <=  'd0;
  end
  else if(bit_clr) begin
    rx_counter   <=   'd0;   
  end
  else if(bit_en)begin
    rx_counter   <=   rx_counter + 'd1;
  end
end

assign bit_en        = (rx_fsm == RECIEVE) && (rx_edge_i);
assign bit_clr       =  go_recieve;

assign word_done     = (rx_counter[4:0] == 5'b11111) && rx_edge_i;
assign rx_done_o     = (rx_counter == (rx_length_trgt-1)) && rx_edge_i;
//****************************************************************//
/*********************FSM jump control****************************/
//****************************************************************//

assign go_recieve = (rx_fsm == IDLE) && en_i && rx_data_rdy_i;
assign go_idle     = (rx_fsm == RECIEVE) && ((rx_done_o)||
                     (word_done && ~rx_data_rdy_i));

/******************************************************************/
/*************************FSM jump flow****************************/
/******************************************************************/

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    rx_fsm   <=  IDLE;
  end
  else begin
    case (rx_fsm)
//idle
      IDLE                  : if (go_recieve) begin
                                rx_fsm <= RECIEVE;
                              end

      RECIEVE              : if (go_idle) begin
                                rx_fsm <= IDLE;
                              end

      default               : rx_fsm <= IDLE;
    endcase
  end
end

/******************************************************************/
/************************  FSM output  ****************************/
/******************************************************************/
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    rx_data   <=  'd0;
  end
  else if (go_recieve) begin
    rx_data   <=  'd0;
  end
  else if((rx_fsm == RECIEVE) && rx_edge_i )begin
    rx_data   <=   {rx_data[30:0],sdi_i};
  end
end

assign rx_data_o     = rx_data;
assign rx_data_vld_o = (rx_fsm == IDLE);
endmodule
