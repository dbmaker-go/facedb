# facedb: DBMaker database for face recognition

Integrating annoy and dlib into DBMaker for face recognition.

Using dlib to calculate face vector, and using annoy to search
nearest faces from database by a given face image.

The steps to building facedb:

1. build cannoy library and install it to dbmaker installation path

* down cannoy source
```
git clone https://github.com/dbmaker-go/annoy
```

* build cannoy.
```
cd cwrap
g++ -shared -fPIC -o libcannoy.so cannoy.c
```
here is the linux 64bit binary: https://github.com/dbmaker-go/annoy/raw/master/cwrap/bin/linux_x64/libcannoy.so

for more detail, refer to https://github.com/dbmaker-go/annoy/tree/master/cwrap.

* install cannoy to dbmaker installation path
```
cp libcannoy.so /home/dbmaker/5.4/lib/so/
cp cannoy.h /home/dbmaker/5.4/include/
```

2. build dface library and install it to dbmaker installation path

* down dface source
```
git clone https://github.com/dbmaker-go/dlib
```

* build dface library
```
cd dface
g++ -std=c++11 -O3 dface.cpp ../dlib/all/source.cpp -I. -I..  -shared -fPIC \
  -o libdface.so -ljpeg -lpthread -lpng \
  -DDLIB_PNG_SUPPORT=1 -DDLIB_JPEG_SUPPORT=1 -DDLIB_NO_GUI_SUPPORT=1
```
here is the linux x64 binary: https://github.com/dbmaker-go/dlib/raw/master/dface/bin/linux_x64/libdface.so

for more detail, refer to https://github.com/dbmaker-go/dlib/tree/master/dface.

* install dface to dbmaker installation path
```
cp libdface.so /home/dbmaker/5.4/lib/so
cp dface.h /home/dbmaker/5.4/include
```

3. create a database FACEDB:

* add [FACEDB] section into /home/dbmaker/5.4/dmconfig.ini:
```
[FACEDB]
DB_DBDIR = /home/dbmaker/facedb
DB_PTNUM = 20001
DB_SVADR = 127.0.0.1
```

* crate database and tables
```
create table tmpvec(orid bigint, ovec char(4000)); -- for precompile sp
create table tmprid(rid bigint, distance double);  -- for precompile sp
```

* start database with dmserver

4. build sp for annoy index

* copy annoy_create.ec, annoy_get.ec, annoy_getall.ec to DBDIR
```
cp annoy_*.ec /home/dbmaker/facedb
```

* translate ec to c:
```
cd /home/dbmaker/facedb
dmppcc -d facedb -u SYSADM -n -sp annoy_create.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_get.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_getall.ec
```

* build SP libraries(link to libcannoy.so)
```
cc -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETSYSADM.so annoy_get.c -lcannoy -ldmudf
　
cc -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETALLSYSADM.so annoy_getall.c -lcannoy -ldmudf
　
cc -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
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

5. build udf for face vector

* copy dfaceudf.c to DBDIR
```
cp dfaceudf.c /home/dbmaker/facedb/
```

* build so(link to libdface.so)
```
cd /home/dbmaker/facedb
cc -shared -fPIC -o dfaceudf.so dfaceudf.c  -I. -I/home/dbmaker/5.4/include \
  -L/home/dbmaker/5.4/lib/so -L. -ldmudf -l dface
```

* register udf to database
if can not find libdface.so, please add /home/dbmaker/5.4/lib/so into LD_LIBRARY_PATH env variable.
```
CREATE FUNCTION dfaceudf.GETFACEVECTOR(VARCHAR(256)) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEVECTOR2(long varbinary) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEDIST(char(256), char(256)) RETURNS double;
CREATE FUNCTION dfaceudf.DVECTOJVEC(binary(2048), integer) RETURNS char(4000);
CREATE FUNCTION dfaceudf.JVECTODVEC(char(4000), integer) RETURNS binary(2048);
```

6. create faces table and recognize face

before call udf, msut download modle files, then unzip to dbmaker installation path: /home/dbmaker/5.4
```
http://dlib.net/files/shape_predictor_5_face_landmarks.dat.bz2
http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2
http://dlib.net/files/dlib_face_recognition_resnet_model_v1.dat.bz2
```

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
　
// search nearest 5 faces from database:
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector('/home/dbsql/photo/yaoming4.jpg'), 128, 5)) as sp
  on faces.id = sp.orid;
　
// in program, we can read image into buffer, and bind it to the following sql:
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 5)) as sp
  on faces.id = sp.orid;
　
The following is an example in go:
　
	var db *sql.DB
	var err error
	if db, err = sql.Open("dbmaker", "DSN=FACEDB;UID=SYSADM;PWD=;PTNUM=20001;SVADR=127.0.0.1;"); err != nil {
		return err
	}
	defer db.Close()

	sql = `select id, name, sp.odist as distance from faces join 
		(call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 5)) as sp
		on faces.id = sp.orid;`
	img, _ := ioutil.ReadFile("/home/dbsql/photo/yaoming8.jpg")

	if rows, err := db.Query(sql, img); err != nil {
		return err
	} else {
		var id int
		var name string
		var dist float64

		for rows.Next() {
			if err = rows.Scan(&id, &name, &dist); err != nil {
				return err
			}
			// consume id,name,dist
		}
		if err = rows.Close(); err != nil {
			return err
		}
	}
```

7. Application sample: faceweb

* build faceweb server
```
cd facewebgo
GOPATH=$PWD:$GOPATH go build -o faceweb faceweb
```

* start faceweb server
```
cd facewebgo
./faceweb
```
faceweb server will access face database. 127.0.0.1:20001/FACEDB.
You can specify db's address, port number and dbname:
```
./faceweb --dbsvadr 192.168.1.52 --dbptnum 20001 --dbname FACEDB
```

* start browser to access https://127.0.0.1:9090/
If your machine has a camera, you can test face recognition.
You can use ipad or smart phone to access faceweb server, too.
