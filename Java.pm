package Inline::Java ;
@Inline::Java::ISA = qw(Inline) ;


use strict ;


$Inline::Java::VERSION = '0.01' ;

# DEBUG is set via the DEBUG config
if (! defined($Inline::Java::DEBUG)){
	$Inline::Java::DEBUG = 0 ;
}

# This hash will store the $o objects...
$Inline::Java::INLINE = {} ;


require Inline ;
use Config ;
use Data::Dumper ;
use FindBin ;
use File::Copy ;
use Carp ;
use Cwd ;

use IO::Socket ;

use Inline::Java::Class ;
use Inline::Java::Object ;
use Inline::Java::Protocol ;
# Must be last.
use Inline::Java::Init ;


# Stores a list of the Java interpreters running
my @CHILDREN = () ;
my $CHILD_CNT = 0 ;
my $DONE = 0 ;


# This stuff is to control the termination of the Java Interpreter
sub done {
	my $signal = shift ;

	$DONE = 1 ;

	# Close the sockets
	foreach my $o (values %{$Inline::Java::INLINE}){
		close($o->{Java}->{socket}) ;
	}

	my $ec = 0 ;
	if (! $signal){
		debug("killed by natural death.") ;
	}
	else{
		debug("killed by signal SIG$signal.") ;
		$ec = 1 ;
	}

	foreach my $pid (@CHILDREN){
		my $ok = kill 9, $pid ;
		debug("killing $pid...", ($ok ? "ok" : "failed")) ;
	}

	debug("exiting with $ec") ;
	exit($ec) ;
}
END {
	if (! $DONE){
		done() ;
	}
}
use sigtrap 'handler', \&done, 'normal-signals' ;




# Register this module as an Inline language support module
sub register {
	return {
		language => 'Java',
		aliases => ['JAVA', 'java'],
		type => 'interpreted',
		suffix => 'jdat',
	};
}


sub validate {
	my $o = shift ;

	return $o->_validate(0, @_) ;
}


# Here validate is overridden because some of the config options are needed
# at load as well.
sub _validate {
	my $o = shift ;
	my $ignore_other_configs = shift ;

	if (! exists($o->{Java}->{PORT})){
		$o->{Java}->{PORT} = 7890 ;
	}
	if (! exists($o->{Java}->{STARTUP_DELAY})){
		$o->{Java}->{STARTUP_DELAY} = 15 ;
	}
	if (! exists($o->{Java}->{DEBUG})){
		$o->{Java}->{DEBUG} = 0 ;
	}
	if (! exists($o->{Java}->{CLASSPATH})){
		$o->{Java}->{CLASSPATH} = '' ;
	}

	my $install_lib = $o->{install_lib} ;
	my $modpname = $o->{modpname} ;
	my $install = "$install_lib/auto/$modpname" ;

	while (@_) {
		my ($key, $value) = (shift, shift) ;
		if ($key eq 'BIN'){
		    $o->{Java}->{$key} = $value ;
		}
		elsif ($key eq 'CLASSPATH'){
		    $o->{Java}->{$key} = $value ;
		}
		elsif (
			($key eq 'PORT')||
			($key eq 'STARTUP_DELAY')){

			if ($value !~ /^\d+$/){
				croak "config '$key' must be an integer" ;
			}
			if (! $value){
				croak "config '$key' can't be zero" ;
			}
			$o->{Java}->{$key} = $value ;
		}
		elsif ($key eq 'DEBUG'){
			$o->{Java}->{$key} = $value ;
			$Inline::Java::DEBUG = $value ;
		}
		else{
			if (! $ignore_other_configs){
				croak "'$key' is not a valid config option for Inline::Java\n";	
			}
		}
	}

	$o->set_classpath($install) ; 
	$o->set_java_bin() ; 

	debug("validate done.") ;
}


