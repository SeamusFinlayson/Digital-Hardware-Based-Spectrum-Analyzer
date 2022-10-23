//DFT.sv - turns 4 samples into a frequency domain signal
//Seamus Finlayson 2022-04-04

`define SAMPLING_DELAY 0
`define OUTPUT_DELAY 0
`define COMP_START_DELAY 0
`define ADC_SAMPLING_PERIOD 16

module dft (
	//basic input signals
    input logic clk, reset_n,   		// clock and reset
	
	//to hdmi module
	output logic valid,					//output is valid
	
	//output to hdmi component
	output logic signed [31:0] mag0,
	output logic signed [31:0] mag1, 
	output logic signed [31:0] mag2, 
	output logic signed [31:0] mag3, 
	//output logic signed [31:0] magX[4], //4 bit dft output
	
	//testing signals (comment out after testing)
	//input logic [11:0] sample,			//simulate input from adc interface
	
	//ADC signals, must be pin planned in top level module
	output ADC_CONVST, ADC_SCK, ADC_SDI,
	input ADC_SDO,
	input logic [2:0] adc_channel //ADC channel to sample
);

//square root module instatiation ##################################################

parameter WIDTH = 32;
parameter FBITS = 0;
logic sqrt_done = 0;
logic sqrt_start;
logic [31:0] sumsqu1;
//logic signed [31:0] mag1; 
logic busy; //not used
logic [WIDTH-1:0] rem; //not used

//compute the magnitude of the dft for complex terms
sqrt #(.WIDTH(WIDTH), .FBITS(FBITS)) sqrt_0 (
	.clk,
	.start(sqrt_start),
	.valid(sqrt_done),
	.rad(sumsqu1), 
	.root(mag1),
	.busy,
	.rem
);

//AD2 module instantiation #########################################################

// ADC result, should be sampled every 17 cycles for new result
logic [11:0] adcValue;   

// ADC interface module
adcinterface(
	.clk, 
	.reset_n, 
	.chan(adc_channel),
	.result(adcValue), //data sample stable on negedge clk
	.ADC_CONVST, 
	.ADC_SCK, 
	.ADC_SDI, 
	.ADC_SDO
);

//state machine ####################################################################

//STATE MEANINGS: SamPling, Computing Start, COmputing dft, OUtput valid
enum logic [1:0] {SP, CS, CO, OU} state, next_state;
logic [4:0] count, next_count;

//determine next state and count
always_comb begin

