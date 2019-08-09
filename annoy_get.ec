
#include <string.h>
#include "cannoy.h"


int gcidx(void *h){
	printf("gc annoy index begin: %p\n",h);
	hannoy idx = (hannoy)h;
	DestroyAnnoyIndex(idx);
	printf("gc annoy index: %x\n", idx);
	return 0;
}

void dumpvec(char *caption, double vec[], int dimension){
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
	$ end declare section;
	
	char aidxname[256];
	double vecoid[2];
	char *prid = (void *)vecoid;
	double vec[256];
	int i,j,k;
	hannoy idx1, idx2;
	int newIdx1 = 0, newIdx2 = 0;
	int idary[16];
	double disary[16];
	
	
   $ begin code section;
   
	if (dimension > 256)
		dimension = 256;
   
	sprintf(aidxname, "%s_%s.tree", tbname, idxname);
	if ((idx1 = (hannoy)utcv_get(hdbc, aidxname)) == NULL){
   		idx1 = NewAnnoyIndexEuclidean(dimension);
   		AnnoyLoad(idx1, aidxname);
   		i = AnnoyGetNItems(idx1);
   		printf("load %s ok: %d items\n", idxname, i);
   		
   		utcv_set(hdbc, aidxname, (void *)idx1, gcidx, NULL);
   		printf("save idx1 handle into cv: %x\n", idx1);
	} else {
		printf("get idx1 handle from cv: %x\n", idx1);
   		i = AnnoyGetNItems(idx1);
   		printf("idx1 has %d items\n", i);
	}
   
	sprintf(aidxname, "%s_%s_oid.tree", tbname, idxname);
	if ((idx2 = (hannoy)utcv_get(hdbc, aidxname)) == NULL){
   		idx2 = NewAnnoyIndexEuclidean(2);
   		AnnoyLoad(idx2, aidxname);
   		i = AnnoyGetNItems(idx2);
   		printf("load %s_oid ok: %d items\n", idxname, i);
   		
   		utcv_set(hdbc, aidxname, (void *)idx2, gcidx, NULL);
   		printf("save idx2 handle into cv: %x\n", idx2);
	} else {
		printf("get idx2 handle from cv: %x\n", idx2);
   		i = AnnoyGetNItems(idx2);
   		printf("idx2 has %d items\n", i);
	}

	if (nItem > 16)
		nItem = 16;
	for (i=0; i<16; i++)
		idary[i] = -1;
	
	//char_to_vec(jvec, dimension, vec);
	printf("annoy_get args ivec: type=%d, ind=%d, len=%d, xval=%p, val[0]=%.15f\n", 
		args[3].type, args[3].ind, args[3].len, args[3].u.xval, *((double*)ivec));
	printf("  dimension=%d, nItem=%d\n", dimension, nItem);
	memcpy(vec, ivec, dimension*sizeof(double));
	dumpvec("received:", vec, 128);
	AnnoyGetNnsByVector(idx1, vec, nItem, idary, disary);
	for (i=0; i<nItem; i++){
		if (idary[i] < 0)
			break;
		printf("get nns by vector: %d, %f\n", idary[i], disary[i]);
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
		printf("insert id: %ld, %f\n", rid, dist);
	}
     
	//DestroyAnnoyIndex(idx1);
	//DestroyAnnoyIndex(idx2);
   
   $ returns select rid,distance from tmprid into :orid,:odist;
   
   $ returns status SQLCODE;
   $ end code section;
}