sub set_classpath {
	my $o = shift ;
	my $path = shift ;

	my @list = () ;
	if (defined($ENV{CLASSPATH})){
		push @list, $ENV{CLASSPATH} ;
	}
	if (defined($o->{Java}->{CLASSPATH})){
		push @list, $o->{Java}->{CLASSPATH} ;
	}
	if (defined($path)){
		push @list, $path ;
	}

	my $sep = portable("ENV_VAR_PATH_SEP") ;

	my @cp = split(/$sep/, join($sep, @list)) ;

	my %cp = map { ($_ !~ /^\s*$/ ? ($_, 1) : ()) } @cp ;

	$ENV{CLASSPATH} = join($sep, keys %cp) ;

	debug("  classpath: " . $ENV{CLASSPATH}) ;
}


sub set_java_bin {
	my $o = shift ;

	my $sep = portable("PATH_SEP_RE") ;

	my $cjb = $o->{Java}->{BIN} ;
	my $ejb = $ENV{PERL_INLINE_JAVA_BIN} ;
	if ($cjb){
		$cjb =~ s/$sep+$// ;
		return $o->find_java_bin([$cjb]) ;
	}
	elsif ($ejb) {
		$ejb =~ s/$sep+$// ;
		$o->{Java}->{BIN} = $ejb ;
		return $o->find_java_bin([$ejb]) ;
	}

	# Java binaries are assumed to be in $ENV{PATH} ;
	return $o->find_java_bin() ;
}


sub find_java_bin {
	my $o = shift ;
	my $paths = shift ;

	my $java =  "java" . portable("EXE_EXTENSION") ;
	my $javac = "javac" . portable("EXE_EXTENSION") ;

	my $path = $o->find_file_in_path([$java, $javac], $paths) ;
	if (defined($path)){
		$o->{Java}->{BIN} = $path ;
	}
	else{	
		croak 
			"Can't locate your java binaries ('java' and 'javac'). Please set one of the following to the proper directory:\n" .
			"  - The BIN config option;\n" .
			"  - The PERL_INLINE_JAVA_BIN environment variable;\n" .
			"  - The PATH environment variable.\n" ;
	}
}


sub find_file_in_path {
	my $o = shift ;
	my $files = shift ;
	my $paths = shift ;

	if (! defined($paths)){
		my $psep = portable("ENV_VAR_PATH_SEP") ;
		$paths = [(split(/$psep/, $ENV{PATH} || ''))] ;			
	}
	
	my $home = $ENV{HOME} ;
	my $sep = portable("PATH_SEP_RE") ;

	foreach my $p (@{$paths}){
		debug("path element: $p") ;
		if ($p !~ /^\s*$/){
			$p =~ s/$sep+$// ;

			if ($p =~ /^~/){
				if ($home){
					$p =~ s/^~/$home/ ;
				}
				else{
					# -f don't work with ~/...
					next ;
				}
			}
	
			foreach my $file (@{$files}){
				my $f = "$p/$file" ;
				debug("  candidate: $f\n") ;

				if (-f $f){
					debug("  found file $file in $p") ;

					return $p ;
				}
			}	
		}
	}

	return undef ;
}


# Parse and compile Java code
sub build {
	my $o = shift ;

	if ($o->{Java}->{built}){
		return ;
	}

	$o->write_java ;
	$o->write_makefile ;
	
	$o->compile ;

	$o->{Java}->{built} = 1 ;
}


