#! /bin/bash

export LD_LIBRARY_PATH=`pwd`/src/jni

/usr/java/j2sdk1.4.2_02/bin/java -cp ./dist/lib/PerlInterpreter.jar org.perl.PerlInterpreter
