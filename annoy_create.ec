
#include <string.h>
#include "cannoy.h"
#include "libudf.h"

#if defined(WIN32) || defined(_WIN64)
# define PATHSEP '\\'
#else
# define PATHSEP '/'
#endif

#ifdef DEBUG
# define TRACE printf
#else
# define TRACE
#endif

/**************************************
 * build annoy index
 **************************************/
$ create procedure annoy_create(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	char(128) ridcol INPUT,
	char(128) idxcol INPUT,
	int dimession INPUT,
	int nitem OUTPUT) returns status ;
{
	$ begin declare section;
		bigint rid;
		binary cval[4096];
		varchar sql[1024];
		char dbdir[1024];
		int dbdirlen;
	$ end declare section;
	
	hannoy idx1, idx2;
	char aidxname[256];
	double vec[256];
	double vecoid[2] = {0};
	int id;
	
   $ begin code section;
   
   idx1 = NewAnnoyIndexEuclidean(dimession);
   idx2 = NewAnnoyIndexEuclidean(2);
     
   sprintf(sql.arr, "select %s, %s from %s", ridcol, idxcol, tbname);
   sql.len = strlen(sql.arr);
   
   $ prepare stmt from :sql;
   $ declare cur1 cursor for stmt;
   $ open cur1;
   
   id = 0;
   while (1)
   {
   		$ fetch cur1 into :rid, :cval;
   		if (SQLCODE == SQL_SUCCESS || 
         	SQLCODE == SQL_SUCCESS_WITH_INFO) {
			; 
     	} else {
        	break;
        }

		memcpy(vec, cval, dimession*sizeof(double));

		AnnoyAddItem(idx1, id, vec);

		vecoid[0] = rid;

		AnnoyAddItem(idx2, id, vecoid);
		id++;
	}
   
   $close cur1;
   nitem = id;
   
   TRACE("add %d items into annoy index\n", id);
   
   AnnoyBuild(idx1, 10);
   AnnoyBuild(idx2, 1);
   
   $ select VALUE, LENGTH(VALUE) from SYSCONFIG where KEYWORD='DB_DBDIR' into :dbdir, :dbdirlen;
   
   dbdir[dbdirlen] = 0;
   TRACE("dbdir: %s, %d\n", dbdir, dbdirlen);
   
   sprintf(aidxname, "%s%c%s_%s.tree", dbdir, PATHSEP, tbname, idxname);
   TRACE("save index to: %s\n", aidxname);
   AnnoySave(idx1, aidxname);
   
   sprintf(aidxname, "%s%c%s_%s_oid.tree", dbdir, PATHSEP, tbname, idxname);
   TRACE("save index to: %s\n", aidxname);
   AnnoySave(idx2, aidxname);

	DestroyAnnoyIndex(idx1);
	DestroyAnnoyIndex(idx2);
   
   $ returns status SQLCODE;
   $ end code section;
}

/*
CREATE FUNCTION ANNOY_CREATESYSADM.LOADSP_CREATE() RETURNS int;
	IN:  dummy
	RET: dummy
	
this udf is only for loading sp library when starting db.
*/
#ifdef DB_PCWIN
__declspec(dllexport)
#endif
int  LOADSP_CREATE(int nArg, VAL args[])
{
	VAL ret;

	ret.u.ival = 0;
	ret.len = sizeof(int);
	ret.type = INT_TYP;

exit:
	
	return _RetVal(args, ret);
}