# Return a small report about the Java code.
sub info {
	my $o = shift;

	if (! $o->{Java}->{built}){
		$o->build ;
	}
	if (! $o->{Java}->{loaded}){
		$o->load ;
	}

	my $info = '' ;
	my $d = $o->{Java}->{data} ;

	my %classes = %{$d->{classes}} ;
 	$info .= "The following Java classes have been bound to Perl:\n" ;
	foreach my $class (sort keys %classes) {
		$info .= "\tclass $class:\n" ;

		if (defined($d->{classes}->{$class}->{constructors})){
			foreach my $const (@{$d->{classes}->{$class}->{constructors}}) {
				my $sign = $const ;
				my $name = $class ;
				$name =~ s/^(.*)::// ;
				$info .= "\t\tpublic $name(" . join(", ", @{$sign}) . ")\n" ;
			}
		}
		foreach my $method (sort keys %{$d->{classes}->{$class}->{methods}->{static}}) {
			my $sign = $d->{classes}->{$class}->{methods}->{static}->{$method} ;
			if (defined($sign)){
				foreach my $s (@{$sign}){
					$info .= "\t\tpublic static $method(" . join(", ", @{$s}) . ")\n" ;
				}
			}
		}
		foreach my $method (sort keys %{$d->{classes}->{$class}->{methods}->{instance}}) {
			my $sign = $d->{classes}->{$class}->{methods}->{instance}->{$method} ;
			if (defined($sign)){
				foreach my $s (@{$sign}){
					$info .= "\t\tpublic $method(" . join(", ", @{$s}) . ")\n" ;
				}
			}
		}
    }


    return $info ;
}


# Writes the java code.
sub write_java {
	my $o = shift ;

	my $build_dir = $o->{build_dir} ;
	my $modfname = $o->{modfname} ;
	my $code = $o->{code} ;

	$o->mkpath($o->{build_dir}) ;

	open(JAVA, ">$build_dir/$modfname.java") or 
		croak "Can't open $build_dir/$modfname.java: $!" ;
	Inline::Java::Init::DumpUserJavaCode(\*JAVA, $modfname, $code) ;
	close(JAVA) ;

	open(JAVA, ">$build_dir/InlineJavaServer.java") or 
		croak "Can't open $build_dir/InlineJavaServer.java: $!" ;
	Inline::Java::Init::DumpServerJavaCode(\*JAVA, $modfname) ;
	close(JAVA) ;

	debug("write_java done.") ;
}


# Writes the makefile.
sub write_makefile {
	my $o = shift ;

	my $build_dir = $o->{build_dir} ;
	my $install_lib = $o->{install_lib} ;
	my $modpname = $o->{modpname} ;
	my $modfname = $o->{modfname} ;

	my $install = "$install_lib/auto/$modpname" ;
	$o->mkpath($install) ;

	my $javac = $o->{Java}->{BIN} . "/javac" . portable("EXE_EXTENSION") ;
	my $java = $o->{Java}->{BIN} . "/java" . portable("EXE_EXTENSION") ;

	my $debug = ($Inline::Java::DEBUG ? "true" : "false") ;

	open(MAKE, ">$build_dir/Makefile") or 
		croak "Can't open $build_dir/Makefile: $!" ;

	my $pjavac = portable("RE_FILE", $javac) ;
	my $pjava = portable("RE_FILE", $java) ;
	my $predir = portable("IO_REDIR") ;

	print MAKE "class:\n" ;
	print MAKE "\t$pjavac $modfname.java > cmd.out $predir\n" ;
	print MAKE "\n" ;
	print MAKE "server:\n" ;
	print MAKE "\t$pjavac InlineJavaServer.java > cmd.out $predir\n" ;
	print MAKE "\n" ;
	print MAKE "report:\n" ;
	print MAKE "\t$pjava InlineJavaServer report $debug $modfname *.class > cmd.out $predir\n" ;

	close(MAKE) ;

	debug("write_makefile done.") ;
}


