package Inline::Java::JNI ;
@Inline::Java::JNI::ISA = qw(DynaLoader) ;


use strict ;

$Inline::Java::JNI::VERSION = '0.10' ;

require DynaLoader ;
Inline::Java::JNI->bootstrap($Inline::Java::JNI::VERSION) ;
