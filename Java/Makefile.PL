use ExtUtils::MakeMaker ;
use File::Find ;

use strict ;

# Define these variables with the correct values to bypass the
# rest of the code that looks for them.
my $java_include = 		undef ;
my $java_include_os = 	undef ;
my $java_lib = 			undef ;
my $java_so = 			undef ;

my $jvm_lib = ($^O eq "MSWin32" ? "jvm.lib" : "libjvm.so") ;
my $jvm_so =  ($^O eq "MSWin32" ? "jvm.dll" : "libjvm.so") ;


my $q = "\nInline::Java has an optional JNI extension (see README for more " .
	"information).\nDo you want to build the JNI extension" ;

my $jni = AskYN($q) ;

if ($jni){
	if ((! defined($java_include))&&
		(! defined($java_include_os))&&
		(! defined($java_lib))&&
		(! defined($java_so))){
		# We need to find the files in order to be able to build
		$q = "\nWhat is the path to your Java installation" ;
		my $jh = Ask($q) ;
		chomp($jh) ;
		if (! -d $jh){
			die("Directory $jh does not exist.") ;
		}
		print "\n" ;
		find(\&wanted, $jh) ;

		if (! defined($java_include)){
			die("Couldn't find jni.h.") ;
		}
		if (! defined($java_include_os)){
			die("Couldn't find jni_md.h.") ;
		}
		if (! defined($java_lib)){
			die("Couldn't find $jvm_lib.") ;
		}
		if (! defined($java_so)){
			die("Couldn't find $jvm_so.") ;
		}
	}
	
	if ($^O eq "MSWin32"){
		my $l = join(" or ", @{$java_so}) ;
		print "\nNote: You will need to add $l to your PATH environment " .
			"variable in order to be able to use the JNI mode.\n" ;
	}

	print "\n" ;
	
}
else{
	# We need to rename the JNI.xs file so that the extension is not built
	rename("JNI.xs", "JNI.xs_") ;	
}


my %h = (
	NAME => 'Inline::Java::JNI',
	VERSION_FROM => 'JNI.pm',
) ;

if ($jni){
	$h{INC} = join(" ", 
		"-I$java_include",
		"-I$java_include_os"
	) ;
	$h{LIBS} = [
		"-L$java_lib -ljvm"
	] ;
}

ExtUtils::MakeMaker::WriteMakefile(%h) ;


# Restore the JNI.xs file
rename("JNI.xs_", "JNI.xs") ;


#################################################


sub wanted {
	my $file = $_ ;

	if ($file eq "jni.h"){
		print "Found jni.h in $File::Find::dir...\n" ;
		$java_include = $File::Find::dir ;
	}
	if ($file eq "jni_md.h"){
		print "Found jni_md.h in $File::Find::dir...\n" ;
		$java_include_os = $File::Find::dir ;
	}
	if ($file eq $jvm_lib){
		print "Found $jvm_lib in $File::Find::dir...\n" ;
		$java_lib = $File::Find::dir ;
	}
	if ($file eq $jvm_so){
		print "Found $jvm_so in $File::Find::dir...\n" ;
		if (! defined($java_so)){
			$java_so = [] ;
		}
		push @{$java_so}, $File::Find::dir ;
	}
}


# Gets yes/no from stdin
sub AskYN {
	my $ques = shift ;

	my $str = $ques . " [yn]: " ;
	print($str) ;

	my $ans = '' ;
	while (<STDIN>){
		$ans = $_ ;
		chomp($ans) ;
		if ($ans =~ /^(y|n)$/i){
			last ;
		}
		else{
			print($str) ;
		}
	}

	if ($ans eq "y"){
		return 1 ;
	}
	else{
		return 0 ;
	}
}


# Gets string from stdin
sub Ask {
	my $ques = shift ;

	my $str = $ques . " : " ;
	print($str) ;
	my $ans = '' ;
	$ans = <STDIN> ;

	return $ans ;
}

