package Inline::Java ;
@Inline::Java::ISA = qw(Inline) ;


use strict ;


$Inline::Java::VERSION = '0.01' ;

# DEBUG is set via the JAVA_DEBUG config
if (! defined($Inline::Java::DEBUG)){
	$Inline::Java::DEBUG = 0 ;
}


require Inline ;
use Config ;
use Data::Dumper ;
use FindBin ;
use Carp ;
use Cwd qw(cwd abs_path) ;

use IO::Socket ;

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

	if (! $signal){
		debug("killed by natural death.") ;
	}
	else{
		debug("killed by signal SIG$signal.") ;
	}

	foreach my $pid (@CHILDREN){
		my $ok = kill 9, $pid ;
		debug("killing $pid...", ($ok ? "ok" : "failed")) ;
	}

	exit 1 ;
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
	    type => 'compiled',
	    suffix => 'jdat',
	   };
}


# Validate the Java config options
sub usage_validate {
    my $key = shift;
    return <<END;
The value of config option '$key' must be a string or an array ref

END
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

	if (! exists($o->{Java}->{JAVA_PORT})){
		$o->{Java}->{JAVA_PORT} = 7890 ;
	}
	if (! exists($o->{Java}->{JAVA_STARTUP_DELAY})){
		$o->{Java}->{JAVA_STARTUP_DELAY} = 15 ;
	}
	if (! exists($o->{Java}->{JAVA_DEBUG})){
		$o->{Java}->{JAVA_DEBUG} = 0 ;
	}

    while (@_) {
		my ($key, $value) = (shift, shift) ;
		if ($key eq 'JAVA_BIN'){
		    $o->{Java}->{$key} = $value ;
		}
		elsif ($key eq 'JAVA_CLASSPATH'){
		    $o->{Java}->{$key} = $value ;
		}
		elsif (
			($key eq 'JAVA_PORT')||
			($key eq 'JAVA_STARTUP_DELAY')){

			if ($value !~ /^\d+$/){
				croak "config '$key' must be an integer" ;
			}
			if (! $value){
				croak "config '$key' can't be zero" ;
			}
		    $o->{Java}->{$key} = $value ;
		}
		elsif ($key eq 'JAVA_DEBUG'){
		    $o->{Java}->{$key} = $value ;
			$Inline::Java::DEBUG = $value ;
		}
		else{
			if (! $ignore_other_configs){
				croak "'$key' is not a valid config option for Inline::Java\n";	
			}
		}
	}

	$o->set_classpath() ; 
	$o->set_java_bin() ; 

	debug("validate done.") ;
}



# Parse and compile Java code
sub build {
	my $o = shift ;

	my $install_lib = $o->{install_lib} ;
	my $modpname = $o->{modpname} ;

	my $install = "$install_lib/auto/$modpname" ;
	$o->set_classpath($install) ; 

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

	my $javac = $o->{Java}->{JAVA_BIN} . "/javac" ;
	my $java = $o->{Java}->{JAVA_BIN} . "/java" ;

	my $debug = ($Inline::Java::DEBUG ? "true" : "false") ;

	open(MAKE, ">$build_dir/Makefile") or 
		croak "Can't open $build_dir/Makefile: $!" ;

	print MAKE "class:\n" ;
	print MAKE "\t$javac $modfname.java > cmd.out 2<&1\n" ;
	print MAKE "\tcp -f *.class $install\n" ;
	print MAKE "\n" ;
	print MAKE "server:\n" ;
	print MAKE "\t$javac InlineJavaServer.java > cmd.out 2<&1\n" ;
	print MAKE "\tcp -f *.class $install\n" ;
	print MAKE "\n" ;
	print MAKE "report:\n" ;
	print MAKE "\t$java InlineJavaServer report $debug $modfname *.class > cmd.out 2<&1\n" ;
	print MAKE "\tcp -f *.jdat $install\n" ;

	close(MAKE) ;

	debug("write_makefile done.") ;
}