# Run the build process.
sub compile {
	my $o = shift ;

	my $build_dir = $o->{build_dir} ;
	my $modpname = $o->{modpname} ;
	my $modfname = $o->{modfname} ;
	my $install_lib = $o->{install_lib} ;

	my $install = "$install_lib/auto/$modpname" ;
	my $pinstall = portable("RE_FILE", $install) ;

	my $cwd = Cwd::getcwd() ;
	if ($o->{config}->{UNTAINT}){
	    ($cwd) = $cwd =~ /(.*)/ ;
	}

	my $make = $Config::Config{make} ;
	if (! $make){
		croak "Can't locate your make binary" ;
	}
	$make .= portable("EXE_EXTENSION") ;
	my $path = $o->find_file_in_path([$make]) ;
	if (! $path){
		croak "Can't locate your make binary in your PATH" ;
	}
	my $pmake = portable("RE_FILE", "$path/$make") ;

	foreach my $cmd (
		"$pmake -s class",
		["copy_pattern", $build_dir, "*.class", $pinstall, $o->{config}->{UNTAINT} || 0],
		"$pmake -s server",
		["copy_pattern", $build_dir, "*.class", $pinstall, $o->{config}->{UNTAINT} || 0],
		"$pmake -s report",
		["copy_pattern", $build_dir, "*.jdat", $pinstall, $o->{config}->{UNTAINT} || 0],
		) {


		if ($cmd){

			chdir $build_dir ;
			if (ref($cmd)){
				debug_obj($cmd) ;
				my $func = shift @{$cmd} ;
				my @args = @{$cmd} ;
				
				debug("$func" . "(" . join(", ", @args) . ")") ;

				no strict 'refs' ;
				my $ret = $func->(@args) ;
				if ($ret){
					croak $ret ;					
				}
			}
			else{
				if ($o->{config}->{UNTAINT}){
				    ($cmd) = $cmd =~ /(.*)/ ;
				}

				debug("$cmd") ;
				my $res = my_system($cmd) ;
				$res and do {
					$o->error_copy ;
					croak $o->compile_error_msg($cmd, $cwd) ;
				} ;
			}
			chdir $cwd ;
		}
	}

	if ($o->{config}->{CLEAN_AFTER_BUILD} and 
		not $o->{config}->{REPORTBUG}){
		$o->rmpath($o->{config}->{DIRECTORY} . 'build/', $modpname) ;
	}	

	debug("compile done.") ;
}


sub compile_error_msg {
	my $o = shift ;
	my $cmd = shift ;
	my $cwd = shift ;

	my $build_dir = $o->{build_dir} ;
	my $error = '' ;
	if (open(CMD, "<cmd.out")){
		$error = join("", <CMD>) ;
		close(CMD) ;
	}

	return <<MSG

A problem was encountered while attempting to compile and install your Inline
$o->{language} code. The command that failed was:
  $cmd

The build directory was:
$build_dir

The error message was:
$error

To debug the problem, cd to the build directory, and inspect the output files.

MSG
;
}


# Load and Run the Java Code.
sub load {
	my $o = shift ;
	
	if ($o->{Java}->{loaded}){
		return ;
	}

	if ($o->{mod_exists}){
		# In this case, the options are not rechecked, and therefore
		# the defaults not registered. We must force it
		$o->_validate(1, %{$o->{config}}) ;
	}

	my $install_lib = $o->{install_lib} ;
	my $modpname = $o->{modpname} ;
	my $modfname = $o->{modfname} ;

	my $install = "$install_lib/auto/$modpname" ;
	my $class = $modfname ;

	# Now we must open the jdat file and read it's contents.
	if (! open(JDAT, "$install/$class.jdat")){
		croak "Can't open $install/$class.jdat code information file" ;
	}
	my @lines = <JDAT> ;
	close(JDAT) ;

	debug(@lines) ;

	$o->load_jdat(@lines) ;
	$o->bind_jdat() ;

	my $java = $o->{Java}->{BIN} . "/java" . portable("EXE_EXTENSION") ;
	my $cp = $ENV{CLASSPATH} ;

	debug("  cwd is: " . Cwd::getcwd()) ;
	debug("  load is forking.") ;
	my $pid = fork() ;
	if (! defined($pid)){
		croak "Can't fork to start Java interpreter" ;
	}
	$CHILD_CNT++ ;

	my $port = $o->{Java}->{PORT} + ($CHILD_CNT - 1) ;

	if ($pid){
		# parent here
		debug("  parent here.") ;

		push @CHILDREN, $pid ;

		my $socket = $o->setup_socket($port) ;
		$o->{Java}->{socket} = $socket ;
		$Inline::Java::INLINE->{$modfname} = $o ;

		$o->{Java}->{loaded} = 1 ;
		debug("load done.") ;
	}
	else{
		# child here
		debug("  child here.") ;

		my $debug = ($Inline::Java::DEBUG ? "true" : "false") ;
		
		my $cmd = "$java InlineJavaServer run $debug $port" ;
		debug($cmd) ;

		if ($o->{config}->{UNTAINT}){
		    ($cmd) = $cmd =~ /(.*)/ ;
		}

		my_exec($cmd)
			or croak "Can't exec Java interpreter" ;
	}
}


