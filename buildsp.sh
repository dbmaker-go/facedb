#!/bin/sh

cp ../facedb/*.ec ./

dmppcc -d facedb -u SYSADM -n -sp annoy_create.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_get.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_getall.ec

# annoy_create
cc -g -DDEBUG -shared -fPIC -I/home/dbmaker/5.4/include \
   -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_CREATESYSADM.so.debug annoy_create.c -lcannoy -ldmudf

cc -shared -fPIC -I/home/dbmaker/5.4/include \
   -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_CREATESYSADM.so.release annoy_create.c -lcannoy -ldmudf


# annoy_get
cc -g -DDEBUG -shared -fPIC -I/home/dbmaker/5.4/include \
   -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETSYSADM.so.debug annoy_get.c -lcannoy -ldmudf

cc -shared -fPIC -I/home/dbmaker/5.4/include \
   -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETSYSADM.so.release annoy_get.c -lcannoy -ldmudf


# annoy_getall
cc -g -DDEBUG -shared -fPIC -I/home/dbmaker/5.4/include \
   -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETALLSYSADM.so.debug annoy_getall.c -lcannoy -ldmudf

cc -shared -fPIC -I/home/dbmaker/5.4/include \
   -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETALLSYSADM.so.release annoy_getall.c -lcannoy -ldmudf

# udf
cp ../facedb/dfaceudf.c ./
cc -shared -fPIC -o dfaceudf.so.release dfaceudf.c  -I. -I/home/dbmaker/5.4/include \
  -L/home/dbmaker/5.4/lib/so -L. -ldmudf -l dface
cc -g -DDEBUG -shared -fPIC -o dfaceudf.so.debug dfaceudf.c  -I. -I/home/dbmaker/5.4/include \
  -L/home/dbmaker/5.4/lib/so -L. -ldmudf -l dface

if [ "$1" = "DEBUG" ]; then
ln -s ANNOY_CREATESYSADM.so.debug ANNOY_CREATESYSADM.so
ln -s ANNOY_GETSYSADM.so.debug ANNOY_GETSYSADM.so
ln -s ANNOY_GETALLSYSADM.so.debug ANNOY_GETALLSYSADM.so
ln -s dfaceudf.so.debug dfaceudf.so
else
ln -s ANNOY_CREATESYSADM.so.release ANNOY_CREATESYSADM.so
ln -s ANNOY_GETSYSADM.so.release ANNOY_GETSYSADM.so
ln -s ANNOY_GETALLSYSADM.so.release ANNOY_GETALLSYSADM.so
ln -s dfaceudf.so.release dfaceudf.so
fi
