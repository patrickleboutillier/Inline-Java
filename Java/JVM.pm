package Inline::Java::JVM ;


use strict ;

$Inline::Java::JVM::VERSION = '0.30' ;

use Carp ;
use IPC::Open3 ;
use IO::File ;

sub new {
	my $class = shift ;
	my $o = shift ;

	my $this = {} ;
	bless($this, $class) ;

	$this->{socket} = undef ;
	$this->{JNI} = undef ;
	$this->{owner} = 1 ;

	Inline::Java::debug("Starting JVM...") ;

	if ($o->get_java_config('JNI')){
		Inline::Java::debug("  JNI mode") ;

		my $jni = new Inline::Java::JNI(
			$ENV{CLASSPATH} || "",
			(Inline::Java::get_DEBUG() ? 1 : 0),
		) ;
		$jni->create_ijs() ;

		$this->{JNI} = $jni ;
	}
	else{
		Inline::Java::debug("  Client/Server mode") ;
		
		my $debug = (Inline::Java::get_DEBUG() ? "true" : "false") ;

		my $shared_jvm = ($o->get_java_config('SHARED_JVM') ? "true" : "false") ;	
		my $port = $o->get_java_config('PORT') ;

		$this->{port} = $port ;
		$this->{host} = "localhost" ;

		# Check if JVM is already running
		if ($shared_jvm eq "true"){
			eval {
				$this->reconnect() ;
			} ;
			if (! $@){
				Inline::Java::debug("  Connected to already running JVM!") ;
				return $this ;
			}
		}

		my $java = $o->get_java_config('BIN') . "/java" . Inline::Java::portable("EXE_EXTENSION") ;
		my $pjava = Inline::Java::portable("RE_FILE", $java) ;

		my $cmd = "\"$pjava\" InlineJavaServer $debug $this->{port} $shared_jvm" ;
		Inline::Java::debug($cmd) ;

		if ($o->get_config('UNTAINT')){
			($cmd) = $cmd =~ /(.*)/ ;
		}

		my $pid = 0 ;
		eval {
			my $in = new IO::File() ;
			$pid = open3($in, ">&STDOUT", ">&STDERR", $cmd) ;
			# We won't be sending anything to the child in this fashion...
			close($in) ;
		} ;
		croak "Can't exec JVM: $@" if $@ ;

		$this->{pid} = $pid ;
		$this->{socket}	= $this->setup_socket(
			$this->{host}, 
			$this->{port}, 
			$o->get_java_config('STARTUP_DELAY'),
			0
		) ;
	}

	return $this ;
}


sub DESTROY {
	my $this = shift ;

	if ($this->{owner}){
		Inline::Java::debug("JVM owner exiting...") ;

		if ($this->{socket}){
			# This asks the Java server to stop and die.
			my $sock = $this->{socket} ;
			if ($sock->connected()){
				Inline::Java::debug("Sending 'die' message to JVM...") ;
				print $sock "die\n" ;
			}
			else{
				carp "Lost connection with Java virtual machine" ;
			}
			close($sock) ;
	
			if ($this->{pid}){
				# Here we go ahead and send the signals anyway to be very 
				# sure it's dead...
				# Always be polite first, and then insist.
				Inline::Java::debug("Sending 15 signal to JVM...") ;
				kill(15, $this->{pid}) ;
				Inline::Java::debug("Sending 9 signal to JVM...") ;
				kill(9, $this->{pid}) ;
	
				# Reap the child...
				waitpid($this->{pid}, 0) ;
			}
		}
	}
	else{
		# We are not the JVM owner, so we simply politely disconnect
		if ($this->{socket}){
			Inline::Java::debug("JVM non-owner exiting...") ;
			close($this->{socket}) ;
			$this->{socket} = undef ;
		}
	}

	# For JNI we need to do nothing because the garbage collector will call
	# the JNI destructor
}


sub setup_socket {
	my $this = shift ;
	my $host = shift ;
	my $port = shift ;
	my $timeout = shift ;
	my $one_shot = shift ;

	my $socket = undef ;

	my $last_words = "timeout\n" ;
	my $got_alarm = Inline::Java::portable("GOT_ALARM") ;

	eval {
		local $SIG{ALRM} = sub { die($last_words) ; } ;

		if ($got_alarm){
			alarm($timeout) ;
		}

		# ignore expected "connection refused" warnings
		# Thanks binkley!
		local $SIG{__WARN__} = sub { 
			warn($@) unless ($@ =~ /Connection refused/i) ; 
		} ;

		while (1){
			$socket = new IO::Socket::INET(
				PeerAddr => $host,
				PeerPort => $port,
				Proto => 'tcp') ;
			if (($socket)||($one_shot)){
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
			if ($got_alarm){
				alarm(0) ;
			}
			croak $@ ;
		}
	}

	if (! $socket){
		croak "Can't connect to JVM at ($host:$port): $!" ;
	}

	$socket->autoflush(1) ;

	return $socket ;
}


sub release {
	my $this = shift ;

	$this->{owner} = 0 ;
}


sub reconnect {
	my $this = shift ;

	if ($this->{JNI}){
		return ;
	}

	if ($this->{socket}){
		# Close the previous socket
		close($this->{socket}) ;
		$this->{socket} = undef ;
	}

	my $socket = $this->setup_socket(
		$this->{host}, 
		$this->{port}, 
		0,
		1
	) ;
	$this->{socket} = $socket ;

	# Now that we have reconnected, we release the JVM
	$this->release() ;
}


sub process_command {
	my $this = shift ;
	my $inline = shift ;
	my $data = shift ;

	my $resp = undef ;
	while (1){
		Inline::Java::debug("  packet sent is $data") ;

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
			$Inline::Java::JNI::INLINE_HOOK = $inline ;
			$resp = $this->{JNI}->process_command($data) ;
		}

		Inline::Java::debug("  packet recv is $resp") ;

		# We got an answer from the server. Is it a callback?
		if ($resp =~ /^callback/){
			$data = Inline::Java::Callback::InterceptCallback($inline, $resp) ;
			next ;
		}
		else{
			last ;
		}
	}

	return $resp ;
}
