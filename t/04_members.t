use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 8) ;
}


my $o1 = new obj_test() ;
ok($o1->{i}, 7) ;
ok($o1->{s}, "data") ;
my $om = $o1->{om} ;
ok($om->getl(), 67) ;
ok($om->{string}, "blablabla") ;

$o1->{i} = 5 ;
$o1->{s} = 5 ;
$om->{string} = "yoyo" ;

ok($o1->{i}, 5) ;
ok($o1->{s}, "5") ;
ok($om->{string}, "yoyo") ;

my $o2 = new obj_member(123456) ;
$o1->{om} = $o2 ;
$om = $o1->{om} ;
ok($om->getl(), 123456) ;



__END__

__Java__

import java.util.* ;


class obj_test {
	public int i = 7 ;
	public String s = "data" ;
	public obj_member om = new obj_member(67) ;

	public obj_test(){
	}
}


class obj_member {
	long l ;
	public String string = "blablabla" ;

	public obj_member(long a){
		l = a ;
	}

	public long getl(){
		return l ;
	}
}
