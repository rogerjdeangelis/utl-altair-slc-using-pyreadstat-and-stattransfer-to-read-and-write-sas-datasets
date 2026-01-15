%let pgm=utl-altair-slc-using-pyreadstat-and-stattransfer-to-read-and-write-sas-datasets;

%stop_submission;

Altair slc using pyreadstat and stattransfer to read and write sas datasets

Too long to post here, see github

github
https://github.com/rogerjdeangelis/utl-altair-slc-using-pyreadstat-and-stattransfer-to-read-and-write-sas-datasets


CONTENTS

  1. input sas dataset
  2. stattransfer function (create sas dataset)
  3. process subset zipcode (sqlite select from zipcode where)
  4. output subsetted sas dataset
  5. log
  6. slc_pybegin macro
  7. slc_pyend macro


This post supports reading and writing sas datasets,
without proc python in sas or in the altair slc.
It also has the ability to do the reads and writes inside python.

You do need to purchase, stattransfer, to create sas datasets.

The solution uses macro sandwiches to execute python;

/*   _                   _                        _       _                 _
/ | (_)_ __  _ __  _   _| |_   ___  __ _ ___   __| | __ _| |_ __ _ ___  ___| |_
| | | | `_ \| `_ \| | | | __| / __|/ _` / __| / _` |/ _` | __/ _` / __|/ _ \ __|
| | | | | | | |_) | |_| | |_  \__ \ (_| \__ \| (_| | (_| | || (_| \__ \  __/ |_
|_| |_|_| |_| .__/ \__,_|\__| |___/\__,_|___/ \__,_|\__,_|\__\__,_|___/\___|\__|
            |_|
*/

This solution requires

  c:/temp    for temporary files
  c:/wpsoto  for the stattransfer function

/*--- autoexex has libname workx "d:/wpswrkx" ; ---*/
proc datasets lib=workx kill;
run;quit;

data workx.zipcode;
  set sashelp.zipcode(obs=10 keep= zip x y statename);
run;quit;

/*---
WORKX.ZIPCODE total obs=10

Obs    ZIP        X          Y        STATENAME

  1    501    -73.0464    40.8131    New York
  2    544    -73.0493    40.8132    New York
  3    601    -66.7236    18.1660    Puerto Rico
  4    602    -67.1866    18.3830    Puerto Rico
  5    603    -67.1520    18.4332    Puerto Rico
  6    604    -67.1359    18.5053    Puerto Rico
  7    605    -67.1513    18.4361    Puerto Rico
  8    606    -66.9774    18.1856    Puerto Rico
  9    610    -67.1442    18.2859    Puerto Rico
 10    611    -66.7976    18.2877    Puerto Rico
---*/

/*___        _        _   _                        __             __                  _   _
|___ \   ___| |_ __ _| |_| |_ _ __ __ _ _ __  ___ / _| ___ _ __  / _|_   _ _ __   ___| |_(_) ___  _ __
  __) | / __| __/ _` | __| __| `__/ _` | `_ \/ __| |_ / _ \ `__|| |_| | | | `_ \ / __| __| |/ _ \| `_ \
 / __/  \__ \ || (_| | |_| |_| | | (_| | | | \__ \  _|  __/ |   |  _| |_| | | | | (__| |_| | (_) | | | |
|_____| |___/\__\__,_|\__|\__|_|  \__,_|_| |_|___/_|  \___|_|   |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|

save the python function in c:/wpsoto/fn_python.py. Ypu on;y need to do this omce
*/

%utlfkil(c:/oto/fn_python.py); /*--- delete fn_python.py ---*/

data _null_;
  file "c:/wpsoto/fn_python.py";
  input;
  put _infile_;
cards4;
import pyarrow.feather as feather
import tempfile
import pyperclip
import os
import sys
import subprocess
import time
import pandas as pd
import pyreadstat as ps
import numpy as np
from pandasql import sqldf
mysql = lambda q: sqldf(q, globals())
from pandasql import PandaSQL
pdsql = PandaSQL(persist=True)
sqlite3conn = next(pdsql.conn.gen).connection.connection
sqlite3conn.enable_load_extension(True)
sqlite3conn.load_extension('c:/temp/libsqlitefunctions.dll')
mysql = lambda q: sqldf(q, globals())

