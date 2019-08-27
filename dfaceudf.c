

#include "dface.h"
#include "libudf.h"
#include <string.h>
#include <stdio.h>
#include <time.h>

#ifdef DEBUG
# define TRACE printf
#else
# define TRACE
#endif

//int  GETFACEVECTOR(int nArg, VAL args[]);
//int  GETFACEVECTOR2(int nArg, VAL args[]);

#define faceshape DFACE_SHAPE68
#define cvdface "dface"

#define ERR_UDF (9300)

#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
void gcCloseDface(void *h, size_t dlen){
	dface dh = NULL;
	TRACE("gc close dface begin: %p, %d\n",h, dlen);
	dh = (dface)(*(void **)h);
	CloseDface(dh);
	TRACE("gc close dface end: %x\n", dh);
}

static char instdir[1024];

static dface getDfaceHanle(VAL args[]){
	// get dface handle from cv
	int rc = 0;
	dface dh = NULL;
	time_t t1,t2;
	
	if (rc = udfGetCobj(args, cvdface, &dh, sizeof(dh))){
		dh = NULL;
		TRACE("get dface handle from cv fail: %d\n", rc);
	} else {
		TRACE("get dface handle from cv OK: %x\n", dh);
		return dh;
	}
	
	utInstDir(instdir);
	
	t1 = time(0);
	if (rc = OpenDface(&dh, faceshape, instdir)) {
		TRACE("open dface engine error: %d\n", rc);
		return NULL;
	}
	t2 = time(0);
	TRACE("open dface cost %f seconds\n", difftime(t2,t1));
	
	if (rc = udfSetCobj(args, cvdface, &dh, sizeof(dh), gcCloseDface, NULL, NULL)){
		TRACE("save dface handle into cv error. %d\n", rc);
		CloseDface(dh);
		return NULL;
	} else {
		TRACE("save dface handle into cv ok: %x\n", dh);
	}
	
	return dh;
}

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

static void jvec2dvec(char *json, int dimension, double *vec){
	int i,j;
	char *p;
	
	if (json[0] == '\0'){
		TRACE("invalid json: empty\n");
		return;
	}
	if (json[0] != '['){
		TRACE("invalid json: %s\n", json);
		return;
	} else {
		json++;
	}
	
	for (i=0; i<dimension; i++){
		vec[i] = strtod(json, &p);
		if (*p == '\0')
			break;
		json = p+1;
	}

	return;
}



/*
CREATE FUNCTION dfaceudf.GETFACEVECTOR(VARCHAR(256)) RETURNS binary(2048);
	IN:  imgfilename varchar(256) // char[]
	RET: facevector binary(2048)  // double[]
*/
#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  GETFACEVECTOR(int nArg, VAL args[])
{
	int rc = 0, lrc, i, len;
	char imgfn[256]; // = (char *)args[0].u.sval;
	dface dh = 0;
	facevector fvec;
	char *dvec;
	time_t t1,t2;
	
	i = args[0].len>255? 255:args[0].len;
	strncpy(imgfn, args[0].u.xval, i);
	imgfn[i] = '\0';
	len = strlen(imgfn);
	for (i=len-1; i>0 && imgfn[i]==' '; i--)
		imgfn[i] = '\0';
	TRACE("args[0].len = %d\n", args[0].len);
	TRACE("img:(%d):%s\n", strlen(imgfn), imgfn);
	
	if ((dh = getDfaceHanle(args)) == NULL){
		TRACE("get dface handle fail.\n");
		rc = ERR_UDF;
		goto exit;
	}
	
	t1 = time(0);
	if (rc = GetFaceVector(dh, imgfn, &fvec)) {
		TRACE("get face vector error: %d\n", rc);
		rc = ERR_UDF;
		goto exit;
	}
	t2 = time(0);
	TRACE("get face vector cost %f seconds\n", difftime(t2,t1));
	
	// return vector
	if (rc = _UDFAllocMem(args, &dvec, sizeof(fvec)))
		return rc;
	memcpy(dvec, fvec, sizeof(fvec));
	args[0].u.xval = dvec;
	args[0].len = sizeof(fvec);
	args[0].type = BIN_TYP;
	
exit:
	//if ((lrc = CloseDface(dh)) > rc)
	//	rc = lrc;
	if (rc){
		TRACE("getfacevector error: %d\n", rc);
		return rc;
	}
	
	TRACE("getfacevector end: return char %d\n", args[0].len);
	fflush(stdout);
	
	return _RetVal(args, args[0]);
}


/*
CREATE FUNCTION dfaceudf.GETFACEVECTOR2(long varbinary) RETURNS binary(2048);
	IN:  imgbb long varbinary     // BBHDR
	RET: facevector binary(2048)  // double[]
*/

#define MAX_BUFLEN (1024)
#define MIN(a, b) ((a)<(b)?(a):(b))

