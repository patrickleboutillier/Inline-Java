#! /bin/bash

export LD_LIBRARY_PATH=`pwd`/src/jni

java -cp ./dist/lib/PerlInterpreter.jar:/home/dougm/covalent/eam/PerlInterpreter/inline/lib/auto/MyStuff org.perl.PerlInterpreter