def fn_tosas9x(df,outlib="d:/sd1/",outdsn="txm",timeest=3):
    pthsd1  = outlib + outdsn + ".sas7bdat"
    fthout  = outlib + outdsn + ".feather"
    statcmd = outlib + "statcmd.stcmd"
    if os.path.exists(pthsd1):
       os.remove(pthsd1)
    if os.path.exists(fthout):
       os.remove(fthout)
    if os.path.exists(statcmd):
       os.remove(statcmd)
    feather.write_feather(df,fthout,version=1)
    f = open(statcmd, "a")
    f.writelines([
     "set numeric-names        n                "
    ,"\nset log-level          e                "
    ,"\nset in-encoding        system           "
    ,"\nset out-encoding       system           "
    ,"\nset enc-errors         sub              "
    ,"\nset enc-sub-char       _                "
    ,"\nset enc-error-limit    100              "
    ,"\nset var-case-ci        preserve-always  "
    ,"\nset preserve-label-sets y               "
    ,"\nset preserve-str-widths n               "
    ,"\nset preserve-num-widths n               "
    ,"\nset recs-to-optimize   all              "
    ,"\nset map-miss-with-labs n                "
    ,"\nset user-miss          all              "
    ,"\nset map-user-miss      n                "
    ,"\nset sas-date-fmt       mmddyy           "
    ,"\nset sas-time-fmt       time             "
    ,"\nset sas-datetime-fmt   datetime         "
    ,"\nset write-file-label   none             "
    ,"\nset write-sas-fmts     n                "
    ,"\nset sas-outrep         windows_64       "
    ,"\nset write-old-ver      1                "
    ,"\ncopy " + fthout + " sas9 " + pthsd1 ])
    f.close()
    cmds="c:/PROGRA~1/StatTransfer17-64/st.exe " + outlib + "statcmd.stcmd"
    devnull = open('NUL', 'w');
    rc = subprocess.Popen(cmds, stdout=devnull, stderr=devnull)
    time.sleep(timeest)
    os.system(f"taskkill /f /im {'st.exe'}")
;;;;
run;quit;

/*____                                                 _              _        _                     _
|___ /   _ __  _ __ ___   ___ ___  ___ ___   ___ _   _| |__  ___  ___| |_  ___(_)_ __   ___ ___   __| | ___
  |_ \  | `_ \| `__/ _ \ / __/ _ \/ __/ __| / __| | | | `_ \/ __|/ _ \ __||_  / | `_ \ / __/ _ \ / _` |/ _ \
 ___) | | |_) | | | (_) | (_|  __/\__ \__ \ \__ \ |_| | |_) \__ \  __/ |_  / /| | |_) | (_| (_) | (_| |  __/
|____/  | .__/|_|  \___/ \___\___||___/___/ |___/\__,_|_.__/|___/\___|\__|/___|_| .__/ \___\___/ \__,_|\___|
        |_|                                                                     |_|
*/

%slc_pybegin;
cards4;
exec(open('c:/wpsoto/fn_python.py').read())
zip,meta = ps.read_sas7bdat('d:/wpswrkx/zipcode.sas7bdat')
print(zip)
want=pdsql('''
  select
     *
  from
     zip
  where
     statename = "New York"
  order
     by zip
   ''')
print(want)
fn_tosas9x(
    want,
    outlib='d:/wpswrkx/',
    outdsn='pywant',timeest=3)
;;;;
%slc_pyend;


proc print data=workx.pywant;
run;quit;

/*  _                 _               _
| || |     ___  _   _| |_ _ __  _   _| |_
| || |_   / _ \| | | | __| `_ \| | | | __|
|__   _| | (_) | |_| | |_| |_) | |_| | |_
   |_|    \___/ \__,_|\__| .__/ \__,_|\__|
                         |_|

Altair SLC
LIST: 13:57:45

Altair SLC Python

SUCCESS: The process "st.exe" with PID 4056 has been terminated.
     ZIP          X          Y    STATENAME
0  501.0 -73.046388  40.813078     New York
1  544.0 -73.049288  40.813223     New York
2  601.0 -66.723627  18.165950  Puerto Rico
3  602.0 -67.186553  18.383005  Puerto Rico
4  603.0 -67.151954  18.433236  Puerto Rico
5  604.0 -67.135899  18.505289  Puerto Rico
6  605.0 -67.151346  18.436149  Puerto Rico
7  606.0 -66.977377  18.185616  Puerto Rico
8  610.0 -67.144161  18.285948  Puerto Rico
9  611.0 -66.797578  18.287716  Puerto Rico

     ZIP          X          Y STATENAME
0  501.0 -73.046388  40.813078  New York
1  544.0 -73.049288  40.813223  New York


Altair SLC (BACK TO THE SLC FROM PYTHON)

Obs    ZIP       X           Y       STATENAME

 1     501    -73.0464    40.8131    New York
 2     544    -73.0493    40.8132    New York
---*/

/*___    _
| ___|  | | ___   __ _
|___ \  | |/ _ \ / _` |
 ___) | | | (_) | (_| |
|____/  |_|\___/ \__, |
                 |___/
*/

