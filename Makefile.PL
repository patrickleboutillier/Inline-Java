use ExtUtils::MakeMaker ;
# $Verbose = 2 ;

use strict ;
use File::Spec ;
use Config ;

require "Java/Portable.pm" ;

print "\nWelcome to the Inline::Java installation procedure.\n\n" ;

# Grab the J2SDK argument
my @new_args = () ;
my $jdk_dir = '' ;
foreach my $arg (@ARGV){
	if ($arg =~ /^J2SDK=(.+)$/){
		$jdk_dir = $1 ;
	}
	else {
		push @new_args, $_ ;
	}
}
@ARGV = @new_args ;

if (! $jdk_dir){
	print <<NO_J2SDK;
A Java 2 SDK is required to install and use Inline::Java. Please 
specify your Java 2 SDK installation directory using the J2SDK 
option to Makefile.PL as such:

    perl Makefile.PL J2SDK=/path/to/your/j2sdk/installation
NO_J2SDK
	exit(1) ;
}
elsif (! -d $jdk_dir){
	print <<BAD_J2SDK;
Java 2 SDK installation directory '$jdk_dir' does not exist.
BAD_J2SDK
	exit(1) ;
}
my $perl_jdk_dir = $jdk_dir ;
$perl_jdk_dir =~ s/'/\'/g ;

# Check directory
my $ext = Inline::Java::Portable::portable('EXE_EXTENSION') ;
foreach my $f ('javac', 'jar', 'java'){
	if (! -x File::Spec->catfile($jdk_dir, 'bin', $f . $ext)){
		my $bf = File::Spec->catfile('bin', $f . $ext) ;
		print "Can't locate file '$bf' anywhere under '$jdk_dir'\n" ;
	}
}


# Now we have the J2SDK directory and it exists. 
# We will create the DefaultJ2SDK.pl file that
# will contain that value for future use.
my $def_jdk = File::Spec->catfile('Java', 'DefaultJ2SDK.pl') ;
open(J2SDK, ">$def_jdk") or
	die("Can't open '$def_jdk' for writing: $!") ;
print J2SDK <<J2SDK_PL;
# This file is created by the Makefile.PL for Inline::Java
# You can modify it if you which
use strict ;

# The default J2SDK to use for Inline::Java. You can change
# it if this value becomes invalid.
sub Inline::Java::get_default_j2sdk {
	return '$perl_jdk_dir' ;
}

1 ;
J2SDK_PL
close(J2SDK) ;

my $ij_site_lib = File::Spec->catdir($Config{installsitelib}, 'Inline', 'Java') ;
print <<SAVE_J2SDK;
Default J2SDK for Inline:Java will be '$jdk_dir'.
See module documentation for information on how to use a different J2SDK
or change this default value.

SAVE_J2SDK


# We will now add the building of our Java files to the Makefile.
my $javac = File::Spec->catfile($jdk_dir, 'bin', 'javac' . $ext) ;
my $jar = File::Spec->catfile($jdk_dir, 'bin', 'jar' . $ext) ;
my $src_dir = File::Spec->catdir('Java', 'sources') ;
my $src = File::Spec->catfile($src_dir, '*.java') ;
my $obj_dir = File::Spec->catdir('Java', 'classes') ;
my $arch_dir = File::Spec->catdir('Java', 'jar') ;
my $arch = File::Spec->catfile($arch_dir, 'InlineJava.jar') ;

sub MY::postamble {
	<<MAKE;
pure_all :: java

java ::
	\@\$(MKPATH) $obj_dir
	\@\$(MKPATH) $arch_dir
	"$javac" -d $obj_dir $src
	"$jar" cf $arch -C $obj_dir .
MAKE
}


# Skip the tests for the Java directory
sub MY::test {
  my $this = shift ;

  my $hold = delete $this->{DIR} ;
  my $ret = $this->MM::test(@_) ;
  $this->{DIR} = $hold if defined($hold) ;
  return $ret ;
}


# Write the Makefile
WriteMakefile(
	NAME => 'Inline::Java',
	VERSION_FROM => 'Java.pm',
	DIR => ['Java'],
	PREREQ_PM => {
		Inline	=> 0.44
	},
	PM => {
		'Java.pm' => File::Spec->catfile('$(INST_LIBDIR)', 'Java.pm'),
		'Java.pod'=> File::Spec->catfile('$(INST_LIBDIR)', 'Java.pod'),
		$arch => File::Spec->catfile('$(INST_LIBDIR)', $arch),
	},
	clean => {FILES => "$def_jdk _Inline_test $obj_dir $arch_dir"},
) ;


# Clean up the Makefile for Win95/98/Me
if (Inline::Java::Portable::portable('COMMAND_COM')){
	print "\nFixing Makefile for Win95/98/Me...\n" ;
	open(MAKEFILE, "<Makefile") or die "Can't open Makefile for reading" ;
	my @lines = <MAKEFILE> ;
	close(MAKEFILE) ;
	open(MAKEFILE, ">Makefile") or die "Can't open Makefile for writing" ;
	foreach my $line (@lines){
		if ($line !~ /^\s*((\@\[)|(\]))\s*$/){
			print MAKEFILE $line ;
		}
	}
	close(MAKEFILE) ;
}