static int Blob2TmpFile(VAL args[], BBObj bbSrc, char *ofName)
{
	int rc = 0, lrc;
	i31   hSrc = 0;           /* handles of input blob and output temp blob   */
	i31   szSrc;              /* input blob size                              */
	i31   szBuf, szRead;      /* buffer szie and return read size             */
	i31   length;
	char  buf[MAX_BUFLEN];    /* working memory for copying data              */
	char imgfn[256];
	i63 tempfd = 0;
	i63 tempoff = 0;
	i63 retLen;
	
	if (rc = _UDFBbSize(args, bbSrc, &szSrc)){
		TRACE("get bb size error: %d\n", rc);
		goto exit;
	}
	length = szSrc;
  
  if (rc = _UDFBbOpen(args, bbSrc, &hSrc)){
  	TRACE("open bb error: %d\n", rc);
  	rc = ERR_UDF;
    goto exit;
  }
  
  // make a tmp file for writing image:
  if (utMksTemp(imgfn,&tempfd))
  {
  	rc = ERR_UDF;
  	goto exit;
  }
  
  strcpy(ofName, imgfn);

  /**************************************************************************
   * loop to read data from source BLOB and write to temp BLOB
   **************************************************************************/
  while (1)
    {
    szBuf = MIN(length, MAX_BUFLEN);
    if (rc = _UDFBbRead(args, hSrc, szBuf, &szRead, buf))
      goto exit;

     if (utFileWrite(tempfd, tempoff, szRead, buf, &retLen))
     {
     	rc = ERR_UDF;
     	goto exit;
     }
     tempoff += szRead;

    length -= szRead;

    if ((length == 0) || (szRead == 0))
      break;
    }

exit:
	if (hSrc && ((lrc = _UDFBbClose(args, hSrc)) > rc))
	    rc = lrc;
	if (tempfd > 0)
		utFileClose(tempfd);

    return rc;
}

#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  GETFACEVECTOR2(int nArg, VAL args[])
{
	int rc = 0, lrc, i, len;
	BBObj bbSrc;
	char imgfn[256];
	dface dh = NULL;
	facevector fvec;
	char *dvec;
	time_t t1,t2;

	if (args[0].type == NULL_TYP){
		TRACE("NULL args\n");
		goto exit;
	}

	TRACE("args[0].type = %x\n", args[0].type);

	memcpy((char *)(&bbSrc), args[0].u.xval, BBID_SIZE); /* #005 */

	if (rc = Blob2TmpFile(args, bbSrc, imgfn))
		goto exit;
  
	len = strlen(imgfn);
	for (i=len-1; i>0 && imgfn[i]==' '; i--)
		imgfn[i] = '\0';
	TRACE("args[0].len = %d\n", args[0].len);
	TRACE("img:(%d):%s\n", strlen(imgfn), imgfn);
	
	if ((dh = getDfaceHanle(args)) == NULL){
		TRACE("get dface handle fail.\n");
		rc = ERR_UDF;
		goto exit;
	}
	
	t1 = time(0);
	if (rc = GetFaceVector(dh, imgfn, &fvec)) {
		TRACE("get face vector error: %d\n", rc);
		rc = ERR_UDF;
		goto exit;
	}
	t2 = time(0);
	TRACE("get face vector cost %f seconds\n", difftime(t2,t1));
	
	// return vector
	if (rc = _UDFAllocMem(args, &dvec, sizeof(fvec)))
		return rc;
	memcpy(dvec, fvec, sizeof(fvec));
	args[0].u.xval = dvec;
	args[0].len = sizeof(fvec);
	args[0].type = BIN_TYP;
	
exit:

	utFileRemove(imgfn);
    
	//if (dh && (lrc = CloseDface(dh)) > rc)
	//	rc = lrc;
	if (rc){
		TRACE("getfacevector error: %d\n", rc);
		return rc;
	}
	
	TRACE("getfacevector end: return %d bytes\n", args[0].len);
	fflush(stdout);
	
	return _RetVal(args, args[0]);
}

/*
CREATE FUNCTION dfaceudf.GETFACEDIST(char(256), char(256)) RETURNS double;
*/


#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  GETFACEDIST(int nArg, VAL args[])
{
	char imgfn1[256];
	char imgfn2[256];
	dface dh = NULL;
	double dist;
	int rc, lrc, i;
	size_t len;
	
	i = args[0].len>255? 255:args[0].len;
	strncpy(imgfn1, args[0].u.xval, i);
	imgfn1[i] = '\0';
	len = strlen(imgfn1);
	for (i=len-1; i>0 && imgfn1[i]==' '; i--)
		imgfn1[i] = '\0';
	TRACE("args[0].len = %d\n", args[0].len);
	TRACE("img1:(%d):%s\n", strlen(imgfn1), imgfn1);
	
	i = args[1].len>255? 255:args[1].len;
	strncpy(imgfn2, args[1].u.xval, i);
	imgfn2[i] = '\0';
	len = strlen(imgfn2);
	for (i=len-1; i>0 && imgfn2[i]==' '; i--)
		imgfn2[i] = '\0';
	TRACE("args[1].len = %d\n", args[1].len);
	TRACE("img2:(%d):%s\n", strlen(imgfn2), imgfn2);
	
	if ((dh = getDfaceHanle(args)) == NULL){
		TRACE("get dface handle fail.\n");
		rc = ERR_UDF;
		goto exit;
	}
	
	if (rc = GetFaceDistance(dh, imgfn1, imgfn2, &dist)){
		TRACE("getfacedistance error: %d\n", rc);
		rc = ERR_UDF;
		goto exit;
	}
	
	args[0].type = FLT_TYP;
	args[0].u.fval = dist;
	args[0].len = sizeof(dist);
	
exit:
	if (rc)
		return rc;
	
	TRACE("getfacedistance end: return %.14f\n", args[0].u.fval);
	fflush(stdout);
	
	return _RetVal(args, args[0]);
}

