use strict ;

use blib ;


BEGIN {
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test';
}

use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => qq|
		class t  {
			public static int s = 0 ;

			public t(){
			}
		}
	|, 
	PRINT_INFO => 1,
) ;

Inline::Java::release_JVM() ;

my $t = new t() ;
$t::s++ ;
$t::s++ ;
print $t::s . "\n" ;




