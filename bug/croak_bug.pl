#!/usr/local/perl56/bin/perl -w

use strict ;

package class ;
@class::ISA = qw(Inline::Java::Object) ;

use Carp ;


$SIG{__DIE__} = sub {
	$Inline::Java::DONE = 1 ;
	die @_ ;
} ;


sub new {
	my $class = shift ;
	my @args = @_ ;

	my $o = $Inline::Java::INLINE->{'$modfname'} ;

	my $ret = undef ;
	eval {
		$ret = $class->__new() ;
	} ;
	croak $@ if $@ ;

	return $ret ;
}



package Inline::Java::Object ;
@Inline::Java::Object::ISA = qw(Inline::Java::Object::Tie) ;

use strict ;

$Inline::Java::Object::VERSION = '0.10' ;

use Carp ;


# Here we store as keys the knots and as values our blessed private objects
my $PRIVATES = {} ;


# Bogus constructor. We fall here if no public constructor is defined
# in the Java class.
sub new {
	my $class = shift ;
	
	croak "No public constructor defined for class $class" ;
}


# Constructor. Here we create a new object that will be linked
# to a real Java object.
sub __new {
	my $class = shift ;
	my $java_class = shift ;
	my $inline = shift ;
	my $objid = shift ;
	my $proto = shift ;
	my $args = shift ;

	my %this = () ;

	my $knot = tie %this, $class ;
	my $this = bless(\%this, $class) ;

	my $priv = Inline::Java::Object::Private->new($java_class, $inline) ;
	$PRIVATES->{$knot} = $priv ;

	croak "frog" ;
}


sub __get_private {
	my $this = shift ;
	
	my $knot = tied(%{$this}) || $this ;

	my $priv = $PRIVATES->{$knot} ;
	if (! defined($priv)){
		croak "Unknown Java object reference" ;
	}

	return $priv ;
}


# Here an object in destroyed. this function seems to be called twice
# for each object. I think it's because the $this reference is both blessed
# and tied to the same package.
sub DESTROY {
	my $this = shift ;
	
	print STDERR "DESTROY\n" ;
	if (! $Inline::Java::DONE){
		if (! $this->__get_private()->{deleted}){
			$this->__get_private()->{deleted} = 1 ;
			eval {
				$this->__get_private()->{proto}->DeleteJavaObject($this) ;
			} ;
			croak "In method DESTROY of class $this->__get_private()->{class}: $@" if $@ ;
		}
		else{
			# Inline::Java::debug("Object destructor called more than once for $this !") ;
		}
	}

	untie %{$this} ;
}



######################## Hash Methods ########################
package Inline::Java::Object::Tie ;
@Inline::Java::Object::Tie::ISA = qw(Tie::StdHash) ;


use Tie::Hash ;
use Carp ;


sub TIEHASH {
	my $class = shift ;

	return $class->SUPER::TIEHASH(@_) ;
}


sub STORE {
	my $this = shift ;
	my $key = shift ;
	my $value = shift ;

	return $this->__set_member($key, $value) ;
}


sub FETCH {
 	my $this = shift ;
 	my $key = shift ;

	return $this->__get_member($key) ;
}


sub FIRSTKEY { 
	my $this = shift ;

	return $this->SUPER::FIRSTKEY() ;
}


sub NEXTKEY { 
	my $this = shift ;

	return $this->SUPER::NEXTKEY() ;
}


sub EXISTS { 
 	my $this = shift ;
 	my $key = shift ;

	my $inline = $Inline::Java::INLINE->{$this->__get_private()->{module}} ;
	my $fields = $inline->get_fields($this->__get_private()->{java_class}) ;

	if ($fields->{$key}){
		return 1 ;
	}
	
	return 0 ;
}


sub DELETE { 
 	my $this = shift ;
 	my $key = shift ;

	croak "Operation DELETE not supported on Java object" ;
}


sub CLEAR { 
 	my $this = shift ;

	croak "Operation CLEAR not supported on Java object" ;
}


sub DESTROY {
	my $this = shift ;

	$PRIVATES->{$this} = undef ;
}




######################## Private Object ########################
package Inline::Java::Object::Private ;

