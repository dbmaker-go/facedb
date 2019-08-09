# facedb: DBMaker database for face recognition

Integrating annoy and dlib into DBMaker for face recognition.
Using dlib to calculate face vector, and using annoy to search
nearest faces from database by a given face image.


1. build sp for annoy index

1.1 translate ec to c.

start database FACEDB and create tables:

```
create table FACES (
 ID  SERIAL(1) primary key,
 NAME  CHAR(20) ,
 PHOTO  FILE ,
 VECTOR  BINARY(2048));

create trigger ains after insert on FACES for each row(
	update FACES set vector = getfacevector(filename(photo)) where id = new.id);

create table tmpvec(orid bigint, ovec char(4000)); -- for sp annoy_getall
create table tmprid(rid bigint, distance double);  -- for sp annoy_create
```

translate ec to c:
```
  dmppcc -d facedb -u SYSADM -n -sp annoy_create.ec // generate annoy_create.c
  dmppcc -d facedb -u SYSADM -n -sp annoy_get.ec    // generate annoy_get.c
  dmppcc -d facedb -u SYSADM -n -sp annoy_getall.ec
```

1.2 build SP libraries(link to libcannoy.so)
```
  cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/v54rel/sdb.out/debug/bin -L.\
   -o ANNOY_GETSYSADM.so annoy_get.c -lcannoy -ldmudf
  
  cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/v54rel/sdb.out/debug/bin -L.\
   -o ANNOY_GETALLSYSADM.so annoy_getall.c -lcannoy -ldmudf
   
  cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/v54rel/sdb.out/debug/bin -L.\
   -o ANNOY_CREATESYSADM.so annoy_create.c -lcannoy -ldmudf
```

1.3 register sp in database
```
create procedure annoy_create(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	char(128) ridcol INPUT,
	char(128) idxcol INPUT,
	int dimession INPUT,
	int nitem OUTPUT) returns status ;

create procedure annoy_get(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	binary(2048) ivec INPUT,
	int dimension INPUT,
	int nItem INPUT) returns status, bigint orid, double odist ;
	
create procedure annoy_getall(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	int dimension INPUT) returns status, bigint orid, char(4000) ovec ;
```

1.4 dummy udf for loading libcannoy.so when starting db

build annoyudf.so:
```
	cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/v54rel/sdb.out/debug/bin -L.\
   -o annoyudf.so annoyload.c -lcannoy -ldmudf
```
register udf into database:
```
	CREATE FUNCTION annoyudf.LOADANNOY() RETURNS int;
```
	
2. build udf for face vector

2.1 build so(link to libdface.so)
```
  cc -g -shared -fPIC -o dfaceudf.so udfgetvec.c  -I. -I/home/dbmaker/5.4/include \
  -L/home/dbmaker/5.4/lib -L. -ldmudf -l dface
```
2.2 register udf:
```
CREATE FUNCTION dfaceudf.GETFACEVECTOR(VARCHAR(256)) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEVECTOR2(long varbinary) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEDIST(char(256), char(256)) RETURNS double;
CREATE FUNCTION dfaceudf.DVECTOJVEC(binary(2048), integer) RETURNS char(4000);
CREATE FUNCTION dfaceudf.JVECTODVEC(char(4000), integer) RETURNS binary(2048);
```

