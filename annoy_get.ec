
#include <string.h>
#include "cannoy.h"
#include "libudf.h"

#ifdef DEBUG
# define TRACE printf
# define dumpvec _dumpvec
#else
# define TRACE
# define dumpvec
#endif

#if defined(WIN32) || defined(_WIN64)
# define PATHSEP '\\'
#else
# define PATHSEP '/'
#endif

int gcidx(void *h){
	TRACE("gc annoy index begin: %p\n",h);
	hannoy idx = (hannoy)h;
	DestroyAnnoyIndex(idx);
	TRACE("gc annoy index: %x\n", idx);
	return 0;
}

void _dumpvec(char *caption, double vec[], int dimension){
	printf("=== dump vector: %s ===\n", caption);
	for (int i=0; i<dimension; i++){
		printf("%.15f, ", vec[i]);
		if ((i+1)%8 == 0)
			printf("\n");
	}
	printf("\n");
}

$ create procedure annoy_get(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	binary(2048) ivec INPUT,
	int dimension INPUT,
	int nItem INPUT) returns status, bigint orid, double odist ;
{
	$ begin declare section;
		bigint rid;
		double dist;
		char dbdir[1024];
		int dbdirlen;
	$ end declare section;
	
	char aidxname[256];
	double vecoid[2];
	char *prid = (void *)vecoid;
	double vec[256];
	int i,j,k;
	hannoy idx1, idx2;
	int newIdx1 = 0, newIdx2 = 0;
	int *idary = 0;
	double *disary = 0;
	
   $ begin code section;
   
	if (dimension > 256)
		dimension = 256;
		
	$ select VALUE, LENGTH(VALUE) from SYSCONFIG where KEYWORD='DB_DBDIR' into :dbdir, :dbdirlen;
   
	dbdir[dbdirlen] = 0;

	sprintf(aidxname, "%s%c%s_%s.tree", dbdir, PATHSEP, tbname, idxname);
	if ((idx1 = (hannoy)utcv_get(hdbc, aidxname)) == NULL){
   		idx1 = NewAnnoyIndexEuclidean(dimension);
   		AnnoyLoad(idx1, aidxname);
   		i = AnnoyGetNItems(idx1);
   		TRACE("load %s ok: %d items\n", idxname, i);
   		
   		utcv_set(hdbc, aidxname, (void *)idx1, gcidx, NULL);
   		TRACE("save idx1 handle into cv: %x\n", idx1);
	} else {
		TRACE("get idx1 handle from cv: %x\n", idx1);
   		i = AnnoyGetNItems(idx1);
   		TRACE("idx1 has %d items\n", i);
	}
   
	sprintf(aidxname, "%s%c%s_%s_oid.tree", dbdir, PATHSEP, tbname, idxname);
	if ((idx2 = (hannoy)utcv_get(hdbc, aidxname)) == NULL){
   		idx2 = NewAnnoyIndexEuclidean(2);
   		AnnoyLoad(idx2, aidxname);
   		i = AnnoyGetNItems(idx2);
   		TRACE("load %s_oid ok: %d items\n", idxname, i);
   		
   		utcv_set(hdbc, aidxname, (void *)idx2, gcidx, NULL);
   		TRACE("save idx2 handle into cv: %x\n", idx2);
	} else {
		TRACE("get idx2 handle from cv: %x\n", idx2);
   		i = AnnoyGetNItems(idx2);
   		TRACE("idx2 has %d items\n", i);
	}

	idary = (int *)malloc(nItem * sizeof(int));
	if (idary == 0) {
		SQLCODE = -1;
		goto errexit;
	}
	for (i=0; i<nItem; i++)
		idary[i] = -1;
	disary = (double *)malloc(nItem * sizeof(double));
	if (disary == 0) {
		SQLCODE = -1;
		goto errexit;
	}
	
	//char_to_vec(jvec, dimension, vec);
	TRACE("annoy_get args ivec: type=%d, ind=%d, len=%d, xval=%p, val[0]=%.15f\n", 
		args[3].type, args[3].ind, args[3].len, args[3].u.xval, *((double*)ivec));
	TRACE("  dimension=%d, nItem=%d\n", dimension, nItem);
	memcpy(vec, ivec, dimension*sizeof(double));
	dumpvec("received:", vec, 128);
	AnnoyGetNnsByVector(idx1, vec, nItem, idary, disary);
	for (i=0; i<nItem; i++){
		if (idary[i] < 0)
			break;
		TRACE("get nns by vector: %d, %f\n", idary[i], disary[i]);
	}
	
	
	$ drop table if exists tmprid;
	$ create temp table tmprid(rid bigint, distance double);
	
	for (i=0; i<nItem; i++){
		if (idary[i] < 0)
			break;
		AnnoyGetItem(idx2, idary[i], vecoid);

		rid = (long)vecoid[0];
		dist = disary[i];
		$ insert into tmprid values(:rid, :dist);
		TRACE("insert id: %ld, %f\n", rid, dist);
	}
     
	//DestroyAnnoyIndex(idx1);
	//DestroyAnnoyIndex(idx2);
   
   $ returns select rid,distance from tmprid into :orid,:odist;

errexit:
   
   $ returns status SQLCODE;
   $ end code section;
}


/*
CREATE FUNCTION ANNOY_CREATESYSADM.LOADSP_GET() RETURNS int;
	IN:  dummy
	RET: dummy
	
this udf is only for loading sp library when starting db.
*/
#ifdef DB_PCWIN
__declspec(dllexport)
#endif
int  LOADSP_GET(int nArg, VAL args[])
{
	VAL ret;

	ret.u.ival = 0;
	ret.len = sizeof(int);
	ret.type = INT_TYP;

exit:
	
	return _RetVal(args, ret);
}

