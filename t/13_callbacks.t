use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline (
	Java => 'DATA',
	PORT => 7891,
	STARTUP_DELAY => 20,	
) ;

use Inline::Java qw(caught) ;


BEGIN {
	plan(tests => 14) ;
}

my $t = new t10() ;

{
	eval {
		ok($t->add(5, 6), 11) ;
		ok($t->add_via_perl(5, 6), 11) ;
		ok($t->mul(5, 6), 30) ;
		ok($t->mul_via_perl(5, 6), 30) ;
		ok($t->silly_mul(3, 2), 6) ;
		ok($t->silly_mul_via_perl(3, 2), 6) ;

		ok(add_via_java(3, 4), 7) ;

		ok($t->add_via_perl_via_java(3, 4), 7) ;
		ok($t->silly_mul_via_perl_via_java(10, 9), 90) ;

		ok(t10->add_via_perl_via_java_t($t, 6, 9), 15) ;

		ok($t->cat_via_perl("Inline", "Java"), "InlineJava") ;

		eval {$t->death_via_perl()} ; ok($@, qr/death/) ;

		my $msg = '' ;
		eval {$t->except()} ; 
		if ($@) {
			if (caught('InlineJavaPerlCaller$InlineJavaPerlCallerException')){
				$msg = $@->getMessage() ;
			}
			else{
				die $@ ;
			}
		}
		ok($msg, "test") ;
	
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
}

ok($t->__get_private()->{proto}->ObjectCount(), 1) ;


sub add {
	my $i = shift ;
	my $j = shift ;

	return $i + $j ;
}


sub mul {
	my $i = shift ;
	my $j = shift ;

	return $i * $j ;
}


sub cat {
	my $i = shift ;
	my $j = shift ;

	return $i . $j ;
}


sub add_via_java {
	my $i = shift ;
	my $j = shift ;

	return $t->add($i, $j) ;
}


sub add_via_java_t {
	my $_t = shift ;
	my $i = shift ;
	my $j = shift ;

	return $_t->add($i, $j) ;
}


sub death {
	die("death") ;
}


__END__

__Java__


import java.io.* ;

class t10 extends InlineJavaPerlCaller {
	public t10() {
	}

	public int add(int a, int b){
		return a + b ;
	}

	public int mul(int a, int b){
		return a * b ;
	}

	public int silly_mul(int a, int b){
		int ret = 0 ;
		for (int i = 0 ; i < b ; i++){
			ret = add(ret, a) ;
		}
		return a * b ;
	}

	public int silly_mul_via_perl(int a, int b) throws InlineJavaPerlCallerException {
		int ret = 0 ;
		for (int i = 0 ; i < b ; i++){
			ret = add_via_perl(ret, a) ;
		}
		return ret ;
	}


	public int add_via_perl(int a, int b) throws InlineJavaPerlCallerException {
		String val = (String)CallPerl("main", "add", 
			new Object [] {new Integer(a), new Integer(b)}) ;

		return new Integer(val).intValue() ;
	}

	public void death_via_perl() throws InlineJavaPerlCallerException {		
		InlineJavaPerlCaller c = new InlineJavaPerlCaller() ;
		c.CallPerl("main", "death", null) ;
	}

	public void except() throws InlineJavaPerlCallerException {		
		throw new InlineJavaPerlCaller.InlineJavaPerlCallerException("test") ;
	}

	public int mul_via_perl(int a, int b) throws InlineJavaPerlCallerException {
		String val = (String)CallPerl("main", "mul", 
			new Object [] {new Integer(a), new Integer(b)}) ;

		return new Integer(val).intValue() ;
	}

	public String cat_via_perl(String a, String b) throws InlineJavaPerlCallerException {
		String val = (String)CallPerl("main", "cat", 
			new Object [] {a, b}) ;

		return val ;
	}

	public int add_via_perl_via_java(int a, int b) throws InlineJavaPerlCallerException {
		String val = (String)CallPerl("main", "add_via_java", 
			new Object [] {new Integer(a), new Integer(b)}) ;

		return new Integer(val).intValue() ;
	}

	static public int add_via_perl_via_java_t(t10 t, int a, int b) throws InlineJavaPerlCallerException {
		InlineJavaPerlCaller c = new InlineJavaPerlCaller() ;
		String val = (String)c.CallPerl("main", "add_via_java_t", 
			new Object [] {t, new Integer(a), new Integer(b)}) ;

		return new Integer(val).intValue() ;
	}

	public int silly_mul_via_perl_via_java(int a, int b) throws InlineJavaPerlCallerException {
		int ret = 0 ;
		for (int i = 0 ; i < b ; i++){
			String val = (String)CallPerl("main", "add_via_java", 
				new Object [] {new Integer(ret), new Integer(a)}) ;
			ret = new Integer(val).intValue() ;
		}
		return ret ;
	}
}