1                                          Altair SLC      13:57 Thursday, January 15, 2026

NOTE: Copyright 2002-2025 World Programming, an Altair Company
NOTE: Altair SLC 2026 (05.26.01.00.000758)
      Licensed to Roger DeAngelis
NOTE: This session is executing on the X64_WIN11PRO platform and is running in 64 bit mode

NOTE: AUTOEXEC processing beginning; file is C:\wpsoto\autoexec.sas
NOTE: AUTOEXEC source line
1       +  ï»¿ods _all_ close;
           ^
ERROR: Expected a statement keyword : found "?"
NOTE: Library workx assigned as follows:
      Engine:        SAS7BDAT
      Physical Name: d:\wpswrkx

NOTE: Library slchelp assigned as follows:
      Engine:        WPD
      Physical Name: C:\Progra~1\Altair\SLC\2026\sashelp


LOG:  13:57:45
NOTE: 1 record was written to file PRINT

NOTE: The data step took :
      real time : 0.025
      cpu time  : 0.015


NOTE: AUTOEXEC processing completed

1         %slc_pybegin;
The file c:/temp/py_pgm.py does not exist
2         cards4;

NOTE: The file 'c:\temp\py_pgmx.py' is:
      Filename='c:\temp\py_pgmx.py',
      Owner Name=SLC\suzie,
      File size (bytes)=0,
      Create Time=12:21:25 Jan 12 2026,
      Last Accessed=13:57:44 Jan 15 2026,
      Last Modified=13:57:44 Jan 15 2026,
      Lrecl=32767, Recfm=V

NOTE: 18 records were written to file 'c:\temp\py_pgmx.py'
      The minimum record length was 80
      The maximum record length was 80
NOTE: The data step took :
      real time : 0.002
      cpu time  : 0.000


3         exec(open('c:/wpsoto/fn_python.py').read())
4         zip,meta = ps.read_sas7bdat('d:/wpswrkx/zipcode.sas7bdat')
5         print(zip)
6         want=pdsql('''
7           select
8              *
9           from
10             zip
11          where
12             statename = "New York"
13          order
14             by zip
15           ''')

2                                                                                                                         Altair SLC

16        print(want)
17        fn_tosas9x(
18            want,
19            outlib='d:/wpswrkx/',
20            outdsn='pywant',timeest=3)
21        ;;;;
22        %slc_pyend;

NOTE: The infile 'c:\temp\py_pgmx.py' is:
      Filename='c:\temp\py_pgmx.py',
      Owner Name=SLC\suzie,
      File size (bytes)=1476,
      Create Time=12:21:25 Jan 12 2026,
      Last Accessed=13:57:44 Jan 15 2026,
      Last Modified=13:57:44 Jan 15 2026,
      Lrecl=32767, Recfm=V

NOTE: The file 'c:\temp\py_pgm.py' is:
      Filename='c:\temp\py_pgm.py',
      Owner Name=SLC\suzie,
      File size (bytes)=0,
      Create Time=13:56:31 Jan 15 2026,
      Last Accessed=13:57:44 Jan 15 2026,
      Last Modified=13:57:44 Jan 15 2026,
      Lrecl=32767, Recfm=V

exec(open('c:/wpsoto/fn_python.py').read())
zip,meta = ps.read_sas7bdat('d:/wpswrkx/zipcode.sas7bdat')
print(zip)
want=pdsql('''
  select
     *
  from
     zip
  where
     statename = "New York"
  order
     by zip
   ''')
print(want)
fn_tosas9x(
    want,
    outlib='d:/wpswrkx/',
    outdsn='pywant',timeest=3)
NOTE: 18 records were read from file 'c:\temp\py_pgmx.py'
      The minimum record length was 80
      The maximum record length was 80
NOTE: 18 records were written to file 'c:\temp\py_pgm.py'
      The minimum record length was 80
      The maximum record length was 80
NOTE: The data step took :
      real time : 0.002
      cpu time  : 0.000



NOTE: The infile rut is:
      Unnamed Pipe Access Device,
      Process=d:\Py314\python.exe c:/temp/py_pgm.py 2> c:/temp/py_pgm.log,
      Lrecl=32767, Recfm=V

SUCCESS: The process "st.exe" with PID 4056 has been terminated.
     ZIP          X          Y    STATENAME

3                                                                                                                         Altair SLC

