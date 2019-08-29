
#include <string.h>
#include "cannoy.h"
#include "libudf.h"

#ifdef DEBUG
# define TRACE printf
#else
# define TRACE
#endif

#if defined(WIN32) || defined(_WIN64)
# define PATHSEP '\\'
#else
# define PATHSEP '/'
#endif

static void dvec2jvec(double dvec[], int nvec, char *obuf)
{
	int i, pos;
	char tbuf[64];
	
	if (nvec <= 0){
		strcpy(obuf, "[]");
		return;
	}
	
	sprintf(obuf, "[%.15f", dvec[0]);
	pos = strlen(obuf);
	for (i=1; i<nvec; i++){
		sprintf(tbuf, ",%.15f", dvec[i]);
		strcpy(obuf+pos, tbuf);
		pos += strlen(tbuf);
	}
	strcat(obuf, "]");
	
	return;
}

int gcidx(void *data, i63 dlen){
	hannoy idx = NULL;
	TRACE("gc annoy index begin: %p, %d\n", data, dlen);
	idx = (hannoy)(*(void **)data);
	DestroyAnnoyIndex(idx);
	TRACE("gc annoy index: %x\n", idx);
	return 0;
}

$ create procedure annoy_getall(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	int dimension INPUT) returns status, bigint orid, char(4000) ovec ;
{
	$ begin declare section;
		bigint rid;
		char jvec[4000];
		int jveclen;
		char dbdir[1024];
		int dbdirlen;
	$ end declare section;
	
	char aidxname[256];
	double vecoid[2];

	double vec[256];
	int i,j,k;
	hannoy idx1, idx2;
	int nItem = 0;
	
	
	$ begin code section;
   
	if (dimension > 256)
		dimension = 256;
   
	$ select VALUE, LENGTH(VALUE) from SYSCONFIG where KEYWORD='DB_DBDIR' into :dbdir, :dbdirlen;
   
	dbdir[dbdirlen] = 0;
	
	sprintf(aidxname, "%s%c%s_%s.tree", dbdir, PATHSEP, tbname, idxname);

	idx1 = NewAnnoyIndexEuclidean(dimension);
	AnnoyLoad(idx1, aidxname);
	i = AnnoyGetNItems(idx1);
	TRACE("load %s ok: %d items\n", idxname, i);
   
	sprintf(aidxname, "%s%c%s_%s_oid.tree", dbdir, PATHSEP, tbname, idxname);

	idx2 = NewAnnoyIndexEuclidean(2);
	AnnoyLoad(idx2, aidxname);
	i = AnnoyGetNItems(idx2);
	TRACE("load %s_oid ok: %d items\n", idxname, i);
		
	$ drop table if exists tmpvec;
	$ create temp table tmpvec(orid bigint, ovec char(4000));
	
	nItem = AnnoyGetNItems(idx1);
	for (i=0; i<nItem; i++){
		AnnoyGetItem(idx1, i, vec);
		AnnoyGetItem(idx2, i, vecoid);

		rid = (long)vecoid[0];
		dvec2jvec(vec,128,jvec);
		jveclen = strlen(jvec);
		$ insert into tmpvec values(:rid, :jvec :jveclen);
	}
     
	DestroyAnnoyIndex(idx1);
	DestroyAnnoyIndex(idx2);
   
   $ returns select orid, ovec from tmpvec into :orid,:ovec;
   
   $ returns status SQLCODE;
   $ end code section;
}

/*
CREATE FUNCTION ANNOY_CREATESYSADM.LOADSP_GETALL() RETURNS int;
	IN:  dummy
	RET: dummy
	
this udf is only for loading sp library when starting db.
*/
#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  LOADSP_GETALL(int nArg, VAL args[])
{
	VAL ret;

	ret.u.ival = 0;
	ret.len = sizeof(int);
	ret.type = INT_TYP;

exit:
	
	return _RetVal(args, ret);
}


