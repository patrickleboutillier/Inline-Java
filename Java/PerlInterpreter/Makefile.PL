use ExtUtils::MakeMaker ;

use strict ;
require "../Portable.pm" ;

my $libperl_dir = Inline::Java::Portable::portable('SUB_FIX_MAKE_QUOTES',
	"??") ;

WriteMakefile(
	NAME => 'Inline::Java::PerlInterpreter',
	VERSION_FROM => 'PerlInterpreter.pm',
	INC => join(' ', @main::I),
	LIBS => [join(' ', @main::L) . " -ljvm -L$libperl_dir -lperl"],
	# CCFLAGS => '-D_REENTRANT',
) ;

