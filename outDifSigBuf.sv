// ELEX 7660 Project - Differential Signal Output Buffer
// This module will create a differential signal ready
// for output given on its input signal and 2 output
// lines.
// Michael Andrews 2021/04/03

module outDifSigBuf ( input logic in, output logic out, outB);
    always_ff @* out = in;
    always_ff @* outB = ~in;
endmodule