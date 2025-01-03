/*
 * Module: rast_driver
 * =====================
 * This file contains the driver for the rasteriser.
 * In order for this driver to work properly, the testbench
 * must do follow the following operations:
 * 1. Call the InitLines() task during simulation initialization
 * 2. Set the name of the test vectors files. Example:
 *    driver.testname = "my_test.dat";
 * 3. Call the RunTest() task to start the driver
 * 4. Wait on the TestFinish signal
 *
 * Made by:
 * John Brunhaver  [jbrunhaver@gmail.com]
 * Ofer Shacham    [shacham@stanford.edu]
 *
 */

  /****************************************************************************
 * Change bar:
 * -----------
 * Date           Author    Description
 * Sep 22, 2012   jingpu    ported from John's original code to Genesis
 *
 * ***************************************************************************/

module rast_driver
#(
    parameter SIGFIG = 24, // Bits in color and position.
    parameter RADIX = 10, // Fraction bits in color and position
    parameter VERTS = 3, // Maximum Vertices in triangle
    parameter AXIS = 3, // Number of axis foreach vertex 3 is (x,y,z).
    parameter COLORS = 3 // Number of color channels
)
(
    input logic halt_RnnnnL,       // Input: Indicates No Work Should Be Done

    input logic rst,                // Input: Reset
    input logic clk,                // Input: Clock

    output logic signed [SIGFIG-1:0]    tri_R10S [VERTS-1:0][AXIS-1:0], // Output: 4 Sets X,Y Fixed Point Values
    output logic signed [SIGFIG-1:0]    color_R10U [COLORS-1:0],
    output logic                        validTri_R10H,                  // Output: Valid Data for Operation
    output logic signed [SIGFIG-1:0]    screen_RnnnnS[1:0],              // Output: Screen Dimensions
    output logic        [3:0]           subSample_RnnnnU,                // Output: SubSample_Interval
    output int                          ss_w_lg2_RnnnnS
);

    logic   signed   [24-1:0]  tmp_tri_R10S[VERTS-1:0][AXIS-1:0] ; // Output: 4 Sets X,Y Fixed Point Values
    logic   unsigned [24-1:0]  tmp_color_R10U[COLORS-1:0];


    int signed      mini = -1024;
    int signed      maxi =  1024;
    int             ss_w_lg2 ;
    int             i,j,k,l,m,n;
    int             eachAxis, eachVerts, eachColor;
    int             eachVertsA;

    // for controlling the input file
    string  testname;
    string  format_header;
    int     fh; //test file handle
    int     count;
    int     msaa;
    int     line_num;
    int     num_vertices;

    logic   TestFinish ;

    assign ss_w_lg2_RnnnnS = ss_w_lg2;

    // Initialization method
    task InitLines;
    begin
        $display("time=%10t ************** Driver Is Initializing Input Signals *****************", $time);

        // initialize the lines with random data (valid is off)

        for(eachAxis = 0; eachAxis < AXIS; eachAxis++) begin
            for(eachVerts = 0; eachVerts < VERTS; eachVerts++) begin
                tri_R10S[eachVerts][eachAxis] = $random();
            end
        end

        for(eachColor = 0; eachColor < COLORS; eachColor++) begin
            color_R10U[eachColor] = $random();
        end

        // Set the designs screen and MSAA
        // Should be Parameterized for Sig Fig and Radix -TODO John
        screen_RnnnnS[0] = {1'b1,19'd0} ;  //Set Screen to 512 Width
        screen_RnnnnS[1] = {1'b1,19'd0} ;  //Set Screen to 512 Height
        subSample_RnnnnU = 4'b0100 ;       //MSAA=x4
        ss_w_lg2         = 1 ;             //MSAA=x4 ss_w=2 ss_w_lg2=1

        validTri_R10H  = 1'b0;          // Not Valid
        TestFinish = 1'b0;		  // Simulation signal to tell bench when I'm done
    end
    endtask // InitLines


    task InitTest;
    begin
        $display("time=%10t ************** Driver Is Initializing Test from File *****************", $time);

        // open test file:
        fh = $fopen(testname,"r");
        line_num = 1;
        assert (fh) else $fatal(2, "ERROR: Cannot open file %s", testname);
        assert (!$feof(fh)) else $fatal(2, "ERROR: File -->%s<--is empty",testname);

        // read the screen parameters
        count = $fscanf(fh, "%s" , format_header );
        assert(format_header=="JB21") else $fatal(2, "Error: Incorrect File Type" );

        count = $fscanf(fh, "%6x %6x %d", screen_RnnnnS[0], screen_RnnnnS[1], msaa);
        line_num = line_num+1;
        assert (count==3) else $fatal(2, "ERROR: Cannot find screen params");
        $display ("Setting screen params: w=%0d h=%0d msaa=%0d RADIX = %0d", screen_RnnnnS[0]>>10, screen_RnnnnS[1]>>10, msaa, RADIX);
        case (msaa)
            1: begin
                subSample_RnnnnU = 4'b1000;
                ss_w_lg2 = 0;
            end
            4: begin
                subSample_RnnnnU = 4'b0100;
                ss_w_lg2 = 1;
            end
            16: begin
                subSample_RnnnnU = 4'b0010;
                ss_w_lg2 = 2;
            end
            64: begin
                subSample_RnnnnU = 4'b0001;
                ss_w_lg2 = 3;
            end
            default:
                assert (0) else $fatal(2, "ERROR: Illigal MSAA input %d", msaa);
        endcase // case(msaa)

    end
    endtask


    //START TEST
    //  This test sets up some initial values
    //   and then iterates over the entire
    //   screen and generating triangles
    task RunTest;
    begin
        $display("time=%10t ************** Driver Is Runnning Test -->%s<-- *****************", $time, testname);

        // wait a couple of cycles for the design to learn the parameters
        repeat (2) @(posedge clk);

        // Now start driving the signals
        while (!$feof(fh)) begin
            // Wait until the design is ready (unhalted)
            while( ! (halt_RnnnnL || !(halt_RnnnnL || top_rast.rast.validTri_R13H)) ) @(posedge clk);

                // read a triangle from the file\
                // Need to fix conversion tool to include depth
                // Data is strongly dependent on parameterization
                // This is brittle code!!!
                // Need some indirection to make this better
                count = $fscanf(fh, "%1b %1d %6x %6x %6x %6x %6x %6x %6x %6x %6x %6x %6x %6x %6x %6x %6x",
                    validTri_R10H, num_vertices,
                    tmp_tri_R10S[0][0], tmp_tri_R10S[0][1], tmp_tri_R10S[0][2],
                    tmp_tri_R10S[1][0], tmp_tri_R10S[1][1], tmp_tri_R10S[1][2],
                    tmp_tri_R10S[2][0], tmp_tri_R10S[2][1], tmp_tri_R10S[2][2],
                    tmp_tri_R10S[3][0], tmp_tri_R10S[3][1], tmp_tri_R10S[3][2],
                    tmp_color_R10U[0],   tmp_color_R10U[1], tmp_color_R10U[2] );

                for( eachVertsA = 0 ; eachVertsA < VERTS ; eachVertsA++ ) begin
                    tri_R10S[eachVertsA][0] = tmp_tri_R10S[eachVertsA][0] & 24'h1FFFFF;
                    tri_R10S[eachVertsA][1] = tmp_tri_R10S[eachVertsA][1] & 24'h1FFFFF;
                    tri_R10S[eachVertsA][2] = tmp_tri_R10S[eachVertsA][2] & 24'h1FFFFF;
                    // $display("Truncated %b to %b", tmp_tri_R10S[eachVertsA][0], tri_R10S[eachVertsA][0]);
                end

                color_R10U[0] = tmp_color_R10U[0] & 24'h1FFFFF;
                color_R10U[1] = tmp_color_R10U[1] & 24'h1FFFFF;
                color_R10U[2] = tmp_color_R10U[2] & 24'h1FFFFF;

                // make sure we read a triangle with either 3 or 4 vertices
                assert (num_vertices==3 || num_vertices==4)
                    else $fatal(2, "ERROR: Wrong number of vertices for triangle at line %0d", line_num);
                assert (VERTS==3 && num_vertices==3 || VERTS==4)
                    else $fatal(2, "Error: Input contains triangle pairs, should only contain singles at line %0d", line_num);

                // If we were able to read the line, continue, else finish this simulation
                if (count!=-1) begin
                    assert (count==17) else $fatal(2, "ERROR: Cannot read triangle at line %0d", line_num);
                line_num = line_num+1;
                @(posedge clk);
            end
        end // while (!$feof(fh))
    $fclose(fh);

    // stop stressing the design
    validTri_R10H =  1'b0;

    // Wait until the design is done processing (unhalted)
    while( ! halt_RnnnnL ) @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    while( ! halt_RnnnnL ) @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    while( ! halt_RnnnnL ) @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    while( ! halt_RnnnnL ) @(posedge clk);

    // Now let the pipe clean and finish
    repeat(10) @(posedge clk);
    TestFinish = 1'b1;
    $display("time=%10t ************** Driver Is Done *****************", $time);

    end
    endtask // RunTest

endmodule
