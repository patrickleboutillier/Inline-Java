use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 'DATA',
	SHARED_JVM => 1,
) ;


my $JNI = Inline::Java::__get_JVM()->{JNI} ;
plan(tests => ($JNI ? 1 : 3)) ;


if ($JNI){
	skip("JNI", 1) ;
	Inline::Java::shutdown_JVM() ;
	exit ;
}


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


