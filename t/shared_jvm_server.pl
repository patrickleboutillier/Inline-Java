use strict ;

use blib ;


BEGIN {
	$ENV{CLASSPATH} .= ":[PERL_INLINE_JAVA=shared_jvm_test]" ;
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test';
}


use Inline Config => 
           DIRECTORY => './_Inline_test' ;


use Inline(
	Java => 'STUDY',
	SHARED_JVM => 1,
) ;

print "CLASSPATH should be preset for the server to work\n" ;
print "CLASSPATH = $ENV{CLASSPATH}\n" ;
print "Shared JVM server started\n" ;
while (1){
	sleep(60) ;
}
