// Instance: /home/cowboy/target/spi/rtl/spi_clkgen.v
// Instance: /home/cowboy/target/spi/rtl/spi_rx.v
// Instance: /home/cowboy/target/spi/rtl/spi_tx.v
module spi_master_controller (
  input  wire                     clk_i,             //system clock   
  input  wire                     rst_n_i,           //system reset
  
  input  wire               [7:0] spi_clk_div_i,     //spi clock prescaler
  input  wire                     spi_clk_div_vld_i, //spi clock prescaler valid

  input  wire              [31:0] stream_data_i,     //stream data
  input  wire                     stream_data_vld_i, //stream data valid
  output wire                     stream_data_rdy_o, //stream data ready

  output wire              [31:0] spi_data_rx_o,     //stream spi rx data
  output wire                     spi_data_rx_vld_o, //stream spi rx data valid
  input  wire                     spi_data_rx_rdy_i, //stream spi rx data ready

  output wire                     spi_clk_o,         //spi clock
  output reg                      spi_cs_n_o,        //spi cs_n_o
  output wire                     spi_sdo_o,         //spi sdo
  input  wire                     spi_sdi_i,         //spi sdi

  output reg                      eot_o              //eot, end of transmission

);

parameter WR_REQ = 4'b1011;
parameter RD_REQ = 4'b1010;
/*************************regs & wires declare********************/
enum logic [2:0] {IDLE = 3'd0,CMD,ADDR,DUMMY,TX_DATA,RX_DATA,EOT} master_fsm;
  
  reg        spi_clock_en;  //spi clock enable
  wire       spi_rise_edge; //spi rising edge
  wire       spi_fall_edge; //spi falling edge

  reg        spi_tx_en;     //enable spi to write out
  reg        spi_rx_en;     //enable spi to read in

  reg     [3:0] cmd;        //command
  reg     [3:0] addr;       //address
  reg     [7:0] wr_rd_len;  //write length
  reg    [15:0] wr_data;    //write data

  reg    [31:0] data_tx;    //data to tx
  reg           data_tx_vld;

  reg    [15:0] tx_len;     // tx counter
  reg           tx_len_vld; // tx counter valid

  reg    [15:0] rx_len;     // rx counter
  reg           rx_len_vld; // rx counter valid

  wire          tx_done;
  wire          rx_done;
  
  wire          spi_rd_req;  //read command
  wire          spi_wr_req;  //write command

