use strict ;

use Test ;
use File::Spec ;
use Inline::Java ;
use Inline::Java::Portable ;
# Our default J2SK
require Inline::Java->find_default_j2sdk() ;


BEGIN {
    plan(tests => 1) ;
}


$ENV{CLASSPATH} = make_classpath(get_server_jar()) ;


my $java = File::Spec->catfile(
	Inline::Java::get_default_j2sdk(),
	'bin', 'java' . Inline::Java::portable("EXE_EXTENSION")) ;

my $cmd = Inline::Java::portable("SUB_FIX_CMD_QUOTES", "\"$java\" org.perl.inline.java.InlineJavaPerlInterpreter") ;

print STDERR "Running '$cmd'\n" ;
print `$cmd` ;
