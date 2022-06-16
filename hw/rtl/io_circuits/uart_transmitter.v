module uart_transmitter #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200)
(
    input clk,
    input rst,

    // Enqueue the to-be-sent character
    input [7:0] data_in,
    input data_in_valid,
    output data_in_ready,    

    // Serial bit output, 8 bit data, 1 stop bit!
    output serial_out
);

localparam SAMPLE_TIME          = CLOCK_FREQ/BAUD_RATE - 1;  //宽度?
localparam CLOCK_COUNTER_WIDTH  = 10;
//FSM status
localparam IDLE = 1'b0;
localparam BUSY = 1'b1;

wire data_in_fire = data_in_valid & data_in_ready;
reg [CLOCK_COUNTER_WIDTH-1:0] main_counter; //用来确定何时对输入信号采样
reg [4:0]                     bit_counter ; //确定当前计数到哪一个比特
reg                           status      ; // 


//shift reg 
//keep shift...
reg [8:0] shift_reg_tx;
wire[8:0] shift_reg_next;
wire      shift_reg_en;
wire      shift_reg_data_in;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        shift_reg_tx <= 9'b111111111;
    end 
    else if(shift_reg_en) begin
        shift_reg_tx <= shift_reg_next;
    end
end
assign shift_reg_data_in = data_in_fire;
//先发低位
assign shift_reg_next = shift_reg_data_in ? {data_in, 1'b0}:
                        { 1'b1, shift_reg_tx[8:1]};

assign shift_reg_en = shift_reg_data_in || main_counter == SAMPLE_TIME;

//FSM
reg     next_status;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        status <= IDLE;
    end 
    else begin
        status <= next_status;
    end
end

always @(*) begin
    case (status)
        IDLE: next_status = data_in_valid;
        BUSY: next_status = bit_counter == 5'd9 && main_counter == SAMPLE_TIME ? IDLE : BUSY;
        default: next_status = IDLE;
    endcase
end

//main_counter 
//main_counter keep going
wire[CLOCK_COUNTER_WIDTH-1:0]    main_counter_next;
wire                             main_counter_rst;

assign  main_counter_rst = rst | data_in_fire;   //开始校准时钟

always @(posedge clk or posedge main_counter_rst) begin
    if(main_counter_rst) begin
        main_counter <= {CLOCK_COUNTER_WIDTH{1'b0}};
    end
    else begin                          
        main_counter <= main_counter_next;
    end
end

assign main_counter_next = (main_counter == SAMPLE_TIME ) ? {CLOCK_COUNTER_WIDTH{1'b0}} :  //
                           main_counter + {{CLOCK_COUNTER_WIDTH-1{1'b0}}, 1'b1};

//bit_counter 
wire [4:0]   bit_counter_next;
wire         bit_counter_rst;

assign       bit_counter_rst = rst | data_in_fire;  //校准时钟
always @(posedge clk or posedge bit_counter_rst) begin
    if(bit_counter_rst) begin
        bit_counter <= 5'b0;
    end
    else begin                      //在收受状态内，使能counter
        bit_counter <= bit_counter_next;
    end
end
assign bit_counter_next = (main_counter == SAMPLE_TIME) ? bit_counter + 5'b1 : bit_counter;//


assign data_in_ready = ~status;
assign serial_out = shift_reg_tx[0];

endmodule
