# facedb: DBMaker database for face recognition

Integrating annoy and dlib into DBMaker for face recognition.

Using dlib to calculate face vector, and using annoy to search
nearest faces from database by a given face image.

The steps to building facedb are as follows:

### 1. Install cannoy to dbmaker installation path

#### 1.1 build cannoy.
```
git clone https://github.com/dbmaker-go/annoy
cd cwrap
g++ -shared -fPIC -o libcannoy.so cannoy.c
```

here is the linux 64bit binary: https://github.com/dbmaker-go/annoy/raw/master/cwrap/bin/linux_x64/libcannoy.so

for more detail, refer to https://github.com/dbmaker-go/annoy/tree/master/cwrap.

#### 1.2 Install cannoy to dbmaker installation path
```
cp libcannoy.so /home/dbmaker/5.4/lib/so/
cp cannoy.h /home/dbmaker/5.4/include/
```

### 2. Install dface to dbmaker installation path

#### 2.1 build dface library
```
git clone https://github.com/dbmaker-go/dlib
cd dface
g++ -std=c++11 -O3 dface.cpp ../dlib/all/source.cpp -I. -I..  -shared -fPIC \
  -o libdface.so -ljpeg -lpthread -lpng \
  -DDLIB_PNG_SUPPORT=1 -DDLIB_JPEG_SUPPORT=1 -DDLIB_NO_GUI_SUPPORT=1
```
here is the linux x64 binary: https://github.com/dbmaker-go/dlib/raw/master/dface/bin/linux_x64/libdface.so

for more detail, refer to https://github.com/dbmaker-go/dlib/tree/master/dface.

#### 2.2 install dface to dbmaker installation path
```
cp libdface.so /home/dbmaker/5.4/lib/so
cp dface.h /home/dbmaker/5.4/include
```

#### 2.3 install dface modle files to dbmaker installation path

dface need modle files to recognize face. 
download modle files:
```
http://dlib.net/files/shape_predictor_5_face_landmarks.dat.bz2
http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2
http://dlib.net/files/dlib_face_recognition_resnet_model_v1.dat.bz2
```
then unzip them to /home/dbmaker/5.4/

### 3. create a database FACEDB:

#### 3.1 add [FACEDB] section into /home/dbmaker/5.4/dmconfig.ini:
```
[FACEDB]
DB_DBDIR = /home/dbmaker/facedb
DB_PTNUM = 20001
DB_SVADR = 127.0.0.1
```

#### 3.2 crate database and tables

use dmsqls or jtool to create db. then create following tabes:
```
create table tmpvec(orid bigint, ovec char(4000)); -- for precompile sp
create table tmprid(rid bigint, distance double);  -- for precompile sp
```

#### 3.3 start database with dmserver

start database for creating sp and udf.

### 4. build sp for annoy index

#### 4.1 copy annoy_create.ec, annoy_get.ec, annoy_getall.ec to DBDIR
```
git clone https://github.com/dbmaker-go/facedb
cp facedb/annoy_*.ec /home/dbmaker/facedb
```

#### 4.2 translate ec to c:

suppose /home/dbmaker/5.4/bin has been added into PATH env variable.

```
cd /home/dbmaker/facedb
dmppcc -d facedb -u SYSADM -n -sp annoy_create.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_get.ec
dmppcc -d facedb -u SYSADM -n -sp annoy_getall.ec
```

#### 4.3 build SP libraries(link to libcannoy.so)

```
cc -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETSYSADM.so annoy_get.c -lcannoy -ldmudf

cc -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_GETALLSYSADM.so annoy_getall.c -lcannoy -ldmudf

cc -shared -fPIC -I/home/dbmaker/5.4/include -I. -L/home/dbmaker/5.4/lib/so -L.\
   -o ANNOY_CREATESYSADM.so annoy_create.c -lcannoy -ldmudf
```

