
 extern int check_bounding_box(/* INPUT */int v0_x, /* INPUT */int v0_y, /* INPUT */int v1_x, /* INPUT */int v1_y, /* INPUT */int v2_x, /* INPUT */int v2_y, /* INPUT */int valid_triangle, /* INPUT */int ll_x, /* INPUT */int ll_y, /* INPUT */int ur_x, 
/* INPUT */int ur_y, /* INPUT */int ss_w_lg2, /* INPUT */int screen_w, /* INPUT */int screen_h, /* INPUT */int valid_bbox, /* INPUT */int r_shift, /* INPUT */int r_val);

 extern int check_hit_count(/* INPUT */int v0_x, /* INPUT */int v0_y, /* INPUT */int v1_x, /* INPUT */int v1_y, /* INPUT */int v2_x, /* INPUT */int v2_y, /* INPUT */int hits, /* INPUT */int ss_w_lg2, /* INPUT */int screen_w, /* INPUT */int screen_h, 
/* INPUT */int r_shift, /* INPUT */int r_val);

 extern int check_hash(/* INPUT */int s_x, /* INPUT */int s_y, /* INPUT */int ss_w_lg2, /* INPUT */int jitter_x, /* INPUT */int jitter_y, /* INPUT */int s_j_x, /* INPUT */int s_j_y);

 extern int check_sample_test(/* INPUT */int v0_x, /* INPUT */int v0_y, /* INPUT */int v1_x, /* INPUT */int v1_y, /* INPUT */int v2_x, /* INPUT */int v2_y, /* INPUT */int s_x, /* INPUT */int s_y, /* INPUT */int hit);

 extern int check_zbuff_init(/* INPUT */int w, /* INPUT */int h, /* INPUT */int ss_w);

 extern int check_zbuff_process_fragment(/* INPUT */int x, /* INPUT */int y, /* INPUT */int ss_x, /* INPUT */int ss_y, /* INPUT */int d, /* INPUT */int R, /* INPUT */int G, /* INPUT */int B);

 extern int check_zbuff_write_ppm();
