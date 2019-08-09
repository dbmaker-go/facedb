# facedb: DBMaker database for face recognition

Integrating annoy and dlib into DBMaker for face recognition.

Using dlib to calculate face vector, and using annoy to search
nearest faces from database by a given face image.

The steps to building facedb:

1. create a database FACEDB:

* add [FACEDB] section into /home/dbmaker/5.4/dmconfig.ini:
```
[FACEDB]
DB_DBDIR = /home/dbmaker/facedb
DB_PTNUM = 24530
DB_SVADR = 127.0.0.1
```

* crate database and tables
```
create table tmpvec(orid bigint, ovec char(4000)); -- for precompile sp
create table tmprid(rid bigint, distance double);  -- for precompile sp
```

* export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/dbmaker/facedb:.
this is for loading libcannoy.so and libdface.so when starting db.

* start database with dmserver

2. build sp for annoy index

* build cannoy, then copy libcannoy.so and cannoy.h to DBDIR
refer to https://github.com/dbmaker-go/annoy/tree/master/cwrap

* copy annoy_create.ec, annoy_get.ec, annoy_getall.ec to DBDIR

* translate ec to c:
```
  dmppcc -d facedb -u SYSADM -n -sp annoy_create.ec
  dmppcc -d facedb -u SYSADM -n -sp annoy_get.ec
  dmppcc -d facedb -u SYSADM -n -sp annoy_getall.ec
```

* build SP libraries(link to libcannoy.so)
```
cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETSYSADM.so annoy_get.c -lcannoy -ldmudf
  
cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETALLSYSADM.so annoy_getall.c -lcannoy -ldmudf
   
cc -g -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_CREATESYSADM.so annoy_create.c -lcannoy -ldmudf
```

* register sp in database
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
　
// following functions is only for load sp libraries when starting db.
create function ANNOY_CREATESYSADM.loadsp_create() returns int;
create function ANNOY_GETSYSADM.loadsp_get() returns int;
create function ANNOY_GETALLSYSADM.loadsp_getall() returns int;
```

3. build udf for face vector

* build dface, then copy libdface.so and dface.h to DBDIR
refer to https://github.com/dbmaker-go/dlib/tree/master/dface

* copy dfaceudf.c to DBDIR

* build so(link to libdface.so)
```
  cc -g -shared -fPIC -o dfaceudf.so dfaceudf.c  -I. -I/home/dbmaker/5.4/include \
  -L/home/dbmaker/5.4/lib -L. -ldmudf -l dface
```

* register udf to database
```
CREATE FUNCTION dfaceudf.GETFACEVECTOR(VARCHAR(256)) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEVECTOR2(long varbinary) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEDIST(char(256), char(256)) RETURNS double;
CREATE FUNCTION dfaceudf.DVECTOJVEC(binary(2048), integer) RETURNS char(4000);
CREATE FUNCTION dfaceudf.JVECTODVEC(char(4000), integer) RETURNS binary(2048);
```

4. create faces table and recognize face

before call udf, must copy dlib modle files to DBDIR.

```
create table faces(id serial primary key, name char(20), photo file, vector binary(2048));
create trigger ains after insert on FACES for each row(
	update FACES set vector = getfacevector(filename(photo)) where id = new.id);

insert into faces(name, photo) values('yaoming', '/home/dbsql/photo/yaoming1.jpg');
insert into faces(name, photo) values('yaoming', '/home/dbsql/photo/yaoming2.jpg');

select * from faces;
select id,name,dvectojvec(vector, 128) as jvec from faces;

// insert all photos into faces table.

// build annoy index:
call annoy_create('faces','idxvec','id','vector', 128, ?);

// search nearest face from database
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector('/home/dbsql/photo/yaoming4.jpg'), 128, 5)) as sp
  on faces.id = sp.orid;

// in program, we can read image into buffer, and bind it to the following sql:
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 5)) as sp
  on faces.id = sp.orid;

read file '/home/dbsql/photo/yaoming5.jpg' into buffer, and bind it to parameter.

```