#### 4.4 register sp in database
```
create procedure annoy_create(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	char(128) ridcol INPUT,
	char(128) idxcol INPUT,
	int dimension INPUT,
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

### 5. build udf for face vector

#### 5.1 copy dfaceudf.c to DBDIR
```
git clone https://github.com/dbmaker-go/facedb
cp facedb/dfaceudf.c /home/dbmaker/facedb/
```

#### 5.2 build udf library dfaceudf.so(link to libdface.so)
```
cd /home/dbmaker/facedb
cc -shared -fPIC -o dfaceudf.so dfaceudf.c  -I. -I/home/dbmaker/5.4/include \
  -L/home/dbmaker/5.4/lib/so -L. -ldmudf -l dface
```

#### 5.3 register udf to database

if can not find libdface.so, please add /home/dbmaker/5.4/lib/so into LD_LIBRARY_PATH env variable.
```
CREATE FUNCTION dfaceudf.GETFACEVECTOR(VARCHAR(256)) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEVECTOR2(long varbinary) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEDIST(char(256), char(256)) RETURNS double;
CREATE FUNCTION dfaceudf.GETFACEDIST2(long varbinary, long varbinary) RETURNS double;
CREATE FUNCTION dfaceudf.DVECTOJVEC(binary(2048), integer) RETURNS char(4000);
CREATE FUNCTION dfaceudf.JVECTODVEC(char(4000), integer) RETURNS binary(2048);
```

### 6. create faces table and recognize face

#### 6.1 create table FACES to store photo and vector:
```
create table faces(id serial primary key, name char(20), photo file, vector binary(2048));
create trigger ains after insert on FACES for each row(
	update FACES set vector = getfacevector(filename(photo)) where id = new.id);
　
insert into faces(name, photo) values('yaoming', '/home/dbsql/photo/yaoming1.jpg');
insert into faces(name, photo) values('yaoming', '/home/dbsql/photo/yaoming2.jpg');
　
select * from faces;
select id,name,dvectojvec(vector, 128) as jvec from faces;
　
// insert all photos into faces table.
```

#### 6.2 build annoy plugin index for search nearest faces:
```
call annoy_create('faces','idxvec','id','vector', 128, ?);
```

#### 6.3 use annoy index to search nearest faces:
```
// search nearest 5 faces from database:
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector('/home/dbsql/photo/yaoming4.jpg'), 128, 5)) as sp
  on faces.id = sp.orid;

// search nearest 1 face (distance < 0.38):
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector('/home/dbsql/photo/yaoming4.jpg'), 128, 1)) as sp
  on faces.id = sp.orid where sp.odist < 0.38;
```

#### 6.4 create stored command for easy use:
```
create command getface5 as 
  select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 5)) as sp
  on faces.id = sp.orid where sp.odist < ?;

execute command getface5(?, 0.38);
&'/home/dbsql/photo/yaoming4.jpg';
```

#### 6.5 client program search faces.

We can give photo content to database to search faces.

in program, we can read image into buffer, and bind it to the following sql:
```
select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 5)) as sp
  on faces.id = sp.orid;
```

The following is an example in go:
```
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

	// sql = "execute command getface5(?, 0.4) // stored command getface5 is available here!
	
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

### 7. Application sample: faceweb

Faceweb is a web server for demostrating face recognition. 

```
+---------+  http   +---------+   tcp   +-----------------+
| browser | <-----> | faceweb | <-----> | facedb(DBMaker) |
+---------+         +---------+         +-----------------+
```
* browser: open camera and capture face image, then send it to faceweb.
* faceweb: receive face image and query faces from facedb.
* facedb: store face photo information, search nearest faces.

#### 7.1 build faceweb server

```
git clone https://github.com/dbmaker-go/facedb
cd facewebgo
GOPATH=$PWD:$GOPATH go build -o faceweb faceweb
```

#### 7.2 start faceweb server

Assume the database FACEDB has been running.

```
cd facewebgo
./faceweb
```

faceweb server will access database: 127.0.0.1:20001/FACEDB.
You can specify db's address, port number and dbname:
```
./faceweb --dbsvadr 192.168.1.52 --dbptnum 20001 --dbname FACEDB
```

For more detail, see usage:
```
./faceweb -h
```

#### 7.3 start browser to access https://127.0.0.1:9090/

If your machine has a camera, you can test face recognition.
You can use ipad or smart phone to access faceweb server, too.


