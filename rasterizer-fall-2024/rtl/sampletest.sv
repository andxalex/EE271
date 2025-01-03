/*
 *  Performs Sample Test on triangle
 *
 *  Inputs:
 *    Sample and triangle Information
 *
 *  Outputs:
 *    Subsample Hit Flag, Subsample location, and triangle Information
 *
 *  Function:
 *    Utilizing Edge Equations determine whether the
 *    sample location lies inside the triangle.
 *    In the simple case of the triangle, this will
 *    occur when the sample lies to one side of all
 *    three lines (either all left or all right).
 *    This corresponds to the minterm 000 and 111.
 *    Additionally, if backface culling is performed,
 *    then only keep the case of all right.
 *
 *  Edge Equation:
 *    For an edge defined as travelling from the
 *    vertice (x_1,y_1) to (x_2,y_2), the sample
 *    (x_s,y_s) lies to the right of the line
 *    if the following expression is true:
 *
 *    0 >  ( x_2 - x_1 ) * ( y_s - y_1 ) - ( x_s - x_1 ) * ( y_2 - y_1 )
 *
 *    otherwise it lies on the line (exactly 0) or
 *    to the left of the line.
 *
 *    This block evaluates the six edges described by the
 *    triangles vertices,  to determine which
 *    side of the lines the sample point lies.  Then it
 *    determines if the sample point lies in the triangle
 *    by or'ing the appropriate minterms.  In the case of
 *    the triangle only three edges are relevant.  In the
 *    case of the quadrilateral five edges are relevant.
 *
 *
 *   Author: John Brunhaver
 *   Created:      Thu 07/23/09
 *   Last Updated: Tue 10/06/10
 *
 *   Copyright 2009 <jbrunhaver@gmail.com>
 *
 *
 */

/* A Note on Signal Names:
 *
 * Most signals have a suffix of the form _RxxxxN
 * where R indicates that it is a Raster Block signal
 * xxxx indicates the clock slice that it belongs to
 * and N indicates the type of signal that it is.
 * H indicates logic high, L indicates logic low,
 * U indicates unsigned fixed point, and S indicates
 * signed fixed point.
 *
 */