# Load the jdat code information file.
sub load_jdat {
	my $o = shift ;
	my @lines = @_ ;

	$o->{Java}->{data} = {} ;
	my $d = $o->{Java}->{data} ;

	my $current_class = undef ;
	foreach my $line (@lines){
		chomp($line) ;
		if ($line =~ /^class ([\w.\$]+)$/){
			# We found a class definition
			$current_class = $1 ;
			$current_class =~ s/[\$.]/::/g ;
			$d->{classes}->{$current_class} = {} ;
			$d->{classes}->{$current_class}->{constructors} = undef ;
			$d->{classes}->{$current_class}->{methods} = {} ;
			$d->{classes}->{$current_class}->{methods}->{static} = {} ;
			$d->{classes}->{$current_class}->{methods}->{instance} = {} ;
			$d->{classes}->{$current_class}->{fields} = {} ;
			$d->{classes}->{$current_class}->{fields}->{static} = {} ;
			$d->{classes}->{$current_class}->{fields}->{instance} = {} ; 
		}
		elsif ($line =~ /^constructor \((.*)\)$/){
			my $signature = $1 ;

			if (! defined($d->{classes}->{$current_class}->{constructors})){
				$d->{classes}->{$current_class}->{constructors} = [] ;
			}
			else {
				croak "Can't bind class $current_class: class has more than one constructor" ;
			}
			push @{$d->{classes}->{$current_class}->{constructors}}, [split(", ", $signature)] ;
		}
		elsif ($line =~ /^method (\w+) ([\w.\$]+) (\w+)\((.*)\)$/){
			my $static = $1 ;
			my $declared_in = $2 ;
			my $method = $3 ;
			my $signature = $4 ;

			if ($declared_in eq 'java.lang.Object'){
				next ;
			}

			if (! defined($d->{classes}->{$current_class}->{methods}->{$static}->{$method})){
				$d->{classes}->{$current_class}->{methods}->{$static}->{$method} = [] ;
			}
			else{
				croak "Can't bind class $current_class: class has more than one '$method' method (including inherited methods)" ;
			}
			push @{$d->{classes}->{$current_class}->{methods}->{$static}->{$method}}, [split(", ", $signature)] ;
		}
		elsif ($line =~ /^field (\w+) ([\w.\$]+) (\w+) ([\w.]+)$/){
			my $static = $1 ;
			my $declared_in = $2 ;
			my $field = $3 ;
			my $type = $4 ;

			if ($declared_in eq 'java.lang.Object'){
				next ;
			}

			$d->{classes}->{$current_class}->{fields}->{$static}->{$field} = $type ;
		}
	}

	# debug_obj($d) ;
}


sub get_fields {
	my $o = shift ;
	my $class = shift ;

	my $fields = {} ;
	my $d = $o->{Java}->{data} ;

	while (my ($field, $value) = each %{$d->{classes}->{$class}->{fields}->{static}}){
		$fields->{$field} = $value ;
	}
	while (my ($field, $value) = each %{$d->{classes}->{$class}->{fields}->{instance}}){
		$fields->{$field} = $value ;
	}
	
	return $fields ;
}


