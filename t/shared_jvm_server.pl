use strict ;

use blib ;


BEGIN {
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test';
}


use Inline Config => 
           DIRECTORY => './_Inline_test' ;


use Inline(
	Java => 'STUDY',
	SHARED_JVM => 1,
) ;

print "Shared JVM server started\n" ;
while (1){
	sleep(60) ;
}
