
#include <string.h>
#include "cannoy.h"

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
   
   AnnoyBuild(idx1, 10);
   AnnoyBuild(idx2, 1);
   
   sprintf(aidxname, "%s_%s.tree", tbname, idxname);
   AnnoySave(idx1, aidxname);
   
   sprintf(aidxname, "%s_%s_oid.tree", tbname, idxname);
   AnnoySave(idx2, aidxname);

	DestroyAnnoyIndex(idx1);
	DestroyAnnoyIndex(idx2);
   
   $ returns status SQLCODE;
   $ end code section;
}

