
cp ../facedb/*.ec ./

dmppcc -d facedb -u SYSADM -n -sp annoy_create.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_get.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_getall.ec

# sp
cl /c annoy_create.c /I include
link /DLL /OUT:ANNOY_CREATESYSADM.DLL annoy_craete.obj lib/cannoy.lib lib/dmudf.lib

cl /c annoy_get.c /I include
link /DLL /OUT:ANNOY_GETSYSADM.DLL annoy_get.obj lib/cannoy.lib lib/dmudf.lib

cl /c annoy_getall.c /I include
link /DLL /OUT:ANNOY_GETALLSYSADM.DLL annoy_getall.obj lib/cannoy.lib lib/dmudf.lib

# udf
cl /c dfaceudf.c /I include /D DEBUG /D _DEBUG /Zi /D WIN32 /D WINDOWS  /MDd /Od
link /DLL dfaceudf.obj lib/dface.lib lib/dmudf.lib /PDB:dfaceudf.pdb /DEBUG

