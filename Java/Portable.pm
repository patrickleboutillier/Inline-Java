package Inline::Java::Portable ;
@Inline::Java::Portable::ISA = qw(Exporter) ;

@EXPORT = qw(portable) ;


use strict ;

$Inline::Java::Portable::VERSION = '0.31' ;


use Exporter ;
use Carp ;
use Config ;

# Here is some code to figure out if we are running on command.com
# shell under Windows.
my $COMMAND_COM =
	(
		($^O eq 'MSWin32')&&
		(
			($ENV{PERL_INLINE_JAVA_COMMAND_COM})||
			(
				(defined($ENV{COMSPEC}))&&
				($ENV{COMSPEC} =~ /(command|4dos)\.com/i)
			)||
			(`ver` =~ /win(dows )?((9[58])|(m[ei]))/i)
		)
	) || 0 ;


# Used when this module is used by itself, this stubs the requirements
sub use_alone {
	*Inline::Java::debug = sub {} ;
}


sub portable {
	my $key = shift ;
	my $val = shift ;

	my $defmap = {
		EXE_EXTENSION		=>	$Config{exe_ext},
		GOT_ALARM			=>  $Config{d_alarm},
		GOT_FORK			=>	$Config{d_fork},
		ENV_VAR_PATH_SEP	=>	$Config{path_sep},
		SO_EXT				=>	$Config{dlext},
		SO_LIB_PATH_VAR		=>	'LD_LIBRARY_PATH',
		ENV_VAR_PATH_SEP_CP	=>	':',
		IO_REDIR			=>  '2>&1',
		COMMAND_COM			=>  0,
		SUB_FIX_CLASSPATH	=>	undef,
		JVM_LIB				=>	'libjvm.so',
		JVM_SO				=>	'libjvm.so',
	} ;

	my $map = {
		MSWin32 => {
			ENV_VAR_PATH_SEP_CP	=>	';',
			# 2>&1 doesn't work under command.com
			IO_REDIR			=>  ($COMMAND_COM ? '' : undef),
			COMMAND_COM			=>	$COMMAND_COM,
			SO_LIB_PATH_VAR		=>	'PATH',
			JVM_LIB				=>	'jvm.lib',
			JVM_SO				=>	'jvm.dll',
		},
		cygwin => {
			ENV_VAR_PATH_SEP_CP	=>	';',
			SUB_FIX_CLASSPATH	=>	sub {
				my $val = shift ;
				if (defined($val)&&($val)){
					$val = `cygpath -w \"$val\"` ;
					chomp($val) ;
				}
				return $val ;
			},
			JVM_LIB				=>	'jvm.lib',
			JVM_SO				=>	'jvm.dll',
		},
	} ;

	if (! exists($defmap->{$key})){
		croak "Portability issue $key not defined!" ;
	}

	if ((defined($map->{$^O}))&&(defined($map->{$^O}->{$key}))){
		if ($key =~ /^RE_/){
			if (defined($val)){
				my $f = $map->{$^O}->{$key}->[0] ;
				my $t = $map->{$^O}->{$key}->[1] ;
				$val =~ s/$f/$t/g ;
				Inline::Java::debug("portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				Inline::Java::debug("portable: $key for $^O is 'undef'") ;
				return undef ;
			}
		}
		elsif ($key =~ /^SUB_/){
			my $sub = $map->{$^O}->{$key} ;
			if (defined($sub)){
				$val = $sub->($val) ;
				Inline::Java::debug("portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				return $val ;
			}
		}
		else{
			Inline::Java::debug("portable: $key for $^O is '$map->{$^O}->{$key}'") ;
			return $map->{$^O}->{$key} ;
		}
	}
	else{
		if ($key =~ /^RE_/){
			Inline::Java::debug("portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		if ($key =~ /^SUB_/){
			Inline::Java::debug("portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		else{
			Inline::Java::debug("portable: $key for $^O is default '$defmap->{$key}'") ;
			return $defmap->{$key} ;
		}
	}
}


1 ;