//change state and reset count when count down complete
	if(count == '0) begin
	
		//state trasitions based on counter
		case (state)
			SP : next_state = CS;
			CS : next_state = CO;
			CO : next_state = CO; //state transition based on sqrt valid not count
			OU : next_state = SP; 
		endcase
		
		// set time to remain in new state
		case (state)
			OU: next_count = `SAMPLING_DELAY; //updates sample in 1 cycle
			//could be removed
			SP: next_count = `COMP_START_DELAY; //tell sqrt to start for 1 cycle
			CO: next_count = `OUTPUT_DELAY; //output is valid for 1 cycle
			//end
			default: next_count = '0;
		endcase

	//normal incrementation for count and state
	end else begin
		next_count = count - 1;  // count down to zero
		next_state = state; // default to current state
	end
end

//flip flop driving state machine
always_ff @(negedge clk, negedge reset_n) 
	if (~reset_n) begin
		count <= `SAMPLING_DELAY;
		state <= SP;
	end else if (state == CO && sqrt_done == 1) begin
		state = OU;
	end else begin
		count <= next_count;
		state <= next_state;
	end
	
//state based signals ##############################################################

always_comb begin
	case (state)
		CS : sqrt_start = 1;
		default : begin sqrt_start = 0; end
	endcase
	
	case (state)
		OU : valid = 1;
		default : begin valid = 0;end
	endcase
	
end

//ADC counter ######################################################################
//sample continuously and update to a new valid sample set during SP (sampling state)
//the adc interface gets a new sample every 17 clk cycles

logic [4:0] adc_count, adc_next_count;

//logic for count change
always_comb begin

	//reset counter
	if(adc_count == '0) begin
		adc_next_count = `ADC_SAMPLING_PERIOD;

	//normal incrementation for counter
	end else begin
		adc_next_count = adc_count - 1;  // count down to zero
	end
end

//flip flop driving adc counter
always_ff @(posedge clk, negedge reset_n) 
	if (~reset_n) begin
		adc_count <= `ADC_SAMPLING_PERIOD;
	end else begin
		adc_count <= adc_next_count;
	end

//sampling from ADC ################################################################

logic [11:0] sample;
logic [11:0] samples [4];
logic signed [31:0] samples_int [4];

//buffer to store samples
always_ff @(negedge clk, negedge reset_n)
	if (~reset_n)
		for (int i = 0;i < 4;i++)
			samples[i] <= '0;
	else if (adc_count == 16) begin
		samples[3] <= samples[2];
		samples[2] <= samples[1];
		samples[1] <= samples[0];
		samples[0] <= sample;
	end else
		samples <= samples;

//get sample from ad2 at 17 cycle intervals
always_ff @(negedge clk, negedge reset_n)
	if (~reset_n)
		sample <= 0;
	else if (adc_count == 0)
		sample <= adcValue;
	else
		sample <= sample;

//provide samples to dft computation
always_ff @(posedge clk, negedge reset_n)
	if (~reset_n)
		for (int i = 0;i < 4;i++)
			samples_int[i] <= '0;
	else if (state == SP)
		for (int i = 0;i < 4;i++)
			samples_int[i] <= samples[i];
	else
		for (int i = 0;i < 4;i++)
			samples_int[i] <= samples_int[i];
    
    /*always_comb begin
        samples_int[0] = 4;
        samples_int[1] = 3;
        samples_int[2] = 2;
        samples_int[3] = 1;
    end*/

//DFT math #########################################################################

//not actually int, just 32 bits and signed, and i dont want to change names again
logic signed [31:0] real1;
logic signed [32:0] real1_abs;

logic signed [31:0] imaginary1;
logic signed [31:0] imaginary1_abs;

logic signed [31:0] magX_int [4];
logic signed [31:0] magX_int_abs [4];
/*
logic signed [31:0] mag0;

logic signed [31:0] mag2; 
logic signed [31:0] mag3; 
*/
always_comb begin

//addition and multiplication for dft
	magX_int[0] = samples_int[0] + samples_int[1] + samples_int[2] + samples_int[3];
	
	magX_int[2] = samples_int[0] - samples_int[1] + samples_int[2] - samples_int[3];
	
	real1 = samples_int[0] - samples_int[2];
	imaginary1 = samples_int[3] - samples_int[1];
	
//take the absolute value of the integer signals
	//mag0, already positive
	magX_int_abs[0] = magX_int[0];
	
	//mag2, can be made positive by switching polarity
	if (magX_int[2] < 0)
		magX_int_abs[2] = -magX_int[2];
	else
		magX_int_abs[2] = magX_int[2];

	//mag1, real and imaginary components must be made positive
	if (real1 < 0)
		real1_abs = -real1;
	else
		real1_abs = real1;

	if (imaginary1 < 0)
		imaginary1_abs = -imaginary1;
	else
		imaginary1_abs = imaginary1;
	
	//mag1 is completed in the sqrt_0 module
	sumsqu1 = real1_abs**2 + imaginary1_abs**2;
	
	//mag3, same as mag1 by symetry
	magX_int_abs[3] = magX_int_abs[1];
	
	//actually display magX!!! (ModelSim testing)
	mag0 = magX_int_abs[0];
	mag2 = magX_int_abs[2];
	mag3 = mag1;
	
	//set outputs from dft module (maybe make mag0-3 the module output)
	/*
	magX[0] = mag0;
	magX[1] = mag1;
	magX[2] = mag2;
	magX[3] = mag3;
	*/
		
end

//testing signal connections #######################################################
// (comment out after testing)



endmodule