  reg    [7:0]  dummy_cnt;

//***********************************************//
  wire       go_idle;
  wire       go_cmd;
  wire       go_addr;
  wire       go_dummy;
  wire       go_tx_data;
  wire       go_rx_data;
  wire       go_eot;

//**************************preparation***************************//
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    {cmd,addr,wr_rd_len,wr_data}   <=  32'h0;
  end
  else if (eot_o) begin
    {cmd,addr,wr_rd_len,wr_data}   <=  32'h0;
  end
  else if((master_fsm == IDLE) && (stream_data_vld_i)) begin
    {cmd,addr,wr_rd_len,wr_data}   <=   stream_data_i;   
  end
end

assign spi_wr_req = (cmd == WR_REQ);
assign spi_rd_req = (cmd == RD_REQ);

//*********************spi clock module*************************//
//--------------------------------------------------------------

clk_gen spi_clkgen_i(/*autoinst*/
        //Inputs
        .clk_div_vld_i     (spi_clk_div_vld_i  ),
        .clk_i             (clk_i              ),
        .rst_n_i           (rst_n_i            ),
        .clock_en_i        (spi_clock_en       ),
        .clk_div_i         (spi_clk_div_i      ),
        //Outputs
        .fall_edge_o       (spi_fall_edge      ),
        .rise_edge_o       (spi_rise_edge      ),

        .clk_o             (spi_clk_o          ));

//***********************spi tx module***************************//
//----------------------------------------------------------------
spi_tx spi_tx_i(/*autoinst*/
        //Inputs
        .en_i             (spi_tx_en         ),
        .clk_i            (clk_i             ),
        .rst_n_i          (rst_n_i           ),
        .tx_edge_i        (spi_fall_edge     ),

        .tx_data_i        (data_tx           ),        
        .tx_length_i      (tx_len            ),
        .tx_length_updt_i (tx_len_vld        ),
        .tx_data_vld_i    (data_tx_vld       ),

        //Outputs
        .tx_data_rdy_o    (data_tx_rdy       ),
        .tx_done_o        (tx_done           ),
        .sdo_o            (spi_sdo_o         )
);

//********************* spi rx module *************************//
//--------------------------------------------------------------
spi_rx spi_rx_i(/*autoinst*/
        //Inputs
        .en_i             (spi_rx_en         ),
        .clk_i            (clk_i             ),
        .rst_n_i          (rst_n_i           ),
        
        .sdi_i            (spi_sdi_i         ),

        .rx_edge_i        (spi_rise_edge     ),
        .rx_length_i      (rx_len            ),
        .rx_length_updt_i (rx_len_vld        ),

        .rx_data_rdy_i    (spi_data_rx_rdy_i ),
        //Outputs
        .rx_done_o        (rx_done           ),
        .rx_data_o        (spi_data_rx_o     ),
        .rx_data_vld_o    (spi_data_rx_vld_o));


//****************************************************************//
/*********************FSM jump control****************************/
//****************************************************************//

assign go_cmd      = (master_fsm == IDLE) && (stream_data_vld_i) &&
                     ((spi_rd_req)|(spi_wr_req));
assign go_addr     = (master_fsm == CMD)  && (tx_done);
assign go_dummy    = (master_fsm == ADDR) && (tx_done);
assign go_rx_data  = (master_fsm == DUMMY) && (dummy_cnt == 'd2) && (spi_rd_req);
assign go_tx_data  = (master_fsm == DUMMY) && (dummy_cnt == 'd2) && (spi_wr_req);
assign go_eot      = ((master_fsm == TX_DATA )&&(tx_done))||
                     ((master_fsm == RX_DATA )&&(rx_done));
assign go_idle     = (master_fsm == EOT)&&(spi_fall_edge);

/******************************************************************/
/*************************FSM jump flow****************************/
/******************************************************************/

always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    master_fsm   <=  IDLE;
  end
  else begin
    case (master_fsm)
//idle
      IDLE                  : if (go_cmd) begin 
                                master_fsm <= CMD;
                              end

      CMD                   : if (go_addr) begin
                                master_fsm <= ADDR;
                              end

      ADDR                  : if (go_dummy) begin
                                master_fsm <= DUMMY;
                              end

      DUMMY                 : if (go_tx_data) begin
                                master_fsm <= TX_DATA;
                              end
                              else if(go_rx_data) begin
                                master_fsm <= RX_DATA;
                              end

      TX_DATA               : if (go_eot) begin
                                master_fsm <= EOT;
                              end

      RX_DATA               : if (go_eot) begin
                                master_fsm <= EOT;
                              end

      EOT                   : if (go_idle) begin
                                master_fsm <= IDLE;
                              end

      default               : master_fsm <= IDLE;
    endcase
  end
end

//******************middle signal/enable siganl generated*****************//
//------------------------------------------------------------------------//

//Clock enable
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    spi_clock_en   <=  'd0;
  end
  else if(go_cmd) begin
    spi_clock_en   <=  'd1;   
  end
  else if(go_idle)begin
    spi_clock_en   <=  'd0;
  end
end

//spi tx module enable
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    spi_tx_en   <=  'd0;
  end
  else if(go_cmd || go_addr || go_tx_data) begin
    spi_tx_en   <=  'd1;   
  end
  else if(go_dummy || go_eot)begin
    spi_tx_en   <=  'd0;
  end
end

//spi rx module enable
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    spi_rx_en   <=  'd0;
  end
  else if(go_rx_data) begin
    spi_rx_en   <=   'd1;   
  end
  else if(go_eot) begin
    spi_rx_en   <=   'd0;
  end
end

//tx length enable
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    tx_len       <=  'd0;
    tx_len_vld   <=  'd0;
  end
  else if((master_fsm == CMD)||(master_fsm == ADDR)) begin
    tx_len       <=  'd4;
    tx_len_vld   <=  'd1;  
  end
  else if(master_fsm == TX_DATA )begin
    tx_len       <=  wr_rd_len;
    tx_len_vld   <=  'd1;
  end
  else begin
    tx_len       <=  'd0;
    tx_len_vld   <=  'd0;    
  end
end

//rx_length enable
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    rx_len       <=  'd0;
    rx_len_vld   <=  'd0;
  end
  else if(master_fsm == RX_DATA )begin
    rx_len       <=  wr_rd_len;
    rx_len_vld   <=  'd1;
  end
  else begin
    rx_len       <=  'd0;
    rx_len_vld   <=  'd0;    
  end
end

//data_tx 
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    data_tx      <=  'd0;
    data_tx_vld  <=  'd0;
  end
  else if(go_cmd) begin
    data_tx      <=   {cmd,28'h0};
    data_tx_vld  <=   'd1;
  end
  else if(go_addr) begin
    data_tx      <=   {addr,28'h0};
    data_tx_vld  <=   'd1;
  end
  else if (go_tx_data) begin
    data_tx      <=   {wr_data,16'h0};
    data_tx_vld  <=   'd1;    
  end
  else if (go_dummy||go_eot||go_idle) begin
    data_tx      <=  'd0;
    data_tx_vld  <=  'd0;    
  end
end

//dummy counter
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    dummy_cnt   <=  'd0;
  end
  else if (go_dummy) begin
    dummy_cnt   <=  'd0;
  end
  else if(master_fsm == DUMMY && spi_fall_edge) begin
    dummy_cnt   <=   dummy_cnt +  'd1;   
  end
end

// spi_cs_n_o
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    spi_cs_n_o   <=  'd1;
  end
  else if(go_cmd) begin
    spi_cs_n_o   <=  'd0;   
  end
  else if(go_eot)begin
    spi_cs_n_o   <=  'd1;
  end
end
always @(posedge clk_i or negedge rst_n_i) begin
  if (!rst_n_i) begin
    eot_o   <=  'd0;
  end
  else if(master_fsm == EOT) begin
    eot_o   <=   'd1;   
  end
  else if(master_fsm == IDLE)begin
    eot_o   <=   'd0;
  end
end
endmodule
