use strict ;
use Test ;


BEGIN {
	if ($ENV{PERL_INLINE_JAVA_JNI}){
		plan(tests => 0) ;
		exit ;
	}
	else{
		plan(tests => 3) ;
	}
}


use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 'DATA',
	SHARED_JVM => 1,
) ;


my $t = new t9() ;

{
	ok($t->{i}, 5) ;
	ok(Inline::Java::i_am_JVM_owner()) ;
}

ok($t->__get_private()->{proto}->ObjectCount(), 1) ;


__END__

__Java__

class t9 {
	static public int i = 5 ;

	public t9(){
	}
}


