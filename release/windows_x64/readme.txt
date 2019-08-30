
1. prepare vc 2015 runtime

dface.dll need vcruntime 140 (vs 2015 x64), download from here:

https://www.microsoft.com/en-us/download/details.aspx?id=52685

2. deploy dll

assume DB_SPDIR = DB_LBDIR = DB_DBDIR.
unzip dll.zip to DB_DBDIR.
add DBDIR to %path% env variable.

3. install dface modle files to dbmaker installation path

download modle files:
```
http://dlib.net/files/shape_predictor_5_face_landmarks.dat.bz2
http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2
http://dlib.net/files/dlib_face_recognition_resnet_model_v1.dat.bz2
```
then unzip them to DBMaker home (e.g. C:\DBMaker\5.4\)

4. config [FACEDB] in dmconfig.ini

5. create db facedb

6. run buildsp.sql in dmsql32