0  501.0 -73.046388  40.813078     New York
1  544.0 -73.049288  40.813223     New York
2  601.0 -66.723627  18.165950  Puerto Rico
3  602.0 -67.186553  18.383005  Puerto Rico
4  603.0 -67.151954  18.433236  Puerto Rico
5  604.0 -67.135899  18.505289  Puerto Rico
6  605.0 -67.151346  18.436149  Puerto Rico
7  606.0 -66.977377  18.185616  Puerto Rico
8  610.0 -67.144161  18.285948  Puerto Rico
9  611.0 -66.797578  18.287716  Puerto Rico
     ZIP          X          Y STATENAME
0  501.0 -73.046388  40.813078  New York
1  544.0 -73.049288  40.813223  New York
NOTE: 15 records were written to file PRINT

NOTE: 15 records were read from file rut
      The minimum record length was 40
      The maximum record length was 64
NOTE: The data step took :
      real time : 4.934
      cpu time  : 0.031



NOTE: The infile 'c:\temp\py_pgm.log' is:
      Filename='c:\temp\py_pgm.log',
      Owner Name=SLC\suzie,
      File size (bytes)=148,
      Create Time=12:49:12 Jan 15 2026,
      Last Accessed=13:57:46 Jan 15 2026,
      Last Modified=13:57:46 Jan 15 2026,
      Lrecl=32767, Recfm=V

<string>:15: SADeprecationWarning: The _ConnectionFairy.connection attribute is deprecated; please use 'driver_connection' (deprecated since: 2.0)
NOTE: 1 record was read from file 'c:\temp\py_pgm.log'
      The minimum record length was 146
      The maximum record length was 146
NOTE: The data step took :
      real time : 0.000
      cpu time  : 0.000


23
24
25        proc print data=workx.pywant;
26        run;quit;
NOTE: 2 observations were read from "WORKX.pywant"
NOTE: Procedure print step took :
      real time : 0.015
      cpu time  : 0.015


27
28
ERROR: Error printed on page 1

NOTE: Submitted statements took :
      real time : 5.111
      cpu time  : 0.109

/*__         _                    _                _
 / /_    ___| | ___   _ __  _   _| |__   ___  __ _(_)_ __   _ __ ___   __ _  ___ _ __ ___
| `_ \  / __| |/ __| | `_ \| | | | `_ \ / _ \/ _` | | `_ \ | `_ ` _ \ / _` |/ __| `__/ _ \
| (_) | \__ \ | (__  | |_) | |_| | |_) |  __/ (_| | | | | || | | | | | (_| | (__| | | (_) |
 \___/  |___/_|\___|_| .__/ \__, |_.__/ \___|\__, |_|_| |_||_| |_| |_|\__,_|\___|_|  \___/
                  |__|_|    |___/            |___/

%macro slc_pybegin;
  %utlfkil(c:/temp/py_pgm.py);
  %utlfkil(c:/temp/py_pgm.log);
  data _null_;
    file "c:/temp/py_pgmx.py";
    input;put _infile_;
%mend slc_pybegin;

/*____       _                                   _
|___  |  ___| | ___   _ __  _   _  ___ _ __   __| | _ __ ___   __ _  ___ _ __ ___
   / /  / __| |/ __| | `_ \| | | |/ _ \ `_ \ / _` || `_ ` _ \ / _` |/ __| `__/ _ \
  / /   \__ \ | (__  | |_) | |_| |  __/ | | | (_| || | | | | | (_| | (__| | | (_) |
 /_/    |___/_|\___|_| .__/ \__, |\___|_| |_|\__,_||_| |_| |_|\__,_|\___|_|  \___/
                  |__|_|    |___/
*/

%macro slc_pyend(return=,resolve=N);
run;quit;
data _null_;
  infile "c:/temp/py_pgmx.py";
  input;
  file "c:/temp/py_pgm.py";
  if upcase(substr("&resolve",1,1))="Y" then
     _infile_=resolve(_infile_);
  put _infile_;
  putlog _infile_;
run;quit;
* EXECUTE THE PYTHON PROGRAM;
options noxwait noxsync;
filename rut pipe  "d:\Py314\python.exe c:/temp/py_pgm.py 2> c:/temp/py_pgm.log";
run;quit;
data _null_;
  file print;
  infile rut;
  input;
  put _infile_;
  putlog _infile_;
run;quit;
data _null_;
  infile "c:/temp/py_pgm.log";
  input;
  putlog _infile_;
run;quit;
%if "&return" ne ""  %then %do;
  filename clp clipbrd ;
  data _null_;
   infile clp;
   input;
   putlog "xxxxxx  " _infile_;
   call symputx("&return.",_infile_,"G");
  run;quit;
  %end;
%mend slc_pyend;

/*              _
  ___ _ __   __| |
 / _ \ `_ \ / _` |
|  __/ | | | (_| |
 \___|_| |_|\__,_|

*/
