tar -C ${PREFIX} -xf $SRC_DIR/libtensorflow_cc_output.tar
#rsync -av ${PREFIX}/include/external/local_tsl/tsl/ ${PREFIX}/include/tsl
mkdir -p ${PREFIX}/include/tsl
cp -av ${PREFIX}/include/external/local_tsl/tsl/* ${PREFIX}/include/tsl