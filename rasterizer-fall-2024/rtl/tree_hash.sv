/*
 *  Hashing Function
 *
 *  Inputs:
 *    N-Wide Signal
 *
 *  Outputs:
 *    M-Bit Hashed signal
 *
 *  Function:
 *    Calc a simple hash value useing an xor tree
 *
 *
 *
 *   Author: John Brunhaver
 *   Created:      Thu 10/01/10
 *   Last Updated: Tue 10/16/10
 *
 *   Copyright 2010 <jbrunhaver@gmail.com>
 *
 */

/* ***************************************************************************
 * Change bar:
 * -----------
 * Date           Author    Description
 * Sep 19, 2012   jingpu    ported from John's original code to Genesis
 *
 * ***************************************************************************/

/******************************************************************************
 * PARAMETERIZATION
 * ***************************************************************************/
//; # module parameters
//; my $in_width   = parameter(Name=>'InWidth',
//;                            Val=>40, Min=>40, Step=>1, Max=>40,
//;                            Doc=>"Width of Input");
//; my $out_width  = parameter(Name=>'OutWidth',
//;                            Val=>8, Min=>8, Step=>1, Max=>8,
//;                            Doc=>"Width of output");
//; # Note that these are not yet configurable
//; # this module depends on these statements being 40,8
//; # note that it is possible to build a recursive version
//; # of this module which can generically build a hash tree
//; # for arbitrary N and M.
//; # General strategy:
//; #   *Reduce input to a width that (2^n) * Output Width
//; #   *Swizel and reduce to 2^(n-1) and repeat

/* A Note on Signal Names:
 *
 * Most signals have a suffix of the form _RxxN
 * where R indicates that it is a Raster Block signal
 * xx indicates the clock slice that it belongs to
 * and N indicates the type of signal that it is.
 * H indicates logic high, L indicates logic low,
 * U indicates unsigned fixed point, and S indicates
 * signed fixed point.
 *
 */

module tree_hash
#(
    parameter IN_WIDTH = 40,
    parameter OUT_WIDTH = 8
)
(
    // Input Signals
    input logic unsigned [IN_WIDTH-1:0]      in_RnnH, //Input signal to derive hash from
    input logic unsigned [OUT_WIDTH-1:0]     mask_RnnH, //A mask to apply to the hashed output
    // Output Signals
    output logic unsigned [OUT_WIDTH-1:0]    out_RnnH   //Output signal that has been hashed and masked
);

    logic unsigned [31:0]       arr32_RnnH;
    logic unsigned [15:0]       arr16_RnnH;

    // Zero pad up to 40 digits.
    logic unsigned [40 - 1:0]   arr40_RnnH;    

    // IN_WIDTH that this is brittle and will break for any config that isn't 40:8
    assign arr40_RnnH = {3'b0, in_RnnH[33:17], 3'b0, in_RnnH[16:0]};
    assign arr32_RnnH[7:0]   = arr40_RnnH[7:0]   ^ arr40_RnnH[15:8]  ; // 0 = 0 ^ 1
    assign arr32_RnnH[15:8]  = arr40_RnnH[15:8]  ^ arr40_RnnH[23:16] ; // 1 = 1 ^ 2
    assign arr32_RnnH[23:16] = arr40_RnnH[23:16] ^ arr40_RnnH[31:24] ; // 2 = 2 ^ 3
    assign arr32_RnnH[31:24] = arr40_RnnH[31:24] ^ arr40_RnnH[39:32] ; // 3 = 3 ^ 4

    assign arr16_RnnH[7:0] = arr32_RnnH[7:0] ^ arr32_RnnH[23:16] ; // 0 = 0 ^ 2
    assign arr16_RnnH[15:8] = arr32_RnnH[15:8] ^ arr32_RnnH[31:24] ; // 1 ^ 3

    assign out_RnnH[OUT_WIDTH-1:0] = ( arr16_RnnH[7:0] ^ arr16_RnnH[15:8] ) & mask_RnnH[OUT_WIDTH-1:0] ;

endmodule



