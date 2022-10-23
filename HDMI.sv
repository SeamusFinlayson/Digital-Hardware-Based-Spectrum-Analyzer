// ELEX 7660 Project - HDMI
// Module that takes in the magnitude values from a
// 4-point DFT and outputs the values as blocks on
// any HDMI complaint display.
// Michael Andrews 2021/03/29

module HDMI( input pixelClk, input [1:0] redMag, blueMag, greenMag, whiteMag, output [2:0] TMDSp, TMDSn, output TMDSp_clock, TMDSn_clock );

    //Logic values for use in the module
    logic [9:0] X, Y;
    logic [9:0] shiftTMDS_Red = 0, shiftTMDS_Green = 0, shiftTMDS_Blue = 0;
    logic [7:0] red, green, blue;
    logic [5:0] colorCount;
    logic [3:0] TMDScounter = 0;
    logic hSync, vSync, DrawArea;
    logic shiftTMDS_Load = 0;
    logic [1:0] redMag_sync, greenMag_sync, blueMag_sync, whiteMag_sync;

    //Wires Necessary for the module
    wire [7:0] W = {8 {X [7:0] == Y[7:0]}};
    wire [7:0] A = {8 {X [7:5] == 3'h2 && Y[7:5] == 3'h2}};
    wire [9:0] TMDS_red, TMDS_green, TMDS_blue, clk_TMDS;

    //PLL to multiple the 25 MHz clock by 10 to be 250 MHz
    pll_two pll_two_0( .inclk0(pixelClk), .c0(clk_TMDS));

    //Block to drive the actual visuals and H/Vsync
    always_ff @( posedge pixelClk ) begin

        //1 if within the set resolution
        DrawArea <= (X < 640) && (Y < 480);
        //increments and resets the X counter
        if (X == 799)
            X <= 0;
        else 
            X <= X+1;
        //increments and resets the Y counter
        if (X == 799) begin
            if (Y == 524)
                Y <= 0;
            else
                Y <= Y+1;
        end

        //Hsync and Vsync signals.
        //Sets values to 1 if the X and Y positon is
        //outside the resolution and in the H/Vsync area
        hSync <= (X >= 656) && (X < 752);
        vSync <= (Y >= 490) && (Y < 492);

        if(X == 0 && Y == 0) begin
            redMag_sync <= redMag;
            greenMag_sync <= greenMag;
            blueMag_sync <= blueMag;
            whiteMag_sync <= whiteMag;
        end

        //Creates blocks of increasing height depending on the
        //magnitude passed by the audio DFT module.
        if (X < 160 && Y < 120*redMag_sync) begin
            red <= 'b10101010; 
            green <= 'b0;   //Red block for lowest frequency bin
            blue <= 'b0;
        end
        else if (X >= 160 && X < 320 && Y < 120*greenMag_sync) begin
            red <= 'b0;
            green <= 'b10101010;//green block for second lowest frequency bin
            blue <= 'b0;
        end
        else if (X >= 320 && X < 480 && Y < 120*blueMag_sync) begin
            red <= 'b0;
            green <= 'b0;   //green block for second highest frequency bin
            blue <= 'b10101010;
        end
        else if (X >= 480 && X < 640 && Y < 120*whiteMag_sync) begin
            red <= 'b11111111;
            green <= 'b11111111;//white block for highest frequency bin
            blue <= 'b11111111;
        end
        else begin
            red <= 'b0;
            green <= 'b0;   //Colors the drawable area black otherwise
            blue <= 'b0;
        end
    end

    //Converts the 8 bit color values to 10 bit encoded values.
    //Bits are encoded to lower the amount of switching between
    //bit values as well as to DC balance them.
    TMDS_encoder encode_Red( .clk(pixelClk), .VD(red), .CD(2'b00), .VDE(DrawArea), .TMDS(TMDS_red) );
    TMDS_encoder encode_Green( .clk(pixelClk), .VD(green), .CD(2'b00), .VDE(DrawArea), .TMDS(TMDS_green) );
    TMDS_encoder encode_Blue( .clk(pixelClk), .VD(blue), .CD({vSync, hSync}), .VDE(DrawArea), .TMDS(TMDS_blue) );

    //Shift register to shift the next bit into the ouput buffer at 250 MHz
    always_ff @( posedge clk_TMDS ) begin

        //Sets to 1 when the counter reaches 9
        shiftTMDS_Load <= (TMDScounter == 'd9);

        //Loads the current value if the load flag is not set.
        //Otherwise loads the encoded value.
	    shiftTMDS_Red   <= shiftTMDS_Load ? TMDS_red   : shiftTMDS_Red  [9:1];
	    shiftTMDS_Green <= shiftTMDS_Load ? TMDS_green : shiftTMDS_Green[9:1];
	    shiftTMDS_Blue  <= shiftTMDS_Load ? TMDS_blue  : shiftTMDS_Blue [9:1];	
    
        //Counts from 0 to 9 (For all 10 bits in the frame)
	    if (TMDScounter == 'd9)
            TMDScounter <= 'd0;
        else
            TMDScounter <= TMDScounter + 'd1;
    end 

    //Bank of buffers to create the differential signal needed for HDMI. All signals out
    //are buffered.
    outDifSigBuf outDifSigBuf_red  ( .in(shiftTMDS_Red  [0]), .out(TMDSp[2]), .outB(TMDSn[2]) );
    outDifSigBuf outDifSigBuf_green( .in(shiftTMDS_Green[0]), .out(TMDSp[1]), .outB(TMDSn[1]) );
    outDifSigBuf outDifSigBuf_blue ( .in(shiftTMDS_Blue [0]), .out(TMDSp[0]), .outB(TMDSn[0]) );
    outDifSigBuf outDifSigBuf_clock( .in(pixelClk), .out(TMDSp_clock), .outB(TMDSn_clock) );

endmodule

// megafunction wizard: %ALTPLL%
// ...
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
// ...

//This PLL is to multiply the input pixel clock by 10,
//as there is 10 bits per pixel.
module pll_two ( inclk0, c0);

        input     inclk0;
        output    c0;

        wire [0:0] sub_wire2 = 1'h0;
        wire [4:0] sub_wire3;
        wire  sub_wire0 = inclk0;
        wire [1:0] sub_wire1 = {sub_wire2, sub_wire0};
        wire [0:0] sub_wire4 = sub_wire3[0:0];
        wire  c0 = sub_wire4;

        altpll altpll_component ( .inclk (sub_wire1), .clk
          (sub_wire3), .activeclock (), .areset (1'b0), .clkbad
          (), .clkena ({6{1'b1}}), .clkloss (), .clkswitch
          (1'b0), .configupdate (1'b0), .enable0 (), .enable1 (),
          .extclk (), .extclkena ({4{1'b1}}), .fbin (1'b1),
          .fbmimicbidir (), .fbout (), .fref (), .icdrclk (),
          .locked (), .pfdena (1'b1), .phasecounterselect
          ({4{1'b1}}), .phasedone (), .phasestep (1'b1),
          .phaseupdown (1'b1), .pllena (1'b1), .scanaclr (1'b0),
          .scanclk (1'b0), .scanclkena (1'b1), .scandata (1'b0),
          .scandataout (), .scandone (), .scanread (1'b0),
          .scanwrite (1'b0), .sclkout0 (), .sclkout1 (),
          .vcooverrange (), .vcounderrange ());

        defparam
                altpll_component.bandwidth_type = "AUTO",
                altpll_component.clk0_divide_by = 1,
                altpll_component.clk0_duty_cycle = 50,
                altpll_component.clk0_multiply_by = 10, //pixel clock x 10
                altpll_component.clk0_phase_shift = "0",
                altpll_component.compensate_clock = "CLK0",
                altpll_component.inclk0_input_frequency =40000,
                altpll_component.intended_device_family = "Cyclone IV E",
                altpll_component.lpm_hint = "CBX_MODULE_PREFIX=lab1clk",
                altpll_component.lpm_type = "altpll",
                altpll_component.operation_mode = "NORMAL",
                altpll_component.pll_type = "AUTO",
                altpll_component.port_activeclock = "PORT_UNUSED",
                altpll_component.port_areset = "PORT_UNUSED",
                altpll_component.port_clkbad0 = "PORT_UNUSED",
                altpll_component.port_clkbad1 = "PORT_UNUSED",
                altpll_component.port_clkloss = "PORT_UNUSED",
                altpll_component.port_clkswitch = "PORT_UNUSED",
                altpll_component.port_configupdate = "PORT_UNUSED",
                altpll_component.port_fbin = "PORT_UNUSED",
                altpll_component.port_inclk0 = "PORT_USED",
                altpll_component.port_inclk1 = "PORT_UNUSED",
                altpll_component.port_locked = "PORT_UNUSED",
                altpll_component.port_pfdena = "PORT_UNUSED",
                altpll_component.port_phasecounterselect = "PORT_UNUSED",
                altpll_component.port_phasedone = "PORT_UNUSED",
                altpll_component.port_phasestep = "PORT_UNUSED",
                altpll_component.port_phaseupdown = "PORT_UNUSED",
                altpll_component.port_pllena = "PORT_UNUSED",
                altpll_component.port_scanaclr = "PORT_UNUSED",
                altpll_component.port_scanclk = "PORT_UNUSED",
                altpll_component.port_scanclkena = "PORT_UNUSED",
                altpll_component.port_scandata = "PORT_UNUSED",
                altpll_component.port_scandataout = "PORT_UNUSED",
                altpll_component.port_scandone = "PORT_UNUSED",
                altpll_component.port_scanread = "PORT_UNUSED",
                altpll_component.port_scanwrite = "PORT_UNUSED",
                altpll_component.port_clk0 = "PORT_USED",
                altpll_component.port_clk1 = "PORT_UNUSED",
                altpll_component.port_clk2 = "PORT_UNUSED",
                altpll_component.port_clk3 = "PORT_UNUSED",
                altpll_component.port_clk4 = "PORT_UNUSED",
                altpll_component.port_clk5 = "PORT_UNUSED",
                altpll_component.port_clkena0 = "PORT_UNUSED",
                altpll_component.port_clkena1 = "PORT_UNUSED",
                altpll_component.port_clkena2 = "PORT_UNUSED",
                altpll_component.port_clkena3 = "PORT_UNUSED",
                altpll_component.port_clkena4 = "PORT_UNUSED",
                altpll_component.port_clkena5 = "PORT_UNUSED",
                altpll_component.port_extclk0 = "PORT_UNUSED",
                altpll_component.port_extclk1 = "PORT_UNUSED",
                altpll_component.port_extclk2 = "PORT_UNUSED",
                altpll_component.port_extclk3 = "PORT_UNUSED",
                altpll_component.width_clock = 5;
endmodule