package Inline::Java::JVM ;


use strict ;

$Inline::Java::JVM::VERSION = '0.20' ;

use Carp ;


sub new {
	my $class = shift ;
	my $o = shift ;

	my $this = {} ;
	bless($this, $class) ;

	$this->{socket} = undef ;
	$this->{JNI} = undef ;

	Inline::Java::debug("Starting JVM...") ;

	if ($o->{Java}->{JNI}){
		Inline::Java::debug("  JNI mode") ;

		require Inline::Java::JNI ;

		my $jni = new Inline::Java::JNI(
			$ENV{CLASSPATH} || "", 
			(Inline::Java::get_DEBUG() ? 1 : 0),
		) ;
		$jni->create_ijs() ;

		$this->{JNI} = $jni ;
	}
	else{
		Inline::Java::debug("  Client/Server mode") ;

		my $pid = fork() ;
		if (! defined($pid)){
			croak "Can't fork to start JVM" ;
		}

		my $port = $o->{Java}->{PORT} ;
		if ($pid){
			$this->{pid} = $pid ;
			$this->{socket}	= $this->setup_socket($port, $o->{Java}->{STARTUP_DELAY}) ;
		}
		else{
			my $debug = (Inline::Java::get_DEBUG() ? "true" : "false") ;

			my $java = $o->{Java}->{BIN} . "/java" . Inline::Java::portable("EXE_EXTENSION") ;
			my $pjava = Inline::Java::portable("RE_FILE", $java) ;

			my @cmd = ($pjava, 'InlineJavaServer', $debug, $port) ;
			Inline::Java::debug(join(" ", @cmd)) ;

			if ($o->{config}->{UNTAINT}){
				foreach my $cmd (@cmd){
					($cmd) = $cmd =~ /(.*)/ ;
				}
			}

			exec(@cmd)
				or croak "Can't exec JVM" ;
		}
	}

	return $this ;
}


sub setup_socket {
	my $this = shift ;
	my $port = shift ;
	my $timeout = shift ;

	my $socket = undef ;
	my $last_words = "timeout\n" ;
	eval {
		local $SIG{ALRM} = sub { die($last_words) ; } ;

		my $got_alarm = Inline::Java::portable("GOT_ALARM") ;

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
			croak "JVM taking more than $timeout seconds to start, or died before Perl could connect. Increase config STARTUP_DELAY if necessary." ;
		}
		else{
			croak $@ ;
		}
	}
	if (! $socket){
		croak "Can't connect to JVM: $!" ;
	}

	$socket->autoflush(1) ;

	return $socket ;
}


sub process_command {
	my $this = shift ;
	my $data = shift ;

	Inline::Java::debug("  packet sent is $data") ;		

	my $resp = undef ;
	if ($this->{socket}){
		my $sock = $this->{socket} ;
		print $sock $data . "\n" or
			croak "Can't send packet to JVM: $!" ;

		$resp = <$sock> ;
		if (! $resp){
			croak "Can't receive packet from JVM: $!" ;
		}
	}
	if ($this->{JNI}){
		$resp = $this->{JNI}->process_command($data) ;
	}

	Inline::Java::debug("  packet recv is $resp") ;

	return $resp ;
}


sub DESTROY {
	my $this = shift ;

	if ($this->{socket}){
		# This asks the Java server to stop and die.
		my $sock = $this->{socket} ;
		if ($sock->connected()){
			print $sock "die\n" ;
		}
		close($sock) ;
		
		my $pid = $this->{pid} ;
		if ($pid){
			my $ok = kill 9, $this->{pid} ;
			Inline::Java::debug("killing $pid...", ($ok ? "ok" : "failed")) ;
		}
	}

	# For JNI we need to do nothing because the garbage collector will call
	# the JNI destructor
}

