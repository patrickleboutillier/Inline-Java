use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 14) ;
}


my $o1 = new object() ;
my $o2 = new object() ;
ok($o1->get_data(), "data") ;
ok($o2->get_data(), "data") ;
ok($o1->get_this()->get_data(), "data") ;
ok($o1->get_that($o2)->get_data(), "data") ;

$o1->set_data("new data") ;
ok($o1->get_data(), "new data") ;
ok($o2->get_data(), "new data") ;

object->set_data("new new data") ;
ok($o1->get_data(), "new new data") ;
ok($o2->get_data(), "new new data") ;

my $so1 = new sub_object(5) ;
my $so2 = new sub_object(6) ;
ok($so1->get_data(), "new new data") ;
ok($so1->get_number(), 5) ;
ok($so2->get_number(), 6) ;

$so1->set_number(7) ;
ok($so1->get_number(), 7) ;

my $io = new object::inner_object($o1) ;
ok($io->get_data(), "new new data") ;

my $al = $o1->new_arraylist() ;
$o1->set_arraylist($al, "array data") ;
ok($o1->get_arraylist($al), "array data") ;


__END__

__Java__

import java.util.* ;


class object {
	public static String data = "data" ;

	public object(){
	}

	public object get_this(){
		return this ;
	}

	public object get_that(object o){
		return o ;
	}

	public static String get_data(){
		return data ;
	}

	public static void set_data(String d){
		data = d ;
	}
	
	public ArrayList new_arraylist(){
		return new ArrayList() ;
	}

	public void set_arraylist(ArrayList a, String s){
		a.add(0, s) ;
	}

	public String get_arraylist(ArrayList a){
		return (String)a.get(0) ;
	}

	
	class inner_object {
		public inner_object(){
		}

		public String get_data(){
			return object.this.get_data() ;
		}
	}
}


class sub_object extends object {
	public int number ;

	public sub_object(int num){
		super() ;
		number = num ;
	}

	public int get_number(){
		return number ;
	}

	public void set_number(int num){
		number = num ;
	}
}
