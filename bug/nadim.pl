#!/usr/bin/perl

package PBS ;
use Data::Dumper ;

sub GetConfig {
	print "do GetConfig(@_)\n" ;
	return 1 ;
}

sub AddRule {
	print "do AddRule( " . Dumper(\@_) . ")\n" ;
}


package PBS::Java ;

my $java_code = <<JC ;
	if (GetConfig("EXTRA_OBJECT_FILES")){
		AddRule("extra_object_file", new String [] {"*.lib", "d"}, null);
		AddRule("d", new String [] {"d"}, "some_command") ;
	}

	AddRule("dep1", new String [] {"a", "a.dep"}, "a_second_command") ;
	AddRule("dep2", new String [] {"b", "a.dep"}, "another_command") ;
JC

use Inline ;
Inline->bind(
	Java => <<JAVA,
import org.perl.inline.java.* ;

class PBS_Java_12345 extends InlineJavaPerlCaller {
	public PBS_Java_12345() throws InlineJavaException {
	}

	private boolean GetConfig(String k) throws InlineJavaException, InlineJavaPerlException {
		Boolean b = (Boolean)CallPerlSub("PBS::GetConfig", new Object [] {k}, Boolean.class) ;
		return b.booleanValue() ;
	}

	private void AddRule(String d, String r[], String cmd) throws InlineJavaException, InlineJavaPerlException {
		CallPerlSub("PBS::AddRule", new Object [] {d, r, cmd}) ;
	}

	public void run() throws InlineJavaException, InlineJavaPerlException {
		$java_code ;
	}
}
JAVA
) ;

my $o = new PBS::Java::PBS_Java_12345() ;
$o->run() ;
