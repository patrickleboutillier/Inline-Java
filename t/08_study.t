use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'STUDY',
	AUTOSTUDY => 1,
) ;



BEGIN {
	plan(tests => 2) ;
}


Inline::Java::study_it(['t.types']) ;

my $t = new t::types() ;
ok($t->func(), "study") ;
ok($t->hm()->get("key"), "value") ;

