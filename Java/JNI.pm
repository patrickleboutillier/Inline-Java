package Inline::Java::JNI ;
@Inline::Java::JNI::ISA = qw(DynaLoader) ;


use strict ;

$Inline::Java::JNI::VERSION = '0.31' ;

use Carp ;
use File::Basename ;


# A place to attach the Inline object that is currently in Java land
$Inline::Java::JNI::INLINE_HOOK = undef ;

# The full path to the shared object loaded by JNI
$Inline::Java::JNI::SO = '' ;


eval {
	Inline::Java::JNI->bootstrap($Inline::Java::JNI::VERSION) ;
	
	if (! $Inline::Java::JNI::SO){
		croak "Can't find JNI shared object!" ;
	}

	Inline::Java::debug("JNI shared object is '$Inline::Java::JNI::SO'") ;
} ;
if ($@){
	croak "Can't load JNI module. Did you build it at install time?\nError: $@" ;
}


# This is a *NASTY* way to get the shared object file that was loaded 
# by DynaLoader
sub dl_load_flags {
	my $so = $DynaLoader::file ;
	my $dir = dirname($so) ;
	my $f = basename($so) ;
	my $sep = Inline::Java::portable("PATH_SEP") ;

	$Inline::Java::JNI::SO = Inline::Java::portable("RE_FILE", Cwd::abs_path($dir) . $sep . $f) ;
	$Inline::Java::JNI::SO = Inline::Java::portable("RE_FILE_JAVA", $Inline::Java::JNI::SO) ;

	return DynaLoader::dl_load_flags() ;
}



1 ;
