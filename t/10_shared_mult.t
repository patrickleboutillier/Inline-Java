package t10 ;

use strict ;
use Test ;


BEGIN {
	if ($ENV{PERL_INLINE_JAVA_JNI}){
		plan(tests => 0) ;
		exit ;
	}
	else{
		plan(tests => 8) ;
	}
}


use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 't/shared.java',
	SHARED_JVM => 1,
	NAME => 't10',
) ;


eval <<CODE1;
	my \$t = new t10::t10() ;
	{
		ok(\$t->{i}++, 5) ;
		ok(Inline::Java::i_am_JVM_owner()) ;
		Inline::Java::release_JVM() ;
		ok(! Inline::Java::i_am_JVM_owner()) ;
	}
CODE1
if ($@){
	die($@) ;
}

my $JVM1 = Inline::Java::__get_JVM() ;
$JVM1->{destroyed} = 1 ;
Inline::Java::__clear_JVM() ;

eval <<CODE2;
	use Inline (
		Java => 't/shared.java',
		SHARED_JVM => 1,
		NAME => 't10',
	) ;

	my \$t = new t10::t10() ;
	{
		ok(\$t->{i}++, 6) ;
		ok(! Inline::Java::i_am_JVM_owner()) ;
	}
CODE2
if ($@){
	die($@) ;
}

my $JVM2 = Inline::Java::__get_JVM() ;
$JVM2->{destroyed} = 1 ;
Inline::Java::__clear_JVM() ;

eval <<CODE3;
	use Inline (
		Java => 't/shared.java',
		SHARED_JVM => 1,
		NAME => 't10',
	) ;

	my \$t = new t10::t10() ;
	{
		ok(\$t->{i}, 7) ;
		ok(! Inline::Java::i_am_JVM_owner()) ;
		Inline::Java::capture_JVM() ;
		ok(Inline::Java::i_am_JVM_owner()) ;
	}
CODE3
if ($@){
	die($@) ;
}