sub set_classpath {
	my $o = shift ;
	my $path = shift ;

	my @cp = split(/:/, join(":", $ENV{CLASSPATH}, $o->{Java}->{JAVA_CLASSPATH}, $path)) ;

	my %cp = map { ($_ !~ /^\s*$/ ? ($_, 1) : ()) } @cp ;

	$ENV{CLASSPATH} = join(":", keys %cp) ;

	debug("  classpath: " . $ENV{CLASSPATH}) ;
}


sub set_java_bin {
	my $o = shift ;

	my $cjb = $o->{Java}->{JAVA_BIN} ;
	my $ejb = $ENV{JAVA_BIN} ;
	if ($cjb){
		$cjb =~ s/\/+$// ;
		return $o->find_java_bin($cjb) ;
	}
	elsif ($ejb) {
		$ejb =~ s/\/+$// ;
		$o->{Java}->{JAVA_BIN} = $ejb ;
		return $o->find_java_bin($ejb) ;
	}

	# Java binaries are assumed to be in $ENV{PATH} ;
	my @path = split(/:/, $ENV{PATH}) ;
	return $o->find_java_bin(@path) ;
}


sub find_java_bin {
	my $o = shift ;
	my @paths = @_ ;
	
	my $home = $ENV{HOME} ;

	my $found = 0 ;
	foreach my $p (@paths){
		if ($p !~ /^\s*$/){
			$p =~ s/\/+$// ;

			if ($p =~ /^~/){
				if ($home){
					$p =~ s/^~/$home/ ;
				}
				else{
					# -f don't work with ~/...
					next ;
				}
			}
	
			my $java = $p . "/java" ;
			if (-f $java){
				debug("  found java binaries in $p") ;
				$o->{Java}->{JAVA_BIN} = $p ;
				$found = 1 ;
				last ;
			}	
		}
	}

	if (! $found){
		croak 
			"Can't locate your java binaries ('java' and 'javac'). Please set one of the following to the proper directory:\n" .
		    "  - The JAVA_BIN config option;\n" .
		    "  - The JAVA_BIN environment variable;\n" .
		    "  - The PATH environment variable.\n" ;
	}
}


# Run the build process.
sub compile {
	my $o = shift ;

	my $build_dir = $o->{build_dir} ;
	my $modpname = $o->{modpname} ;
	my $modfname = $o->{modfname} ;
	my $install_lib = $o->{install_lib} ;

	my $cwd = &cwd ;

	my $make = $Config::Config{make} ;
	if (! $make){
		croak "Can't locate your make binary" ;
	}

	foreach my $cmd (
		"make -s class",
		"make -s server",
		"make -s report",
		) {

		if ($cmd){
			debug("$cmd") ;
			chdir $build_dir ;
			my $res = system($cmd) ;
			$res and do {
				$o->error_copy ;
				croak $o->error_msg($cmd, $cwd) ;
			} ;

		    chdir $cwd ;
		}
	}

    if ($o->{config}{CLEAN_AFTER_BUILD} and 
		not $o->{config}{REPORTBUG}){
		$o->rmpath($o->{config}{DIRECTORY} . 'build/', $modpname) ;
    }	

	debug("compile done.") ;
}


sub error_msg {
	my $o = shift ;
	my $cmd = shift ;
	my $cwd = shift ;

	my $build_dir = $o->{build_dir} ;
	my $error = `cat cmd.out` ;

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

	my $java = $o->{Java}->{JAVA_BIN} . "/java" ;
	my $cp = $ENV{CLASSPATH} ;

	debug("  cwd is: " . cwd()) ;
	debug("  load is forking.") ;
	my $pid = fork() ;
	if (! defined($pid)){
		croak "Can't fork to start Java interpreter" ;
	}
	$CHILD_CNT++ ;

	my $port = $o->{Java}->{JAVA_PORT} + ($CHILD_CNT - 1) ;

	if ($pid){
		# parent here
		debug("  parent here.") ;

		push @CHILDREN, $pid ;

		$o->setup_socket($port) ;
	
		$Inline::Java::LOADED = 1 ;
		$o->{Java}->{loaded} = 1 ;
		debug("load done.") ;
	}
	else{
		# child here
		debug("  child here.") ;

		my $debug = ($Inline::Java::DEBUG ? "true" : "false") ;
		debug("    $java InlineJavaServer run $debug $port") ;

		exec "$java InlineJavaServer run $debug $port"
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
			$current_class =~ s/\$/::/g ;
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

			if ($declared_in ne $current_class){
				next ;
			}
			if (! defined($d->{classes}->{$current_class}->{methods}->{$static}->{$method})){
				$d->{classes}->{$current_class}->{methods}->{$static}->{$method} = [] ;
			}
			else{
				croak "Can't bind class $current_class: class has more than one '$method' method" ;
			}
			push @{$d->{classes}->{$current_class}->{methods}->{$static}->{$method}}, [split(", ", $signature)] ;
		}
		elsif ($line =~ /^field (\w+) ([\w.\$]+) (\w+) ([\w.]+)$/){
			my $static = $1 ;
			my $declared_in = $2 ;
			my $field = $3 ;
			my $type = $4 ;

			if ($declared_in ne $current_class){
				next ;
			}

			$d->{classes}->{$current_class}->{fields}->{$static}->{$field} = $type ;
		}
	}

	# debug_obj($d) ;
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

