use strict ;

use blib ;
use Getopt::Long ;

BEGIN {
	mkdir('./_Inline_test', 0777) unless -e './_Inline_test';
}

use Inline Config => 
           DIRECTORY => './_Inline_test';

require Inline::Java ;
								  

my %opts = () ;
GetOptions (\%opts,
	"d",    	# debug
	"s=i",    	# skip to
	"o=i",    	# only
) ;


open(POD, "<Java.pod") or 
	die("Can't open Java.pod file") ;
my $pod = join("", <POD>) ;

my $del = "\n=for comment\n" ;

my @code_blocks = ($pod =~ m/$del(.*?)$del/gs) ;

my $ps = Inline::Java::portable("ENV_VAR_PATH_SEP_CP") ;
$ENV{CLASSPATH} .= "$ps" . "[PERL_INLINE_JAVA=Pod_Foo,Pod_Bar]" ;

my $skip_to = $opts{s} || 0 ;

my $cnt = -1 ;
foreach my $code (@code_blocks){
	$cnt++ ;

	if ((defined($opts{o}))&&($opts{o} != $cnt)){
		print "skipped\n" ;
		next ;
	}

	if ($cnt < $skip_to){
		print "skipped\n" ;
		next ;
	}

	print "-> Code Block $cnt\n" ;

	$code =~ s/(\n)(   )/$1/gs ;  
	$code =~ s/(((END(_OF_JAVA_CODE)?)|STUDY)\')/$1, NAME => "main::main" / ;  

	if (($code =~ /SHARED_JVM/)&&($opts{o} != $cnt)){
		print "skipped\n" ;
		next ;
	}

	$code =~ s/print\((.*) \. \"\\n\"\) ; # prints (.*)/{
		"print (((($1) eq ('$2')) ? \"ok\" : \"not ok ('$1' ne '$2')\") . \"\\n\") ;" ;
	}/ge ;

	debug($code) ;

	eval $code ;
	if ($@){
		die $@ ;
	}
}

close(POD) ;


sub debug {
	my $msg = shift ;
	if ($opts{d}){
		print $msg ;
	}
}

