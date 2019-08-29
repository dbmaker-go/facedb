
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

#ifdef CACHEANNOY
int cacheAnnoy = 1;
#else
int cacheAnnoy = 0;
#endif

int gcidx(void *data, i63 dlen){
	hannoy idx = NULL;
	TRACE("gc annoy index begin: %p, %d\n", data, dlen);
	idx = (hannoy)(*(void **)data);
	DestroyAnnoyIndex(idx);
	TRACE("gc annoy index end: %x\n", idx);
	return 0;
}

void _dumpvec(char *caption, double vec[], int dimension){
	int i;
	printf("=== dump vector: %s ===\n", caption);
	for (i=0; i<dimension; i++){
		printf("%.15f, ", vec[i]);
		if ((i+1)%8 == 0)
			printf("\n");
	}
	printf("\n");
}

int loadAnnoyIndex(void *hdbc, char *aidxname, int dimension, hannoy *oidx)
{
	int rc = 0;
	int i;
	hannoy idx1 = NULL;
	
	if (!cacheAnnoy) {
		idx1 = NewAnnoyIndexEuclidean(dimension);
   		AnnoyLoad(idx1, aidxname);
   		i = AnnoyGetNItems(idx1);
   		TRACE("load %s ok: %d items\n", aidxname, i);
   		*oidx = idx1;
   		return rc;
	}
	
	if (rc= spGetCobj(hdbc, aidxname, &idx1, (i63)sizeof(idx1))){
		rc = 0;
   		idx1 = NewAnnoyIndexEuclidean(dimension);
   		AnnoyLoad(idx1, aidxname);
   		i = AnnoyGetNItems(idx1);
   		TRACE("load %s ok: %d items\n", aidxname, i);
   		
   		if (rc = spSetCobj(hdbc, aidxname, (void *)idx1, (i63)sizeof(idx1), gcidx, NULL, NULL)){
   			rc = 0;
   			TRACE("save idx handle of %s fail: %d\n", aidxname, rc);
   		} else {
   			TRACE("save idx handle of %s: %x\n", aidxname, idx1);
   		}
	} else {
		TRACE("get idx1 handle from cv: %x\n", idx1);
   		i = AnnoyGetNItems(idx1);
   		TRACE("idx1 has %d items\n", i);
	}
	
	*oidx = idx1;
	return rc;
}

int unloadAnnoyIndex(hannoy idx)
{
	if (!cacheAnnoy){
		DestroyAnnoyIndex(idx);
	}
	return 0;
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
	loadAnnoyIndex(hdbc, aidxname, dimension, &idx1);
   
	sprintf(aidxname, "%s%c%s_%s_oid.tree", dbdir, PATHSEP, tbname, idxname);
	loadAnnoyIndex(hdbc, aidxname, 2, &idx2);

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
     
	unloadAnnoyIndex(idx1);
	unloadAnnoyIndex(idx2);
   
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
#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
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