# Binds the classes and the methods to Perl
sub bind_jdat {
	my $o = shift ;

	my $d = $o->{Java}->{data} ;
	my $modfname = $o->{modfname} ;

	my $c = ":" ;
	my %classes = %{$d->{classes}} ;
	foreach my $class (sort keys %classes) {
		my $java_class = $class ;
		$java_class =~ s/::/\$/g ;
		my $class_name = $class ;
		$class_name =~ s/^(.*)::// ;
		my $code = <<CODE;
package $o->{pkg}::$class ;
\@$o->{pkg}::$class$c:ISA = qw(Inline::Java::Object) ;
\$$o->{pkg}::$class$c:EXISTS = 1 ;
use Carp ;

CODE

		if (defined($d->{classes}->{$class}->{constructors})){
			my @sign = @{$d->{classes}->{$class}->{constructors}->[0]} ;
			my $signature = '' ;
			if (scalar(@sign)){
				$signature = "'" . join("', '", @sign). "'" ;
			}
			my $pkg = $o->{pkg} ;
			$code .= <<CODE;

sub new {
	my \$class = shift ;
	my \@args = \@_ ;
	
	my \@new_args = \$class->__validate_prototype('new', [\@args], [$signature]) ;

	my \$ret = undef ;
	eval {
		\$ret = \$class->__new('$java_class', \$Inline::Java::INLINE->{'$modfname'}, -1, \@new_args) ;
	} ;
	croak \$@ if \$@ ;

	return \$ret ;
}


sub $class_name {
	return new(\@_) ;
}

CODE
		}


		while (my ($method, $sign) = each %{$d->{classes}->{$class}->{methods}->{static}}){
			my @sign = @{$sign->[0]} ;
			my $signature = '' ;
			if (scalar(@sign)){
				$signature = "'" . join("', '", @sign). "'" ;
			}
			my $pkg = $o->{pkg} ;
			$code .= <<CODE;

sub $method {
	my \$class = shift ;
	my \@args = \@_ ;
	
	my \@new_args = \$class->__validate_prototype('$method', [\@args], [$signature]) ;

	my \$proto = new Inline::Java::Protocol(undef, \$Inline::Java::INLINE->{'$modfname'}) ;	

	my \$ret = undef ;
	eval {
		\$ret = \$proto->CallStaticJavaMethod('$java_class', '$method', \@new_args) ;
	} ;
	croak \$@ if \$@ ;

	return \$ret ;
}

CODE
		}


		while (my ($method, $sign) = each %{$d->{classes}->{$class}->{methods}->{instance}}){
			my @sign = @{$sign->[0]} ;
			my $signature = '' ;
			if (scalar(@sign)){
				$signature = "'" . join("', '", @sign). "'" ;
			}
			$code .= <<CODE;

sub $method {
	my \$this = shift ;
	my \@args = \@_ ;
	
	my \@new_args = \$this->__validate_prototype('$method', [\@args], [$signature]) ;
	
	my \$ret = undef ;
	eval {
		\$ret = \$this->{private}->{proto}->CallJavaMethod('$method', \@new_args) ;
	} ;
	croak \$@ if \$@ ;

	return \$ret ;
}

CODE
		}
		debug($code) ;

		eval $code ;

		croak $@ if $@ ;
	}
}


# Sets up the communication socket to the Java program
sub setup_socket {
	my $o = shift ;
	my $port = shift ;
	
	my $timeout = $o->{Java}->{STARTUP_DELAY} ;

	my $modfname = $o->{modfname} ;
	my $socket = undef ;

	my $last_words = "timeout\n" ;
	eval {
		local $SIG{ALRM} = sub { die($last_words) ; } ;

		my $got_alarm = portable("GOT_ALARM") ;

		if ($got_alarm){
			alarm($timeout) ;
		}

		while (1){
			$socket = new IO::Socket::INET(
				PeerAddr => 'localhost',
				PeerPort => $port,
				Proto => 'tcp') ;
			if ($socket){
				last ;
			}
		}

		if ($got_alarm){
			alarm(0) ;
		}
	} ;
	if ($@){
		if ($@ eq $last_words){
			croak "Java program taking more than $timeout seconds to start, or died before Perl could connect. Increase config STARTUP_DELAY if necessary." ;
		}
		else{
			croak $@ ;
		}
	}
	if (! $socket){
		croak "Can't connect to Java program: $!" ;
	}

	$socket->autoflush(1) ;
	return $socket ;
}