/*
CREATE FUNCTION dfaceudf.GETFACEDIST2(long varbinary, long varbinary) RETURNS double;
*/


#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  GETFACEDIST2(int nArg, VAL args[])
{
	char imgfn1[256];
	char imgfn2[256];
	dface dh = NULL;
	double dist;
	int rc, lrc, i;
	size_t len;
	BBObj bb1, bb2;
	
	if (args[0].type == NULL_TYP || args[1].type == NULL_TYP){
		TRACE("NULL args\n");
		goto exit;
	}
	
	memcpy((char *)(&bb1), args[0].u.xval, BBID_SIZE);
	memcpy((char *)(&bb2), args[1].u.xval, BBID_SIZE);
	
	if (rc = Blob2TmpFile(args, bb1, imgfn1))
		goto exit;
	if (rc = Blob2TmpFile(args, bb2, imgfn2))
		goto exit;
	
	TRACE("args[0].len = %d\n", args[0].len);
	TRACE("img1:(%d):%s\n", strlen(imgfn1), imgfn1);
	
	TRACE("args[1].len = %d\n", args[1].len);
	TRACE("img2:(%d):%s\n", strlen(imgfn2), imgfn2);
	
	if ((dh = getDfaceHanle(args)) == NULL){
		TRACE("get dface handle fail.\n");
		rc = ERR_UDF;
		goto exit;
	}
	
	if (rc = GetFaceDistance(dh, imgfn1, imgfn2, &dist)){
		TRACE("getfacedistance error: %d\n", rc);
		rc = ERR_UDF;
		goto exit;
	}
	
	args[0].type = FLT_TYP;
	args[0].u.fval = dist;
	args[0].len = sizeof(dist);
	
exit:
	
	utFileRemove(imgfn1);
	utFileRemove(imgfn2);
	
	if (rc)
		return rc;
	
	TRACE("getfacedistance end: return %.14f\n", args[0].u.fval);
	fflush(stdout);
	
	return _RetVal(args, args[0]);
}

/*
CREATE FUNCTION dfaceudf.DVECTOJVEC(binary(2048), integer) RETURNS char(4000);
	IN:  dvec binary(2048) // double[]
	IN:  vecLen int
	RET: json char(4000)
double array to json array: convert double[128] to json array: '[1, 2, 3, ...]'
*/


#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  DVECTOJVEC(int nArg, VAL args[])
{
	int rc = 0;
	char *obuf;
	int dimension;
	
	if (args[0].type == NULL_TYP){
		return _RetVal(args, args[0]);
	}
	
	if (args[1].type == NULL_TYP){
		dimension = 1;
	} else {
		dimension = args[1].u.ival;
	}
	
	if (dimension > args[0].len/8){
		dimension = args[0].len/8;
	}
	
	if (rc = _UDFAllocMem(args, &obuf, 4000))
		return rc;
	dvec2jvec(args[0].u.xval, dimension, obuf);
	
	args[0].type = CHAR_TYP;
	args[0].len = strlen(obuf);
	args[0].u.xval = obuf;
	
	return _RetVal(args, args[0]);
}

/*
CREATE FUNCTION dfaceudf.JVECTODVEC(char(4000), integer) RETURNS binary(2048);
	IN:  jvec char(4000) //
	IN:  vecLen int
	RET: dvec binary(2048) // double[]
json array to double array: convert json array: '[1, 2, 3, ...]' to double[128].
*/


#if defined(WIN32) || defined(_WIN64)
_declspec(dllexport)
#endif
int  JVECTODVEC(int nArg, VAL args[])
{
	int rc = 0;
	double *dvec = NULL;
	int dimension = args[1].u.ival;
	
	if (args[0].type == NULL_TYP){
		return _RetVal(args, args[0]);
	}
	if (args[1].type == NULL_TYP){
		return _RetVal(args, args[0]);
	}
	
	if (rc = _UDFAllocMem(args, &dvec, dimension*sizeof(double)))
		return rc;
	
	jvec2dvec(args[0].u.xval, args[1].u.ival, dvec);
		
	args[0].type = BIN_TYP;
	args[0].len = dimension*sizeof(double);
	args[0].u.xval = dvec;
	
	return _RetVal(args, args[0]);
}

