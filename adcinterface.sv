//adcinterface.sv - continuously gets values from adc
//Seamus Finlayson 2022-01-32

`define SAMPLING_DELAY 11
`define CONV_START_DELAY 0
`define WAIT_2 2

module adcinterface(
    input logic clk, reset_n,   // clock and reset 
    input logic [2:0] chan,     // ADC channel to sample 
    output logic [11:0] result, // ADC result 
     
    // ltc2308 signals, out from module, into ADC
    output logic ADC_CONVST, ADC_SCK, ADC_SDI, //conversion start, serial output data clock, serial data input
    input logic ADC_SDO  //serial data out
);

//state related signals
enum logic [1:0] {SH, SL, SA, W2} state, next_state; //Conv_start_High, Conv_start_Low, SAmpling, Wait_2
logic [4:0] count, next_count;
logic [11:0] inter_result;

// determine next state and count
always_comb begin

	// change state and reset count when count down complete
	if(count == '0) begin //IMPORTANT MUST BE count NOT count_next
		
		//set next state on timer completion
		case (state)
			SH : next_state = SL;
			SL : next_state = SA;
			SA : next_state = W2;
			W2 : next_state = SH;
		endcase
		
		// set time to remain in new state
		if (next_state == SL || next_state == SH)
			next_count = `CONV_START_DELAY;
		else if (next_state == SA)
			next_count = `SAMPLING_DELAY;
		else
			next_count = `WAIT_2;
	end else begin
	
		//normal incrementation for count and state
		next_count = count - 1;  // count down to zero
		next_state = state; // default to current state
	end
end

//dont output partially complete result, alt code below
//assign result = (state == SA) ? result : inter_result;

//alternate code for above
always_ff @(posedge clk)
	if (state != SA)
		result = inter_result;
	else
		result = result;


//get data from ADC
//adc_sdo is stable on the rising edge
always_ff @(posedge clk, negedge reset_n)
	if (~reset_n)
		inter_result <= '0;
	else if (state == SA)
		inter_result[count] <= ADC_SDO;
	else
		inter_result <= inter_result;

//channel selection logic
//decoder based on 2308fb_adc.pdf pg 10
//using common as reference
logic [2:0] chan_select;

//channel select translator to adc
always_comb
	unique case (chan)
		0 : chan_select = 'b000;
		1 : chan_select = 'b100;
		2 : chan_select = 'b001;
		3 : chan_select = 'b101;
		4 : chan_select = 'b010;
		5 : chan_select = 'b110;
		6 : chan_select = 'b011;
		7 : chan_select = 'b111;
	endcase

//input to adc, select channel;
//"update adc_sdi on the falling edge"
always_ff @(negedge clk)
	if (state == SL)
		ADC_SDI <= 1;
	else if (state == SA && count == 11)
		ADC_SDI <= chan_select[2];
	else if (state == SA && count == 10)
		ADC_SDI <= chan_select[1];
	else if (state == SA && count == 9)
		ADC_SDI <= chan_select[0];
	else if (state == SA && count == 8)
		ADC_SDI <= 1;
	else
		ADC_SDI <= 0;

// store next state and count
always_ff @(negedge clk, negedge reset_n) 
	if (~reset_n) begin
		count <= `WAIT_2;
		state <= W2;
	end else begin
		count <= next_count;
		state <= next_state;
	end
	
//output signal: tell adc to start
always_comb begin 
	case (state)
		SH : ADC_CONVST = 1;
		default : ADC_CONVST = 0;
	endcase
end

//gate clk to adc_sck
assign ADC_SCK = (state == SA) ? clk : 1'b0;

endmodule
