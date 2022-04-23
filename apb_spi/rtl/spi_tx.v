module spi_tx (
  input  wire                    clk_i,            //system clock
  input  wire                    rst_n_i,          //system reset

  input  wire                    en_i,             //enable

  input  wire                    tx_edge_i,        //slk edge

  output wire                    sdo_o,            //output data,real spi 
  output wire                    tx_done_o, 

  input  wire             [15:0] tx_length_i,      //data length
  input  wire                    tx_length_updt_i, //update data length enable

  input  wire             [31:0] tx_data_i,        //data from CPU
  input  wire                    tx_data_vld_i,    //data valid
  output wire                    tx_data_rdy_o
);

/*************************regs & wires declare********************/
enum logic [0:0] {IDLE = 1'b0,TRANSMIT} tx_fsm;

  wire        go_idle;
  wire        go_transmit;

  wire        bit_en;
  wire        bit_clr;

  reg  [31:0] tx_data;
  reg  [15:0] tx_counter;      //bits counter

  reg  [15:0] tx_length_trgt;  // target counter

  wire        word_done;

//*********************counter condition**************************//
always @(posedge clk_i or negedge rst_n_i) begin
  if (~rst_n_i) begin
    tx_length_trgt  <=  'd0;
  end
  else if(tx_length_updt_i) begin
    tx_length_trgt  <=  tx_length_i; 
  end
end

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    tx_counter   <=  'd0;
  end
  else if(bit_clr) begin
    tx_counter   <=   'd0;   
  end
  else if(bit_en)begin
    tx_counter   <=   tx_counter + 'd1;
  end
end

assign bit_en        = (tx_fsm == TRANSMIT) && (tx_edge_i);
assign bit_clr       =  go_transmit;

assign word_done     = (tx_counter[4:0] == 5'b11111) && tx_edge_i;
assign tx_done_o     = (tx_counter == (tx_length_trgt-1)) && tx_edge_i;
//****************************************************************//
/*********************FSM jump control****************************/
//****************************************************************//

assign go_transmit = (tx_fsm == IDLE) && en_i && tx_data_vld_i;
assign go_idle     = (tx_fsm == TRANSMIT) && ((tx_done_o)||
                     (word_done && ~tx_data_vld_i));

/******************************************************************/
/*************************FSM jump flow****************************/
/******************************************************************/

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    tx_fsm   <=  IDLE;
  end
  else begin
    case (tx_fsm)
//idle
      IDLE                  : if (go_transmit) begin
                                tx_fsm <= TRANSMIT;
                              end

      TRANSMIT              : if (go_idle) begin
                                tx_fsm <= IDLE;
                              end

      default               : tx_fsm <= IDLE;
    endcase
  end
end

/******************************************************************/
/************************  FSM output  ****************************/
/******************************************************************/
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    tx_data   <=  'd0;
  end
  else if(go_transmit || (word_done && tx_data_vld_i)) begin
    tx_data   <=   tx_data_i;   
  end
  else if((tx_fsm == TRANSMIT) && tx_edge_i && (~tx_done_o))begin
    tx_data   <=   {tx_data[30:0],tx_data[31]};
  end
end

assign tx_data_rdy_o = (tx_fsm == IDLE);
assign sdo_o         = tx_data[31];

endmodule
