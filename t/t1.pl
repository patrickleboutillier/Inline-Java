#!/home/patrickl/bin/perl56

use strict ;

use lib "/home/patrickl/perl/dev" ;
use lib "/home/patrickl/perl/dev/Inline/blib/arch/auto/Inline/Java/JNI" ;


BEGIN {
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test';
}

use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => qq|
		class t  {
			static int s = 0 ;

			public t(){
			}
		}
	|, 
) ;

my $t = new t() ;
$t::s++ ;
$t::s++ ;
print $t::s . "\n" ;




