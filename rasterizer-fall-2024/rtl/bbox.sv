/*
 * Bounding Box Module
 *
 * Inputs:
 *   3 x,y,z vertices corresponding to tri
 *   1 valid bit, indicating triangle is valid data
 *
 *  Config Inputs:
 *   2 x,y vertices indicating screen dimensions
 *   1 integer representing square root of SS (16MSAA->4)
 *      we will assume config values are held in some
 *      register and are valid given a valid triangle
 *
 *  Control Input:
 *   1 halt signal indicating that no work should be done
 *
 * Outputs:
 *   2 vertices describing a clamped bounding box
 *   1 Valid signal indicating that bounding
 *           box and triangle value is valid
 *   3 x,y vertices corresponding to tri
 *
 * Global Signals:
 *   clk, rst
 *
 * Function:
 *   Determine a bounding box for the triangle
 *   represented by the vertices.
 *
 *   Clamp the Bounding Box to the subsample pixel
 *   space
 *
 *   Clip the Bounding Box to Screen Space
 *
 *   Halt operating but retain values if next stage is busy
 *
 *
 * Long Description:
 *   This bounding box block accepts a triangle described with three
 *   vertices and determines a set of sample points to test against
 *   the triangle.  These sample points correspond to the
 *   either the pixels in the final image or the pixel fragments
 *   that compose the pixel if multisample anti-aliasing (MSAA)
 *   is enabled.
 *
 *   The inputs to the box are clocked with a bank of dflops.
 *
 *   After the data is clocked, a bounding box is determined
 *   for the triangle. A bounding box can be determined
 *   through calculating the maxima and minima for x and y to
 *   generate a lower left vertice and upper right
 *   vertice.  This data is then clocked.
 *
 *   The bounding box next needs to be clamped to the fragment grid.
 *   This can be accomplished through rounding the bounding box values
 *   to the fragment grid.  Additionally, any sample points that exist
 *   outside of screen space should be rejected.  So the bounding box
 *   can be clipped to the visible screen space.  This clipping is done
 *   using the screen signal.
 *
 *   The Halt signal is utilized to hold the current triangle bounding box.
 *   This is because one bounding box operation could correspond to
 *   multiple sample test operations later in the pipe.  As these samples
 *   can take a number of cycles to complete, the data held in the bounding
 *   box stage needs to be preserved.  The halt signal is also required for
 *   when the write device is full/busy.
 *
 *   The valid signal is utilized to indicate whether or not a triangle
 *   is actual data.  This can be useful if the device being read from,
 *   has no more triangles.
 *
 *
 *
 *   Author: John Brunhaver
 *   Created:      Thu 07/23/09
 *   Last Updated: Fri 09/30/10
 *
 *   Copyright 2009 <jbrunhaver@gmail.com>
 */


/* A Note on Signal Names:
 *
 * Most signals have a suffix of the form _RxxxxN
 * where R indicates that it is a Raster Block signal
 * xxxx indicates the clock slice that it belongs to
 * N indicates the type of signal that it is.
 *    H indicates logic high,
 *    L indicates logic low,
 *    U indicates unsigned fixed point,
 *    S indicates signed fixed point.
 *
 * For all the signed fixed point signals (logic signed [SIGFIG-1:0]),
 * their highest `$sig_fig-$radix` bits, namely [`$sig_fig-1`:RADIX]
 * represent the integer part of the fixed point number,
 * while the lowest RADIX bits, namely [`$radix-1`:0]
 * represent the fractional part of the fixed point number.
 *
 *
 *
 * For signal subSample_RnnnnU (logic [3:0])
 * 1000 for  1x MSAA eq to 1 sample per pixel
 * 0100 for  4x MSAA eq to 4 samples per pixel,
 *              a sample is half a pixel on a side
 * 0010 for 16x MSAA eq to 16 sample per pixel,
 *              a sample is a quarter pixel on a side.
 * 0001 for 64x MSAA eq to 64 samples per pixel,
 *              a sample is an eighth of a pixel on a side.
 *
 */