CODE

		if (defined($d->{classes}->{$class}->{constructors})){
			my @sign = @{$d->{classes}->{$class}->{constructors}->[0]} ;
			my $signature = "'" . join("', '", @sign). "'" ;
			my $pkg = $o->{pkg} ;
			$code .= <<CODE;

sub new {
	my \$class = shift ;
	my \@args = \@_ ;
	
	my \$err = \$class->__validate_prototype([\@args], [($signature)]) ;
	croak \$err if \$err ;

	return \$class->__new('$java_class', '$pkg', '$modfname', -1, \@_) ;
}


sub $class_name {
	return new(\@_) ;
}

CODE
		}


		foreach my $method (sort keys %{$d->{classes}->{$class}->{methods}->{static}}) {
			my @sign = @{$d->{classes}->{$class}->{methods}->{static}->{$method}->[0]} ;
			my $signature = "'" . join("', '", @sign). "'" ;
			my $pkg = $o->{pkg} ;
			$code .= <<CODE;

sub $method {
	my \$class = shift ;
	my \@args = \@_ ;
	
	my \$err = \$class->__validate_prototype([\@args], [($signature)]) ;
	croak \$err if \$err ;
	
	my \$proto = new Inline::Java::Protocol(undef, '$modfname') ;

	return \$proto->CallStaticJavaMethod('$java_class', '$pkg', '$method', \@args) ;
}

CODE
		}


		foreach my $method (sort keys %{$d->{classes}->{$class}->{methods}->{instance}}) {
			my @sign = @{$d->{classes}->{$class}->{methods}->{instance}->{$method}->[0]} ;
			my $signature = "'" . join("', '", @sign). "'" ;
			$code .= <<CODE;

sub $method {
	my \$this = shift ;
	my \@args = \@_ ;
	
	my \$err = \$this->__validate_prototype([\@args], [($signature)]) ;
	croak \$err if \$err ;
	
	return \$this->{private}->{proto}->CallJavaMethod('$method', \@args) ;
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
	
	my $timeout = $o->{Java}->{JAVA_STARTUP_DELAY} ;

	my $modfname = $o->{modfname} ;
	my $socket = undef ;

	my $last_words = "timeout\n" ;
	eval {
		local $SIG{ALRM} = sub { die($last_words) ; } ;
		alarm($timeout) ;

		while (1){
			$socket = new IO::Socket::INET(
				PeerAddr => 'localhost',
				PeerPort => $port,
				Proto => 'tcp') ;
			if ($socket){
				last ;
			}
		}

		alarm(0) ;
	} ;
	if ($@){
		if ($@ eq $last_words){
			croak "Java program taking more than $timeout seconds to start. Increase config JAVA_STARTUP_DELAY if necessary." ;
		}
		else{
			croak $@ ;
		}
	}
	if (! $socket){
		croak "Can't connect to Java program: $!" ;
	}

	$socket->autoflush(1) ;
	$Inline::Java::Protocol::socket->{$modfname} = $socket ;
}


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
		print STDERR Dumper($obj) ;
	}
}



1 ;

__END__
