use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'STUDY',
	AUTOSTUDY => 1,
) ;
use Inline::Java qw(study_classes) ;



BEGIN {
	plan(tests => 2) ;
}


study_classes(['t.types']) ;

my $t = new t::types() ;
ok($t->func(), "study") ;
ok($t->hm()->get("key"), "value") ;

