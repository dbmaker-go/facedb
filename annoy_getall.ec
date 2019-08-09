
#include <string.h>
#include "cannoy.h"

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

void gcidx(void *h, size_t dlen){
	printf("gc annoy index begin: %p, %d\n",h, dlen);
	hannoy idx = (hannoy)(*(void **)h);
	DestroyAnnoyIndex(idx);
	printf("gc annoy index: %x\n", idx);
}

$ create procedure annoy_getall(
	char(128) tbname INPUT, 
	char(128) idxname INPUT,
	int dimension INPUT) returns status, bigint orid, char(4000) ovec ;
{
	$ begin declare section;
		bigint rid;
		char jvec[4000];
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
	int nItem = 0;
	
	
   $ begin code section;
   
   if (dimension > 256)
   	 dimension = 256;
   
   sprintf(aidxname, "%s_%s.tree", tbname, idxname);
   if (spGetCobj(hdbc, aidxname, &idx1, sizeof(idx1)) > 0 ){
   		idx1 = NewAnnoyIndexEuclidean(dimension);
   		AnnoyLoad(idx1, aidxname);
   		i = AnnoyGetNItems(idx1);
   		printf("load %s ok: %d items\n", idxname, i);
   		if (spSetCobj(hdbc, aidxname, &idx1, sizeof(idx1), NULL) == 0) {
   			printf("save idx1 handle into cv: %x\n", idx1);
   			spSetCobjGcfName(hdbc, aidxname, "ANNOY_GETSYSADM", "gcidx");
   		} else {
   			printf("save idx1 handle into cv error\n");
   		}
   } else {
   		printf("get idx1 handle from cv: %x\n", idx1);
   }
   
   sprintf(aidxname, "%s_%s_oid.tree", tbname, idxname);
   if (spGetCobj(hdbc, aidxname, &idx2, sizeof(idx2)) > 0 ){
   		idx2 = NewAnnoyIndexEuclidean(2);
   		AnnoyLoad(idx2, aidxname);
   		i = AnnoyGetNItems(idx2);
   		printf("load %s_oid ok: %d items\n", idxname, i);
   		if (spSetCobj(hdbc, aidxname, &idx2, sizeof(idx2), NULL) == 0) {
   			printf("save idx2 handle into cv: %x\n", idx2);
   			spSetCobjGcfName(hdbc, aidxname, "ANNOY_GETSYSADM", "gcidx");
   		} else {
   			printf("save idx2 handle into cv error\n");
   		}
   } else {
   		printf("get idx2 handle from cv: %x\n", idx2);
   }


		
	$ drop table if exists tmpvec;
	$ create temp table tmpvec(orid bigint, ovec char(4000));
	
	nItem = AnnoyGetNItems(idx1);
	for (i=0; i<nItem; i++){
		AnnoyGetItem(idx1, i, vec);
		AnnoyGetItem(idx2, i, vecoid);

		rid = (long)vecoid[0];
		dvec2jvec(vec,128,jvec);
		$ insert into tmpvec values(:rid, :jvec);
	}
     
	//DestroyAnnoyIndex(idx1);
	//DestroyAnnoyIndex(idx2);
   
   $ returns select orid, ovec from tmpvec into :orid,:ovec;
   
   $ returns status SQLCODE;
   $ end code section;
}