module sampletest
#(
    parameter SIGFIG        = 24, // Bits in color and position.
    parameter RADIX         = 10, // Fraction bits in color and position
    parameter VERTS         = 3, // Maximum Vertices in triangle
    parameter AXIS          = 3, // Number of axis foreach vertex 3 is (x,y,z).
    parameter COLORS        = 3, // Number of color channels
    parameter PIPE_DEPTH    = 2 // How many pipe stages are in this block
)
(
    input logic signed [SIGFIG-1:0]     tri_R16S[VERTS-1:0][AXIS-1:0], // triangle to Iterate Over
    input logic unsigned [SIGFIG-1:0]   color_R16U[COLORS-1:0] , // Color of triangle
    input logic signed [SIGFIG-1:0]     sample_R16S[1:0], // Sample Location
    input logic                         validSamp_R16H, // A valid sample location

    input logic clk, // Clock
    input logic rst, // Reset

    output logic signed [SIGFIG-1:0]    hit_R18S[AXIS-1:0], // Hit Location
    output logic unsigned [SIGFIG-1:0]  color_R18U[COLORS-1:0] , // Color of triangle
    output logic                        hit_valid_R18H                   // Is hit good
);

    localparam EDGES = (VERTS == 3) ? 3 : 5;
    localparam SHORTSF = SIGFIG;
    localparam MROUND = (2 * SHORTSF) - RADIX;

    // output for retiming registers
    logic signed [SIGFIG-1:0]       hit_R18S_retime[AXIS-1:0];   // Hit Location
    logic unsigned [SIGFIG-1:0]     color_R18U_retime[COLORS-1:0];   // Color of triangle
    logic                           hit_valid_R18H_retime;   // Is hit good
    // output for retiming registers

    // Signals in Access Order
    logic signed [SIGFIG-1:0]       tri_shift_R16S[VERTS-1:0][1:0]; // triangle after coordinate shift
    // logic signed [SIGFIG-1:0]       edge_R16S[EDGES-1:0][1:0][1:0]; // Edges
    logic signed [(2*SHORTSF)-1:0]  dist_lg_R16S[EDGES-1:0]; // Result of x_1 * y_2 - x_2 * y_1
    logic                           hit_valid_R16H ; // Output (YOUR JOB!)
    logic signed [SIGFIG-1:0]       hit_R16S[AXIS-1:0]; // Sample position
    // Signals in Access Order

    // Your job is to produce the value for hit_valid_R16H signal, which indicates whether a sample lies inside the triangle.
    // hit_valid_R16H is high if validSamp_R16H && sample inside triangle (with back face culling)
    // Consider the following steps:

    // START CODE HERE
    // (1) Shift X, Y coordinates such that the fragment resides on the (0,0) position.


    logic                           tri_shift_signs [VERTS-1:0][1:0];
    logic                           dist_sign[EDGES-1:0];
    logic                           sign_prod_a;
    logic                           sign_prod_b;
    logic                           sign_prod_c;
    logic                           sign_prod_d;
    logic                           sign_prod_e;
    logic                           sign_prod_f;                   

    logic unsigned [16:0]     abs_tri_shift_R16S[VERTS-1:0][1:0];
    logic signed [16:0]       temp_tri_shift_R16S[VERTS-1:0][1:0];
    logic signed [25:0]       log2_abs_tri_shift_R16S[VERTS-1:0][1:0];
    logic signed [26:0]       log2_sums[VERTS-1:0][1:0];
    logic                     is_zero[VERTS-1:0];

    // Log 2 LUT to avoid multiplication
    logic [25:0] log2rom [131071:0];
    initial begin
        $readmemb("rtl/log2_rom2.mem", log2rom);
    end

    always_comb begin

        // Shift vertices
        for(int i= 0; i< VERTS; i++) begin

            // Get shifted values

            // We only actually need 17 bits of precision to pass all vectors.
            temp_tri_shift_R16S[i][0]= (tri_R16S[i][0] - sample_R16S[0])& 17'h1FFFF;
            temp_tri_shift_R16S[i][1]= (tri_R16S[i][1] - sample_R16S[1])& 17'h1FFFF;

            // Get signs
            tri_shift_signs[i][0] = temp_tri_shift_R16S[i][0][17 - 1];
            tri_shift_signs[i][1] = temp_tri_shift_R16S[i][1][17 - 1];

            // Get absolutes
            abs_tri_shift_R16S[i][0] = tri_shift_signs[i][0]? ~temp_tri_shift_R16S[i][0]+1: temp_tri_shift_R16S[i][0];
            abs_tri_shift_R16S[i][1] = tri_shift_signs[i][1]? ~temp_tri_shift_R16S[i][1]+1: temp_tri_shift_R16S[i][1];
        end	

        // Get zeros:
        is_zero[0] = ((temp_tri_shift_R16S[0][0] == 0) || (temp_tri_shift_R16S[1][1] == 0)) &&
                            ((temp_tri_shift_R16S[1][0] == 0) || (temp_tri_shift_R16S[0][1] == 0));
        is_zero[1] = ((temp_tri_shift_R16S[1][0] == 0) || (temp_tri_shift_R16S[2][1] == 0)) &&
                        ((temp_tri_shift_R16S[2][0] == 0) || (temp_tri_shift_R16S[1][1] == 0));
        is_zero[2] = ((temp_tri_shift_R16S[2][0] == 0) || (temp_tri_shift_R16S[0][1] == 0)) &&
                            ((temp_tri_shift_R16S[0][0] == 0) || (temp_tri_shift_R16S[2][1] == 0));

        // Because we only actually need 17 bits to pass the vectors, implement multiplication as a
        // lookup table.
        sign_prod_a = tri_shift_signs[0][0] ^ tri_shift_signs[1][1];
        sign_prod_b = tri_shift_signs[1][0] ^ tri_shift_signs[0][1];
        sign_prod_c = tri_shift_signs[1][0] ^ tri_shift_signs[2][1];
        sign_prod_d = tri_shift_signs[2][0] ^ tri_shift_signs[1][1];
        sign_prod_e = tri_shift_signs[2][0] ^ tri_shift_signs[0][1];
        sign_prod_f = tri_shift_signs[0][0] ^ tri_shift_signs[2][1];

        // Calculate distances on vertices, don't bother with edges
        // dist_lg_R16S[0] = ((temp_tri_shift_R16S[0][0]*temp_tri_shift_R16S[1][1]))- ((temp_tri_shift_R16S[1][0] * temp_tri_shift_R16S[0][1]));
        // dist_lg_R16S[1] = ((temp_tri_shift_R16S[1][0]*temp_tri_shift_R16S[2][1]))- ((temp_tri_shift_R16S[2][0] * temp_tri_shift_R16S[1][1]));
        // dist_lg_R16S[2] = ((temp_tri_shift_R16S[2][0]*temp_tri_shift_R16S[0][1]))- ((temp_tri_shift_R16S[0][0] * temp_tri_shift_R16S[2][1]));

        // If signs are inequal we know flag sign immediately.
        if ((sign_prod_a^sign_prod_b) & (!is_zero[0]))
            dist_sign[0] = sign_prod_a;
        else begin
            // Fetch from ROM
            log2_abs_tri_shift_R16S[0][0] = log2rom[abs_tri_shift_R16S[0][0]];
            log2_abs_tri_shift_R16S[1][1] = log2rom[abs_tri_shift_R16S[1][1]];
            log2_abs_tri_shift_R16S[1][0] = log2rom[abs_tri_shift_R16S[1][0]];
            log2_abs_tri_shift_R16S[0][1] = log2rom[abs_tri_shift_R16S[0][1]];

            // Lookup binds zeros to -2^24. Detect this and hardcode equality
            
            // Perform log addition
            log2_sums[0][0] = (log2_abs_tri_shift_R16S[0][0] + log2_abs_tri_shift_R16S[1][1])>>>3;
            log2_sums[0][1] = (log2_abs_tri_shift_R16S[1][0] + log2_abs_tri_shift_R16S[0][1])>>>3;
            
            // Set flag by performing comparison in log domain.
            if (log2_sums[0][0] != log2_sums[0][1])
                dist_sign[0] =  is_zero[0]?1:(log2_sums[0][0]<=log2_sums[0][1])?!sign_prod_a:sign_prod_a;
            else
                dist_sign[0] = 1;
        end 

        // If signs are inequal we know flag sign immediately.
        if ((sign_prod_c^sign_prod_d) & (!is_zero[1]))
            dist_sign[1] = sign_prod_c;
        else begin
            // Fetch from ROM
            log2_abs_tri_shift_R16S[1][0] = log2rom[abs_tri_shift_R16S[1][0]];
            log2_abs_tri_shift_R16S[2][1] = log2rom[abs_tri_shift_R16S[2][1]];
            log2_abs_tri_shift_R16S[2][0] = log2rom[abs_tri_shift_R16S[2][0]];
            log2_abs_tri_shift_R16S[1][1] = log2rom[abs_tri_shift_R16S[1][1]];

            // Lookup binds zeros to -2^24. Detect this and hardcode equality


            // Log addition again
            log2_sums[1][0] = (log2_abs_tri_shift_R16S[1][0] + log2_abs_tri_shift_R16S[2][1])>>>3;
            log2_sums[1][1] = (log2_abs_tri_shift_R16S[2][0] + log2_abs_tri_shift_R16S[1][1])>>>3;

            // Set flag by performing comparison in log domain.
            if (log2_sums[1][0] != log2_sums[1][1])
                dist_sign[1] = is_zero[1]?0:(log2_sums[1][0]<log2_sums[1][1])?!sign_prod_c:sign_prod_c;
            else
                dist_sign[0] = 0;
        end

        // If signs are inequal we know flag sign immediately.
        if ((sign_prod_e ^ sign_prod_f) & (!is_zero[2]))
            dist_sign[2] = sign_prod_e; 
        else begin
            // Fetch from ROM
            log2_abs_tri_shift_R16S[2][0] = log2rom[abs_tri_shift_R16S[2][0]];
            log2_abs_tri_shift_R16S[0][1] = log2rom[abs_tri_shift_R16S[0][1]];
            log2_abs_tri_shift_R16S[0][0] = log2rom[abs_tri_shift_R16S[0][0]];
            log2_abs_tri_shift_R16S[2][1] = log2rom[abs_tri_shift_R16S[2][1]];

            // If both sides aren't 0, perform comp in log domain
            log2_sums[2][0] = (log2_abs_tri_shift_R16S[2][0] + log2_abs_tri_shift_R16S[0][1])>>>3;
            log2_sums[2][1] = (log2_abs_tri_shift_R16S[0][0] + log2_abs_tri_shift_R16S[2][1])>>>3;

            // // Lookup binds zeros to -2^24. Detect this and hardcode equality

            // $display("2 is zero: %b", is_zero[2]);

            // Calculate Distance sign in log domain
            if (log2_sums[2][0] != log2_sums[2][1])
                dist_sign[2] = is_zero[2]?1:(log2_sums[2][0]<=log2_sums[2][1])?!sign_prod_e:sign_prod_e;
            else
                dist_sign[2] = 1;
        end

