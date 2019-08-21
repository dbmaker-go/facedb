connect to facedb sysadm;
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
create function ANNOY_CREATESYSADM.loadsp_create() returns int;
create function ANNOY_GETSYSADM.loadsp_get() returns int;
create function ANNOY_GETALLSYSADM.loadsp_getall() returns int;

CREATE FUNCTION dfaceudf.GETFACEVECTOR(VARCHAR(256)) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEVECTOR2(long varbinary) RETURNS binary(2048);
CREATE FUNCTION dfaceudf.GETFACEDIST(char(256), char(256)) RETURNS double;
CREATE FUNCTION dfaceudf.DVECTOJVEC(binary(2048), integer) RETURNS char(4000);
CREATE FUNCTION dfaceudf.JVECTODVEC(char(4000), integer) RETURNS binary(2048);

create table faces(id serial primary key, name char(20), photo file, vector binary(2048));
create trigger ains after insert on FACES for each row(
	update FACES set vector = getfacevector(filename(photo)) where id = new.id);

insert into faces(name, photo) values('yaoming', '/home/dbsql/photo/yaoming1.jpg');
insert into faces(name, photo) values('yaoming', '/home/dbsql/photo/yaoming2.jpg');

select * from faces;
select id,name,dvectojvec(vector, 128) as jvec from faces;

call annoy_create('faces','idxvec','id','vector', 128, ?);

select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector('/home/dbsql/photo/yaoming4.jpg'), 128, 5)) as sp
  on faces.id = sp.orid;

-- getface5(givenImg, maxDist): select top 5 faces where distance(photo, givenImg) <= maxDist
-- execute command getface5(?, 0.38)
--
create command getface5 as select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 5)) as sp
  on faces.id = sp.orid where sp.odist < ?;

--
-- getface1(givenImg): select top 1 face which is the most similar to givenImg
--
create command getface1 as select id, name, sp.odist as distance from faces join 
  (call annoy_get('faces', 'idxvec', getfacevector2(?), 128, 1)) as sp
  on faces.id = sp.orid;


