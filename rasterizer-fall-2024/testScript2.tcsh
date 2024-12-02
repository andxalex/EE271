#!/bin/tcsh

setenv EE271_PROJ /afs/ir.stanford.edu/class/ee271/project
setenv EE271_VECT ${EE271_PROJ}/vect
set diff_output = "diff_results.log"

# Clear the diff output file
rm -f $diff_output
touch $diff_output

echo "TEST 1: RUN"
make run RUN="+testname=$EE271_VECT/vec_271_00_sv.dat"
echo "TEST 1: CALC DIFF"
diff verif_out.ppm $EE271_VECT/vec_271_00_sv_ref.ppm >> $diff_output

echo "TEST 2: RUN"
make run RUN="+testname=$EE271_VECT/vec_271_01_sv.dat"
echo "TEST 2: CALC DIFF"
diff verif_out.ppm $EE271_VECT/vec_271_01_sv_ref.ppm >> $diff_output

echo "TEST 3: RUN"
make run RUN="+testname=$EE271_VECT/vec_271_01_sv_short.dat"
echo "TEST 3: CALC DIFF"
diff verif_out.ppm $EE271_VECT/vec_271_01_sv_short_ref.ppm >> $diff_output

echo "TEST 4: RUN"
make run RUN="+testname=$EE271_VECT/vec_271_02_sv.dat"
echo "TEST 4: CALC DIFF"
diff verif_out.ppm $EE271_VECT/vec_271_02_sv_ref.ppm >> $diff_output

echo "TEST 5: RUN"
make run RUN="+testname=$EE271_VECT/vec_271_02_sv_short.dat"
echo "TEST 5: CALC DIFF"
diff verif_out.ppm $EE271_VECT/vec_271_02_sv_short_ref.ppm >> $diff_output

echo "TEST 6: RUN"
make run RUN="+testname=$EE271_VECT/vec_271_03_sv_short.dat"
echo "TEST 6: CALC DIFF"
diff verif_out.ppm $EE271_VECT/vec_271_03_sv_short_ref.ppm >> $diff_output

# Check if the diff_output file contains any data
if (-s $diff_output) then
    echo "Differences were found in the following tests:"
    cat $diff_output
else
    echo "No differences were found in any test."
endif
 