//         if ((!(dist_lg_R16S[0] > 0) && (dist_lg_R16S[1] < 0) && !(dist_lg_R16S[2] > 0) && validSamp_R16H) != (dist_sign[0] & dist_sign[1] & dist_sign[2] & validSamp_R16H)) begin
//             $display("=========================================================");
//             $display("0: sign_prod_a = %b, sign_prod_b = %b", sign_prod_a, sign_prod_b);
//             $display("0: RTL = %b, gold = %b, %f + %f <= %f + %f, sign = %b, %f * %f <= %f * %f -> b  = %b", dist_sign[0], dist_lg_R16S[0]<=0, $itor(log2_abs_tri_shift_R16S[0][0])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[1][1])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[1][0])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[0][1])*(2**-21.0), dist_sign[0], $itor(temp_tri_shift_R16S[0][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[1][1])*(2**(-10.0)), $itor(temp_tri_shift_R16S[1][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[0][1])*(2**(-10.0)), temp_tri_shift_R16S[0][1]);
//             $display("0: abs(%f) = %f, abs(%f) = %f, abs(%f) = %f, abs(%f) = %f", $itor(temp_tri_shift_R16S[0][0])*(2**(-10.0)), $itor(abs_tri_shift_R16S[0][0])*(2**(-10.0)),$itor(temp_tri_shift_R16S[1][1])*(2**(-10.0)),$itor(abs_tri_shift_R16S[1][1])*(2**(-10.0)), $itor(temp_tri_shift_R16S[1][0])*(2**(-10.0)), $itor(abs_tri_shift_R16S[1][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[0][1])*(2**(-10.0)), $itor(abs_tri_shift_R16S[0][1])*(2**(-10.0)));
//             $display("0: log2(%f) = %f, log2(%f) = %f, log2(%f) = %f, log2(%f) = %f",  $itor(temp_tri_shift_R16S[0][0])*(2**(-10.0)),$itor(log2_abs_tri_shift_R16S[0][0])*(2**-21.0), $itor(temp_tri_shift_R16S[1][1])*(2**(-10.0)), $itor(log2_abs_tri_shift_R16S[1][1])*(2**-21.0), $itor(temp_tri_shift_R16S[1][0])*(2**(-10.0)),$itor(log2_abs_tri_shift_R16S[1][0])*(2**-21.0), $itor(temp_tri_shift_R16S[0][1])*(2**(-10.0)), $itor(log2_abs_tri_shift_R16S[0][1])*(2**-21.0));
//             $display("valid  = %b, should %b", dist_sign[0] & dist_sign[1] & dist_sign[2] & validSamp_R16H, !(dist_lg_R16S[0] > 0) && (dist_lg_R16S[1] < 0) && !(dist_lg_R16S[2] > 0) && validSamp_R16H);
//             //Check distance and assign hit_valid_R16H.
// // 
//             $display("1: RTL = %b, gold = %b, %f + %f <= %f + %f, sign = %b, %f * %f <= %f * %f -> b  = %b", dist_sign[1], dist_lg_R16S[1]<0, $itor(log2_abs_tri_shift_R16S[1][0])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[2][1])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[2][0])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[1][1])*(2**-21.0), dist_sign[0], $itor(temp_tri_shift_R16S[1][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[2][1])*(2**(-10.0)), $itor(temp_tri_shift_R16S[2][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[1][1])*(2**(-10.0)), temp_tri_shift_R16S[1][1]);
//             $display("2: RTL = %b, gold = %b, %f + %f <= %f + %f, sign = %b, %f * %f <= %f * %f -> b  = %b", dist_sign[2], dist_lg_R16S[2]<=0, $itor(log2_abs_tri_shift_R16S[2][0])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[0][1])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[0][0])*(2**-21.0), $itor(log2_abs_tri_shift_R16S[2][1])*(2**-21.0), dist_sign[0], $itor(temp_tri_shift_R16S[2][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[0][1])*(2**(-10.0)), $itor(temp_tri_shift_R16S[0][0])*(2**(-10.0)), $itor(temp_tri_shift_R16S[2][1])*(2**(-10.0)), temp_tri_shift_R16S[2][1]);
        
