#!/bin/tcsh

setenv EE271_PROJ /afs/ir.stanford.edu/class/ee271/project
setenv EE271_VECT ${EE271_PROJ}/vect

echo "TEST 1: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_00_sv.dat
echo "TEST 1: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_00_sv_ref.ppm


echo "TEST 2: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_01_sv.dat
echo "TEST 2: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_01_sv_ref.ppm

echo "TEST 3: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_01_sv_short.dat
echo "TEST 3: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_01_sv_short_ref.ppm

echo "TEST 4: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_02_sv.dat
echo "TEST 4: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_02_sv_ref.ppm

echo "TEST 5: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_02_sv_short.dat
echo "TEST 5: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_02_sv_short_ref.ppm

echo "TEST 6: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_03_sv_short.dat
echo "TEST 6: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_03_sv_short_ref.ppm

echo "TEST 7: RUN"
./rasterizer_gold out.ppm $EE271_VECT/vec_271_04_sv.dat
echo "TEST 7: CALC DIFF"
diff out.ppm $EE271_VECT/vec_271_04_sv_ref.ppm
