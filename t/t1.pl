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
			public java.util.ArrayList al [] = new java.util.ArrayList[5] ;

			public t(){
				al[0] = new java.util.ArrayList() ;
			}
		}
	|, 
	# PRINT_INFO => 1,
	STUDY => ['java.util.ArrayList'],
) ;

Inline::Java::release_JVM() ;

my $t = new t() ;
$t->{al}->[0]->add("allo") ;
print $t->{al}->[0]->get(0) . "\n" ;