//             $display("2: SHIFTED = sum left = %b, sum right = %b",log2_sums[2][0],log2_sums[2][1]);
//         end
        // $display("Scale test: 2^-23 = %f, 2^-10 = %f", 2.0 ** -21.0, 2.0 ** -10.0);

        // hit_valid_R16H= !(dist_lg_R16S[0] > 0) && (dist_lg_R16S[1] < 0) && !(dist_lg_R16S[2] > 0) && validSamp_R16H;

        hit_valid_R16H= dist_sign[0] & dist_sign[1] & dist_sign[2] & validSamp_R16H;

        // $display("gold = %b, maybe = %b", hit_valid_R16H, dist_sign[0] & dist_sign[1] & dist_sign[2] & validSamp_R16H);
        
        // hit_valid_R16H= (dist_lg_R16S[0] <= 0) && (dist_lg_R16S[1] < 0) && (dist_lg_R16S[2] <= 0) && validSamp_R16H;
    end
    // END CODE HERE

    //Assertions to help debug
    //Check if correct inequalities have been used
    assert property( @(posedge clk) (dist_lg_R16S[1] == 0) |-> !hit_valid_R16H);
    assert property( @(posedge clk) (is_zero[2] == 1) |-> dist_sign[2] == 1);

    //Calculate Depth as depth of first vertex
    // Note that a barrycentric interpolation would
    // be more accurate
    always_comb begin
        hit_R16S[1:0] = sample_R16S[1:0]; //Make sure you use unjittered sample
        hit_R16S[2] = tri_R16S[0][2]; // z value equals the z value of the first vertex
    end

    /* Flop R16 to R18_retime with retiming registers*/
    dff2 #(
        .WIDTH          (SIGFIG         ),
        .ARRAY_SIZE     (AXIS           ),
        .PIPE_DEPTH     (PIPE_DEPTH - 1 ),
        .RETIME_STATUS  (1              )
    )
    d_samp_r1
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (1'b1           ),
        .in     (hit_R16S       ),
        .out    (hit_R18S_retime)
    );

    dff2 #(
        .WIDTH          (SIGFIG         ),
        .ARRAY_SIZE     (COLORS         ),
        .PIPE_DEPTH     (PIPE_DEPTH - 1 ),
        .RETIME_STATUS  (1              )
    )
    d_samp_r2
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (1'b1               ),
        .in     (color_R16U         ),
        .out    (color_R18U_retime  )
    );

    dff_retime #(
        .WIDTH          (1              ),
        .PIPE_DEPTH     (PIPE_DEPTH - 1 ),
        .RETIME_STATUS  (1              ) // RETIME
    )
    d_samp_r3
    (
        .clk    (clk                    ),
        .reset  (rst                    ),
        .en     (1'b1                   ),
        .in     (hit_valid_R16H         ),
        .out    (hit_valid_R18H_retime  )
    );
    /* Flop R16 to R18_retime with retiming registers*/

    /* Flop R18_retime to R18 with fixed registers */
    dff2 #(
        .WIDTH          (SIGFIG ),
        .ARRAY_SIZE     (AXIS   ),
        .PIPE_DEPTH     (1      ),
        .RETIME_STATUS  (0      )
    )
    d_samp_f1
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (1'b1           ),
        .in     (hit_R18S_retime),
        .out    (hit_R18S       )
    );

    dff2 #(
        .WIDTH          (SIGFIG ),
        .ARRAY_SIZE     (COLORS ),
        .PIPE_DEPTH     (1      ),
        .RETIME_STATUS  (0      )
    )
    d_samp_f2
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (1'b1               ),
        .in     (color_R18U_retime  ),
        .out    (color_R18U         )
    );

    dff #(
        .WIDTH          (1  ),
        .PIPE_DEPTH     (1  ),
        .RETIME_STATUS  (0  ) // No retime
    )
    d_samp_f3
    (
        .clk    (clk                    ),
        .reset  (rst                    ),
        .en     (1'b1                   ),
        .in     (hit_valid_R18H_retime  ),
        .out    (hit_valid_R18H         )
    );

    /* Flop R18_retime to R18 with fixed registers */

endmodule



