use strict ;
use Test ;

use Inline Config =>
           DIRECTORY => './_Inline_test';

use Inline (
	Java => 'DATA',
) ;

use Inline::Java qw(caught) ;


BEGIN {
	my $cnt = 1 ;
	if (! $ENV{PERL_INLINE_JAVA_JNI}){
		$cnt = 0 ;
	}
	plan(tests => $cnt) ;
}

eval {
	t121->init() ;
	my $t = new t121() ;
	print $t->yo("!!!!!") . "\n" ;

	my $t2 = new t1212() ;
	print $t2->yo("!!!!!") . "\n" ;

	ok($t->__get_private()->{proto}->ObjectCount(), 2) ;
} ;
if ($@){
	if (caught("java.lang.Throwable")){
		$@->printStackTrace() ;
		die("Caught Java Exception") ;
	}
	else{
		die $@ ;
	}
}


##################################


sub t121::perl::yo {
	my $this = shift ;
	my $s = shift ;
	print "$s\n" ;

	$this->pub_hello() ;

	return $s ;
}


sub t121::perl::hello {
	my $this = shift ;

	print "HELLO\n" ;
}


__END__

__Java__


import java.io.* ;
import org.perl.inline.java.* ;

class t121 extends InlineJavaPerlNatives {

	public t121() throws InlineJavaException {
	}

	static public void init() throws InlineJavaException {
		init("test") ;
	}

	public native String yo(String s) ;

	public void pub_hello(){
		hello();
	}

	protected native void hello() ;
} ;


class t1212 extends t121 {
	public t1212() throws InlineJavaException {
	}
} ;