######################## General Functions ########################



sub debug {
	if ($Inline::Java::DEBUG){
		my $str = join("", @_) ;
		while (chomp($str)) {}
		print STDERR "perl: $str\n" ;
	}
}


sub debug_obj {
	my $obj = shift ;

	if ($Inline::Java::DEBUG){
		print STDERR "perl: " . Dumper($obj) ;
	}
}


sub portable {
	my $key = shift ;
	my $val = shift ;

	my $defmap = {
		EXE_EXTENSION		=>	'',
		ENV_VAR_PATH_SEP	=>	':',
		PATH_SEP			=>	'/',
		PATH_SEP_RE			=>	'/',
		RE_FILE				=>  [],
		IO_REDIR			=>  '2<&1',
		GOT_ALARM			=>  1,
	} ;

	my $map = {
		MSWin32 => {
			EXE_EXTENSION		=>	'.exe',
			ENV_VAR_PATH_SEP	=>	';',
			PATH_SEP			=>	'\\',
			PATH_SEP_RE			=>	'\\\\',
			RE_FILE				=>  ['/', '\\'],
			IO_REDIR			=>  '',
			GOT_ALARM			=>  0,
		}
	} ;

	if (! defined($defmap->{$key})){
		croak "Portability issue $key not defined!" ;
	}

	if ((defined($map->{$^O}))&&(defined($map->{$^O}->{$key}))){
		if ($key =~ /^RE_/){
			if (defined($val)){
				my $f = $map->{$^O}->{$key}->[0] ;
				my $t = $map->{$^O}->{$key}->[1] ;
				$val =~ s/$f/$t/eg ;
				debug("portable: $key => $val for $^O is '$val'") ;
				return $val ;
			}
			else{
				debug("portable: $key for $^O is 'undef'") ;
				return undef ;
			}
		}
		else{
			debug("portable: $key for $^O is '$map->{$^O}->{$key}'") ;
			return $map->{$^O}->{$key} ;
		}
	}
	else{
		if ($key =~ /^RE_/){
			debug("portable: $key => $val for $^O is default '$val'") ;
			return $val ;
		}
		else{
			debug("portable: $key for $^O is default '$defmap->{$key}'") ;
			return $defmap->{$key} ;
		}
	}
}


sub copy_pattern {
	my $src_dir = shift ;
	my $pattern = shift ;
	my $dest_dir = shift ;
	my $untaint = shift ;

	chdir($src_dir) ;

	foreach my $file (glob($pattern)){
		if ($untaint){
			($file) = $file =~ /(.*)/ ;
		}
		debug("copy_pattern: $file, $dest_dir/$file") ;
		if (! File::Copy::copy($file, "$dest_dir/$file")){
			return "Can't copy $src_dir/$file to $dest_dir/$file: $!" ;
		}
	}

	return '' ;
}


sub my_system {
	my @args = @_ ;

	my $envp = $ENV{PATH} ;
	$ENV{PATH} = '' ;
	my $ret = system(@args) ;
	$ENV{PATH} = $envp ;

	return $ret ;	
}


sub my_exec {
	my @args = @_ ;

	my $envp = $ENV{PATH} ;
	$ENV{PATH} = '' ;
	my $ret = exec(@args) ;
	$ENV{PATH} = $envp ;

	return $ret ;
}



1 ;

__END__
