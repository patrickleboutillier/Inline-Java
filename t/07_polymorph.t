use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 2) ;
}


ok(types->get("key"), undef) ;
my $t = new types() ;
ok(types->get("key"), "value") ;


__END__

__Java__


class types {
	public static int = 5 ;
	public static HashMap hm = new HashMap() ;

	public types(){
		hm.add("key", "value") ;
	}

	public static HashMap get(String k){
		return hm.get(k) ; 
	}
}