sub new {
	my $class = shift ;
	my $java_class = shift ;
	my $inline = shift ;
	
	my $this = {} ;
	$this->{class} = $class ;
	$this->{java_class} = $java_class ;
	$this->{module} = $inline->{modfname} ;
	$this->{known_to_perl} = 1 ;
	$this->{proto} = new Inline::Java::Protocol($this, $inline) ;

	bless($this, $class) ;

	return $this ;
}


package Inline::Java::Protocol ;


use strict ;

$Inline::Java::Protocol::VERSION = '0.10' ;

use Carp ;


sub new {
	my $class = shift ;
	my $obj = shift ;
	my $inline = shift ;

	my $this = {} ;
	$this->{obj_priv} = $obj || {} ;
	$this->{module} = $inline->{modfname} ;

	bless($this, $class) ;
	return $this ;
}


sub ISA {
	my $this = shift ;
	my $proto = shift ;

	Inline::Java::debug("checking if $this is a $proto") ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	my $data = join(" ", 
		"isa", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		Inline::Java::Class::ValidateClass($proto),
	) ;

	Inline::Java::debug("  packet sent is $data") ;

	return $this->Send($data, 1) ;
}


# Called to create a Java object
sub CreateJavaObject {
	my $this = shift ;
	my $class = shift ;
	my $proto = shift ;
	my $args = shift ;

	Inline::Java::debug("creating object new $class" . $this->CreateSignature($args)) ; 	

	my $data = join(" ", 
		"create_object", 
		Inline::Java::Class::ValidateClass($class),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;

	return $this->Send($data, 1) ;
}


# Called to call a static Java method
sub CallStaticJavaMethod {
	my $this = shift ;
	my $class = shift ;
	my $method = shift ;
	my $proto = shift ;
	my $args = shift ;

	Inline::Java::debug("calling $class.$method" . $this->CreateSignature($args)) ;

	my $data = join(" ", 
		"call_static_method", 
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMethod($method),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;		

	return $this->Send($data) ;
}


# Calls a regular Java method.
sub CallJavaMethod {
	my $this = shift ;
	my $method = shift ;
	my $proto = shift ;
	my $args = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("calling object($id).$method" . $this->CreateSignature($args)) ;

	my $data = join(" ", 
		"call_method", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMethod($method),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;

	return $this->Send($data) ;
}


# Sets a member variable.
sub SetJavaMember {
	my $this = shift ;
	my $member = shift ;
	my $proto = shift ;
	my $arg = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("setting object($id)->{$member} = $arg->[0]") ;
	my $data = join(" ", 
		"set_member", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMember($member),
		Inline::Java::Class::ValidateClass($proto->[0]),
		$this->ValidateArgs($arg),
	) ;

	Inline::Java::debug("  packet sent is $data") ;

	return $this->Send($data) ;
}


# Gets a member variable.
sub GetJavaMember {
	my $this = shift ;
	my $member = shift ;
	my $proto = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("getting object($id)->{$member}") ;

	my $data = join(" ", 
		"get_member", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMember($member),
		Inline::Java::Class::ValidateClass($proto->[0]),
		"undef:",
	) ;

	Inline::Java::debug("  packet sent is $data") ;

	return $this->Send($data) ;
}


# Deletes a Java object
sub DeleteJavaObject {
	my $this = shift ;
	my $obj = shift ;

	if (defined($this->{obj_priv}->{id})){
		my $id = $this->{obj_priv}->{id} ;
		my $class = $this->{obj_priv}->{java_class} ;

		Inline::Java::debug("deleting object $obj $id ($class)") ;

		my $data = join(" ", 
			"delete_object", 
			$id,
		) ;

		Inline::Java::debug("  packet sent is $data") ;		

		$this->Send($data) ;
	}
}


# This method makes sure that the method we are asking for
# has the correct form for a Java method.
sub ValidateMethod {
	my $this = shift ;
	my $method = shift ;

	if ($method !~ /^(\w+)$/){
		croak "Invalid Java method name $method" ;
	}	

	return $method ;
}


# This method makes sure that the member we are asking for
# has the correct form for a Java member.
sub ValidateMember {
	my $this = shift ;
	my $member = shift ;

	if ($member !~ /^(\w+)$/){
		croak "Invalid Java member name $member" ;
	}	

	return $member ;
}


# Validates the arguments to be used in a method call.
sub ValidateArgs {
	my $this = shift ;
	my $args = shift ;

	my @ret = () ;
	foreach my $arg (@{$args}){
		if (! defined($arg)){
			push @ret, "undef:" ;
		}
		elsif (ref($arg)){
			if ((! UNIVERSAL::isa($arg, "Inline::Java::Object"))&&(! UNIVERSAL::isa($arg, "Inline::Java::Array"))){
				croak "A Java method or member can only have Java objects, Java arrays or scalars as arguments" ;
			}

			if (UNIVERSAL::isa($arg, "Inline::Java::Array")){
				$arg = $arg->__get_object() ; 
			}
			my $class = $arg->__get_private()->{java_class} ;
			my $id = $arg->__get_private()->{id} ;
			push @ret, "object:$class:$id" ;
		}
		else{
			push @ret, "scalar:" . join(".", unpack("C*", $arg)) ;
		}
	}

	return @ret ;
}


sub CreateSignature {
	my $this = shift ;
	my $proto = shift ;
	my $del = shift || ", " ;

	return "(" . join($del, @{$proto}) . ")" ;
}


# This actually sends the request to the Java program. It also takes
# care of registering the returned object (if any)
sub Send {
	my $this = shift ;
	my $data = shift ;
	my $const = shift ;

	my $resp = undef ;
	my $inline = $Inline::Java::INLINE->{$this->{module}} ;
	if (! $inline->{Java}->{JNI}){
		my $sock = $inline->{Java}->{socket} ;
		print $sock $data . "\n" or
			croak "Can't send packet over socket: $!" ;

		$resp = <$sock> ;
	}
	else{
		$resp = $inline->{Java}->{JNI}->process_command($data) ;
	}

	Inline::Java::debug("  packet recv is $resp") ;

	if (! $resp){
		croak "Can't receive packet over socket: $!" ;
	}
	elsif ($resp =~ /^error scalar:([\d.]*)$/){
		my $msg = pack("C*", split(/\./, $1)) ;
		Inline::Java::debug("  packet recv error: $msg") ;
		croak $msg ;
	}
	elsif ($resp =~ /^ok scalar:([\d.]*)$/){
		return pack("C*", split(/\./, $1)) ;
	}
	elsif ($resp =~ /^ok undef:$/){
		return undef ;
	}
	elsif ($resp =~ /^ok object:(\d+):(.*)$/){
		# Create the Perl object wrapper and return it.
		my $id = $1 ;
		my $class = $2 ;

		if ($const){
			$this->{obj_priv}->{java_class} = $class ;
			$this->{obj_priv}->{id} = $id ;
			
			return undef ;
		}
		else{
			my $perl_class = $class ;
			$perl_class =~ s/[.\$]/::/g ;
			my $pkg = $inline->{pkg} ;
			$perl_class = $pkg . "::" . $perl_class ;
			Inline::Java::debug($perl_class) ;

			my $known = 0 ;
			{
				no strict 'refs' ;
				if (defined(${$perl_class . "::" . "EXISTS"})){
					Inline::Java::debug("  returned class exists!") ;
					$known = 1 ;
				}
				else{
					Inline::Java::debug("  returned class doesn't exist!") ;
				}
			}

			my $obj = undef ;
			if ($known){
				Inline::Java::debug("creating stub for known object...") ;
				$obj = $perl_class->__new($class, $inline, $id) ;
				Inline::Java::debug("stub created ($obj)...") ;
			}
			else{
				Inline::Java::debug("creating stub for unknown object...") ;
				$obj = Inline::Java::Object->__new($class, $inline, $id) ;
				Inline::Java::debug("stub created ($obj)...") ;
				$obj->__get_private()->{known_to_perl} = 0 ;
			}

			Inline::Java::debug("checking if stub is array...") ;
			if (Inline::Java::Class::ClassIsArray($class)){
				Inline::Java::debug("creating array object...") ;
				$obj = new Inline::Java::Array($obj) ;
				Inline::Java::debug("array object created...") ;
			}

			Inline::Java::debug("returning stub...") ;

			return $obj ;
		}
	}
}



package main ;

my $o = new class() ;

