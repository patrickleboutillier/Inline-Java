use strict ;
use Test ;

BEGIN {
	plan(tests => 1) ;
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test' ;
}

use Inline Config => 
           DIRECTORY => './_Inline_test' ;

use Inline (
	Java => 'DATA'
) ;

my $mod = (Inline::Java::get_INLINE_modules())[0] ;
my $ij = Inline::Java::get_INLINE($mod) ;
my $jdk = $ij->get_java_config("J2SDK") ;
my $ver = types1->version() ;
print STDERR "\nInline version is $Inline::VERSION\n" ;
print STDERR "Inline::Java version is $Inline::Java::VERSION\n" ;
print STDERR "J2SDK version is $ver, from $jdk\n" ;

if ($ENV{PERL_INLINE_JAVA_EMBEDDED_JNI}){
	print STDERR "Using JNI extension (embedded).\n" ;
}
elsif ($ENV{PERL_INLINE_JAVA_JNI}){
	print STDERR "Using JNI extension.\n" ;
}

ok(1) ;



__END__

__Java__

class types1 {
	static public String version(){
		return System.getProperty("java.version") ;
	}
}