module bbox
#(
    parameter SIGFIG        = 24, // Bits in color and position.
    parameter RADIX         = 10, // Fraction bits in color and position
    parameter VERTS         = 3, // Maximum Vertices in triangle
    parameter AXIS          = 3, // Number of axis foreach vertex 3 is (x,y,z).
    parameter COLORS        = 3, // Number of color channels
    parameter PIPE_DEPTH    = 3 // How many pipe stages are in this block
)
(
    //Input Signals
    input logic signed [SIGFIG-1:0]     tri_R10S[VERTS-1:0][AXIS-1:0] , // Sets X,Y Fixed Point Values
    input logic unsigned [SIGFIG-1:0]   color_R10U[COLORS-1:0] , // Color of Tri
    input logic                         validTri_R10H , // Valid Data for Operation

    //Control Signals
    input logic                         halt_RnnnnL , // Indicates No Work Should Be Done
    input logic signed [SIGFIG-1:0]     screen_RnnnnS[1:0] , // Screen Dimensions
    input logic [3:0]                   subSample_RnnnnU , // SubSample_Interval

    //Global Signals
    input logic clk, // Clock
    input logic rst, // Reset

    //Outout Signals
    output logic signed [SIGFIG-1:0]    tri_R13S[VERTS-1:0][AXIS-1:0],  // 4 Sets X,Y Fixed Point Values
    output logic unsigned [SIGFIG-1:0]  color_R13U[COLORS-1:0] ,        // Color of Tri
    output logic signed [SIGFIG-1:0]    box_R13S[1:0][1:0],             // 2 Sets X,Y Fixed Point Values
    output logic                        validTri_R13H                   // Valid Data for Operation
);

    //Signals In Clocking Order

    //Begin R10 Signals

    // Step 1 Result: LL and UR X, Y Fixed Point Values determined by calculating min/max vertices
    // box_R10S[0][0]: LL X
    // box_R10S[0][1]: LL Y
    // box_R10S[1][0]: UR X
    // box_R10S[1][1]: UR Y
    logic signed [SIGFIG-1:0]   box_R10S[1:0][1:0];
    // Step 2 Result: LL and UR Rounded Down to SubSample Interval
    logic signed [SIGFIG-1:0]   rounded_box_R10S[1:0][1:0];
    // Step 3 Result: LL and UR X, Y Fixed Point Values after Clipping
    logic signed [SIGFIG-1:0]   out_box_R10S[1:0][1:0];      // bounds for output
    // Step 3 Result: valid if validTri_R10H && BBox within screen
    logic                       outvalid_R10H;               // output is valid

    //End R10 Signals

    // Begin output for retiming registers
    logic signed [SIGFIG-1:0]   tri_R13S_retime[VERTS-1:0][AXIS-1:0];   // 4 Sets X,Y Fixed Point Values
    logic unsigned [SIGFIG-1:0] color_R13U_retime[COLORS-1:0];          // Color of Tri
    logic signed [SIGFIG-1:0]   box_R13S_retime[1:0][1:0];              // 2 Sets X,Y Fixed Point Values
    logic                       validTri_R13H_retime ;                  // Valid Data for Operation
    // End output for retiming registers

    // Check if backfacing
    logic signed [(2*SIGFIG)-1:0]     tri_check;
    logic                       valid_triangle;
    
    // Log 2 LUT to avoid multiplication
    logic [25:0] log2rom [131071:0];
    initial begin
        $readmemb("rtl/log2_rom2.mem", log2rom);
    end

    logic signed [16:0] sub1;
    logic signed [16:0] sub2;
    logic signed [16:0] sub3;
    logic signed [16:0] sub4;
    logic unsigned [17:0] abs1;
    logic unsigned [17:0] abs2;
    logic unsigned [17:0] abs3;
    logic unsigned [17:0] abs4;   
    logic signed [25:0] log1;
    logic signed [25:0] log2;
    logic signed [25:0] log3;
    logic signed [25:0] log4;
    logic signed [26:0] logsum1;
    logic signed [26:0] logsum2;   
    logic sign1;
    logic sign2;
    logic sign3;
    logic sign4;
    logic sign_prod_a;
    logic sign_prod_b;
    logic is_zero;
    always_comb begin

        // Do subs
        sub1 = (tri_R10S[1][0] - tri_R10S[0][0])&17'h1FFFF;
        sub2 = (tri_R10S[2][1] - tri_R10S[0][1])&17'h1FFFF;
        sub3 = (tri_R10S[1][1] - tri_R10S[0][1])&17'h1FFFF;
        sub4 = (tri_R10S[2][0] - tri_R10S[0][0])&17'h1FFFF;

        // Get signs
        sign1 = sub1[17-1];
        sign2 = sub2[17-1];
        sign3 = sub3[17-1];
        sign4 = sub4[17-1];

        // Get signs of products
        sign_prod_a = sign1^sign2;
        sign_prod_b = sign3^sign4;

        // Check if 0
        is_zero = (sub1 == 0 || sub2 == 0) && (sub3 == 0 || sub4 == 0);

        // We don't need to compute if we already know the sign
        if ((sign_prod_a^sign_prod_b) & (!is_zero))
            valid_triangle = sign_prod_a;
        else begin
            // Get absolutes
            abs1 = sign1? ~sub1 + 1 : sub1;
            abs2 = sign2? ~sub2 + 1 : sub2;
            abs3 = sign3? ~sub3 + 1 : sub3;
            abs4 = sign4? ~sub4 + 1 : sub4;

            // Get logs
            log1 = log2rom[abs1];
            log2 = log2rom[abs2];
            log3 = log2rom[abs3];
            log4 = log2rom[abs4];

            // Sum in log domain  = mult
            // The shift is absolutely necessary do not
            // question it.
            logsum1 = (log1+log2)>>>3;
            logsum2 = (log3+log4)>>>3;

            // Set flag by performing comparison in log domain.
            if (logsum1 != logsum2)
                valid_triangle =  is_zero?1:(logsum1<=logsum2)?!sign_prod_a:sign_prod_a;
            else
                valid_triangle = 1;
        end
    end



    // ********** Step 1:  Determining a Bounding Box **********
    // Here you need to determine the bounding box by comparing the vertices
    // and assigning box_R10S to be the proper coordinates

    // START CODE HERE
    // This select signal structure may help you in selecting your bbox coordinates
    logic [2:0] bbox_sel_R10H [1:0][1:0];
    // The above structure consists of a 3-bit select signal for each coordinate of the 
    // bouding box. The leftmost [1:0] dimensions refer to LL/UR, while the rightmost 
    // [1:0] dimensions refer to X or Y coordinates. Each select signal should be a 3-bit 
    // one-hot signal, where the bit that is high represents which one of the 3 triangle vertices 
    // should be chosen for that bbox coordinate. As an example, if we have: bbox_sel_R10H[0][0] = 3'b001
    // then this indicates that the lower left x-coordinate of your bounding box should be assigned to the 
    // x-coordinate of triangle "vertex a". 
    
    //  DECLARE ANY OTHER SIGNALS YOU NEED

    // Try declaring an always_comb block to assign values to box_R10S
    // always_comb begin
    //     // Nested ternary to find 3 input minima
    //     bbox_sel_R10H[0][0] = (tri_R10S[0][0] < tri_R10S[1][0])? ((tri_R10S[0][0]<tri_R10S[2][0])?3'b001:3'b100):((tri_R10S[1][0]<tri_R10S[2][0])?3'b010:3'b100);
    //     bbox_sel_R10H[0][1] = (tri_R10S[0][1] < tri_R10S[1][1])? ((tri_R10S[0][1]<tri_R10S[2][1])?3'b001:3'b100):((tri_R10S[1][1]<tri_R10S[2][1])?3'b010:3'b100);
    //     bbox_sel_R10H[1][0] = (tri_R10S[0][0] > tri_R10S[1][0])? ((tri_R10S[0][0]>tri_R10S[2][0])?3'b001:3'b100):((tri_R10S[1][0]>tri_R10S[2][0])?3'b010:3'b100);
    //     bbox_sel_R10H[1][1] = (tri_R10S[0][1] > tri_R10S[1][1])? ((tri_R10S[0][1]>tri_R10S[2][1])?3'b001:3'b100):((tri_R10S[1][1]>tri_R10S[2][1])?3'b010:3'b100);
    
        // // Iterate over assigned vertices and get x/y
        // for (int i=0; i< VERTS; i++) begin
        //     for (int j=0; j<VERTS; j++) begin
        //         (* full_case, parallel_case *)
        //         case(bbox_sel_R10H[j][i])
        //             3'b001: box_R10S[j][i] = tri_R10S[0][i];
        //             3'b010: box_R10S[j][i] = tri_R10S[1][i];
        //             3'b100: box_R10S[j][i] = tri_R10S[2][i];
        //         endcase
        //     end
        // end
    // end

    logic comp  [4:0][3:0];
    logic signed [SIGFIG-1:0] intermediate_tri [4:0][1:0];
    always_comb begin
        comp[0][0] = (tri_R10S[0][0] < tri_R10S[1][0]);
        comp[0][1] = (tri_R10S[0][0] < tri_R10S[2][0]);
        comp[0][2] = (tri_R10S[1][0] < tri_R10S[2][0]);

        intermediate_tri[0][0] = comp[0][1]? tri_R10S[0][0]:tri_R10S[2][0];
        intermediate_tri[0][1] = comp[0][2]? tri_R10S[1][0]:tri_R10S[2][0];
        
        box_R10S[0][0] = comp[0][0]? intermediate_tri[0][0]:intermediate_tri[0][1];
    end

    always_comb begin
        comp[1][0] = (tri_R10S[0][1] < tri_R10S[1][1]);
        comp[1][1] = (tri_R10S[0][1] < tri_R10S[2][1]);
        comp[1][2] = (tri_R10S[1][1] < tri_R10S[2][1]);

        intermediate_tri[1][0] = comp[1][1]? tri_R10S[0][1]:tri_R10S[2][1];
        intermediate_tri[1][1] = comp[1][2]? tri_R10S[1][1]:tri_R10S[2][1];

        box_R10S[0][1] = comp[1][0]? intermediate_tri[1][0]:intermediate_tri[1][1];
    end

    always_comb begin
        comp[2][0] = (tri_R10S[0][0] > tri_R10S[1][0]);
        comp[2][1] = (tri_R10S[0][0] > tri_R10S[2][0]);
        comp[2][2] = (tri_R10S[1][0] > tri_R10S[2][0]);

        intermediate_tri[2][0] = comp[2][1]? tri_R10S[0][0]:tri_R10S[2][0];
        intermediate_tri[2][1] = comp[2][2]? tri_R10S[1][0]:tri_R10S[2][0];

        box_R10S[1][0] = comp[2][0]? intermediate_tri[2][0]:intermediate_tri[2][1];
    end

    always_comb begin
        comp[3][0] = (tri_R10S[0][1] > tri_R10S[1][1]);
        comp[3][1] = (tri_R10S[0][1] > tri_R10S[2][1]);
        comp[3][2] = (tri_R10S[1][1] > tri_R10S[2][1]);

        intermediate_tri[3][0] = comp[3][1]? tri_R10S[0][1]:tri_R10S[2][1];
        intermediate_tri[3][1] = comp[3][2]? tri_R10S[1][1]:tri_R10S[2][1];

        box_R10S[1][1] = comp[3][0]? intermediate_tri[3][0]:intermediate_tri[3][1];
    end

    // Assertions to check if box_R10S is assigned properly
    // We want to check the following properties:
    // 1) Each of the coordinates box_R10S are always and uniquely assigned
    // 2) Upper right coordinate is never less than lower left

    // START CODE HERE
    
    //Assertions to check if all cases are covered and assignments are unique 
    // (already done for you if you use the bbox_sel_R10H select signal as declared)
    // assert property(@(posedge clk) $onehot(bbox_sel_R10H[0][0]));
    // assert property(@(posedge clk) $onehot(bbox_sel_R10H[0][1]));
    // assert property(@(posedge clk) $onehot(bbox_sel_R10H[1][0]));
    // assert property(@(posedge clk) $onehot(bbox_sel_R10H[1][1]));

    //Assertions to check UR is never less than LL
    assert property(@(posedge clk) !(box_R10S[1][1]<box_R10S[0][1]));
    assert property(@(posedge clk) !(box_R10S[1][0]<box_R10S[0][0]));
    // END CODE HERE


    // ***************** End of Step 1 *********************


    // ********** Step 2:  Round Values to Subsample Interval **********

    // We will use the floor operation for rounding.
    // To floor a signal, we simply turn all of the bits
    // below a specific RADIX to 0.
    // The complication here is that there are 4 setting.
    // 1x MSAA eq. to 1 sample per pixel
    // 4x MSAA eq to 4 samples per pixel, a sample is
    // half a pixel on a side
    // 16x MSAA eq to 16 sample per pixel, a sample is
    // a quarter pixel on a side.
    // 64x MSAA eq to 64 samples per pixel, a sample is
    // an eighth of a pixel on a side.

    // Note: Cleverly converting the MSAA signal
    //       to a mask would allow you to do this operation
    //       as a bitwise and operation.

    //Round LowerLeft and UpperRight for X and Y
    generate
    for(genvar i = 0; i < 2; i = i + 1) begin
        for(genvar j = 0; j < 2; j = j + 1) begin

            logic [SIGFIG:0] A  = 'b0;

            always_comb begin

                //Integer Portion of LL and UR Remains the same
                rounded_box_R10S[i][j][SIGFIG-1:RADIX] = box_R10S[i][j][SIGFIG-1:RADIX];

                // Fraction is rounded
                rounded_box_R10S[i][j][RADIX-1:0] = box_R10S[i][j][RADIX-1:0] & ~({subSample_RnnnnU, A[(RADIX - 4):0]} - 1);
            end
        end
    end
    endgenerate

    //Assertion to help you debug errors in rounding
    assert property( @(posedge clk) (box_R10S[0][0] - rounded_box_R10S[0][0]) <= {subSample_RnnnnU,8'b0});
    assert property( @(posedge clk) (box_R10S[0][1] - rounded_box_R10S[0][1]) <= {subSample_RnnnnU,8'b0});
    assert property( @(posedge clk) (box_R10S[1][0] - rounded_box_R10S[1][0]) <= {subSample_RnnnnU,8'b0});
    assert property( @(posedge clk) (box_R10S[1][1] - rounded_box_R10S[1][1]) <= {subSample_RnnnnU,8'b0});

    // ***************** End of Step 2 *********************


    // ********** Step 3:  Clipping or Rejection **********

    // Clamp if LL is down/left of screen origin
    // Clamp if UR is up/right of Screen
    // Invalid if BBox is up/right of Screen
    // Invalid if BBox is down/left of Screen
    // outvalid_R10H high if validTri_R10H && BBox is valid
    logic bbox_valid[1:0]; 
    always_comb begin

        out_box_R10S= box_R10S;
        outvalid_R10H= 1'b0; // Initialized as invalid

        out_box_R10S[0][0] = (rounded_box_R10S[0][0]<0)?0:rounded_box_R10S[0][0];
        out_box_R10S[0][1] = (rounded_box_R10S[0][1]<0)?0:rounded_box_R10S[0][1];
        out_box_R10S[1][0] = (rounded_box_R10S[1][0]>screen_RnnnnS[0])?screen_RnnnnS[0]:rounded_box_R10S[1][0];
        out_box_R10S[1][1] = (rounded_box_R10S[1][1]>screen_RnnnnS[1])?screen_RnnnnS[1]:rounded_box_R10S[1][1];
        
        outvalid_R10H = (out_box_R10S[0][0]<= screen_RnnnnS[0]) && 
                        (out_box_R10S[1][0]>= 0) && (out_box_R10S[0][1]<= screen_RnnnnS[1]) && 
                        (out_box_R10S[1][1]>=0) && validTri_R10H && valid_triangle;

        // $display("LL X = %d, LL Y = %d, UR X = %d, UR Y = %d",out_box_R10S[0][0],out_box_R10S[0][1],out_box_R10S[1][0],out_box_R10S[1][1]);
    end

    //Assertion for checking if outvalid_R10H has been assigned properly
    assert property( @(posedge clk) (outvalid_R10H |-> out_box_R10S[1][0] <= screen_RnnnnS[0] ));
    assert property( @(posedge clk) (outvalid_R10H |-> out_box_R10S[1][1] <= screen_RnnnnS[1] ));

    // ***************** End of Step 3 *********************

    logic bubble_burst_en;
    assign bubble_burst_en = !(halt_RnnnnL||validTri_R13H);
    dff3 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE1(VERTS),
        .ARRAY_SIZE2(AXIS),
        .PIPE_DEPTH(PIPE_DEPTH - 1),
        .RETIME_STATUS(1)
    )
    d_bbx_r1
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (halt_RnnnnL  || bubble_burst_en),
        .in     (tri_R10S          ),
        .out    (tri_R13S_retime   )
    );

    dff2 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE(COLORS),
        .PIPE_DEPTH(PIPE_DEPTH - 1),
        .RETIME_STATUS(1)
    )
    d_bbx_r2
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (halt_RnnnnL  || bubble_burst_en      ),
        .in     (color_R10U         ),
        .out    (color_R13U_retime  )
    );

    dff3 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE1(2),
        .ARRAY_SIZE2(2),
        .PIPE_DEPTH(PIPE_DEPTH - 1),
        .RETIME_STATUS(1)
    )
    d_bbx_r3
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (halt_RnnnnL || bubble_burst_en),
        .in     (out_box_R10S   ),
        .out    (box_R13S_retime)
    );

    dff_retime #(
        .WIDTH(1),
        .PIPE_DEPTH(PIPE_DEPTH - 1),
        .RETIME_STATUS(1) // Retime
    )
    d_bbx_r4
    (
        .clk    (clk                    ),
        .reset  (rst                    ),
        .en     (halt_RnnnnL  || bubble_burst_en),
        .in     (outvalid_R10H          ),
        .out    (validTri_R13H_retime   )
    );
    //Flop Clamped Box to R13_retime with retiming registers

    //Flop the retimed to fixed registers
    dff3 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE1(VERTS),
        .ARRAY_SIZE2(AXIS),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d_bbx_f1
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (halt_RnnnnL || bubble_burst_en        ),
        .in     (tri_R13S_retime    ),
        .out    (tri_R13S           )
    );

    dff2 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE(COLORS),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d_bbx_f2
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (halt_RnnnnL || bubble_burst_en        ),
        .in     (color_R13U_retime  ),
        .out    (color_R13U         )
    );

    dff3 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE1(2),
        .ARRAY_SIZE2(2),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d_bbx_f3
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (halt_RnnnnL || bubble_burst_en    ),
        .in     (box_R13S_retime),
        .out    (box_R13S       )
    );

    dff #(
        .WIDTH(1),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0) // No retime
    )
    d_bbx_f4
    (
        .clk    (clk                    ),
        .reset  (rst                    ),
        .en     (halt_RnnnnL || bubble_burst_en            ),
        .in     (validTri_R13H_retime   ),
        .out    (validTri_R13H          )
    );
    //Flop R13_retime to R13 with fixed registers

    //Error Checking Assertions

    //Define a Less Than Property
    //
    //  a should be less than b
    property rb_lt( rst, a, b, c );
        @(posedge clk) rst | ((a<=b) | !c);
    endproperty

    //Check that Lower Left of Bounding Box is less than equal Upper Right
    assert property( rb_lt( rst, box_R13S[0][0], box_R13S[1][0], validTri_R13H ));
    assert property( rb_lt( rst, box_R13S[0][1], box_R13S[1][1], validTri_R13H ));

    // integer k = 0;
    // always_ff @(posedge clk) begin
    //     if (!rst&(bubble_burst_en)) begin
    //         $display("Shifted %d times",k);
    //         k = k + 1;
    //     end
    // end

endmodule












