package Inline::Java::Object ;
@Inline::Java::Object::ISA = qw(Tie::StdHash) ;


use strict ;

$Inline::Java::Object::VERSION = '0.10' ;

use Inline::Java::Protocol ;
use Tie::Hash ;
use Carp ;


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

	my $knot = tie %this, 'Inline::Java::Object' ;
	my $this = bless (\%this, $class) ;

	$this->{private} = {} ;
	$this->{private}->{class} = $class ;
	$this->{private}->{java_class} = $java_class ;
	$this->{private}->{module} = $inline->{modfname} ;
	$this->{private}->{known_to_perl} = 1 ;
	$this->{private}->{proto} = new Inline::Java::Protocol($this->{private}, $inline) ;

	if ($objid <= 0){
		eval {
			$this->{private}->{proto}->CreateJavaObject($java_class, $proto, $args) ;
		} ;		
		croak "In method new of class $class: $@" if $@ ;
	}
	else{
		$this->{private}->{id} = $objid ;
		Inline::Java::debug("Object created in java ($class):") ;
	}

	Inline::Java::debug_obj($this) ;

	return $this ;
}


# Checks to make sure all the arguments can be "cast" to prototype
# types.
sub __validate_prototype {
	my $class = shift ;
	my $method = shift ;
	my $args = shift ;
	my $prototypes = shift ;
	my $inline = shift ;

	my $matched_protos = [] ;
	my $new_arguments = [] ;
	my $scores = [] ;

	foreach my $proto (@{$prototypes}){
		my $new_args = undef ;
		my $score = undef ;
		eval {
			($new_args, $score) = Inline::Java::Class::CastArguments($args, $proto, $inline->{modfname}) ;
		} ;
		if ($@){
			# We croaked, so we assume that we were not able to cast 
			# the arguments to the prototype
			Inline::Java::debug("Rescued from death: $@") ;
			next ;
		}
		# We passed!
		push @{$matched_protos}, $proto ;
		push @{$new_arguments}, $new_args ;
		push @{$scores}, $score ;
	}

	if (! scalar(@{$matched_protos})){
		my $name = (ref($class) ? $class->{private}->{class} : $class) ;
		my $sa = Inline::Java::Protocol->CreateSignature($args) ;
		my $msg = "In method $method of class $name: Can't find any signature that matches " .
			"the arguments passed $sa. Available signatures are:\n"  ;
		foreach my $proto (@{$prototypes}){
			my $s = Inline::Java::Protocol->CreateSignature($proto) ;
			$msg .= "\t$method$s\n" ;
		}
		chomp $msg ;
		croak $msg ;
	}

	# Amongst the ones that matched, we need to select the one with the 
	# highest score. For now, the last one will do.
	
	my $nb = scalar(@{$matched_protos}) ;
	return ($matched_protos->[$nb - 1], $new_arguments->[$nb - 1]) ;
}


sub AUTOLOAD {
	my $this = shift ;
	my @args = @_ ;

	use vars qw($AUTOLOAD) ;
	my $func_name = $AUTOLOAD ;
	# Strip package from $func_name, Java will take of finding the correct
	# method.
	$func_name =~ s/^(.*)::// ;

	Inline::Java::debug("$func_name") ;

	croak "No public method $func_name defined for class $this->{private}->{class}" ;	
}


# Here an object in destroyed. this function seems to be called twice
# for each object. I think it's because the $this reference is both blessed
# and tied to the same package.
sub DESTROY {
	my $this = shift ;
	
	if (! $Inline::Java::DONE){
		if (! $this->{private}->{deleted}){
			$this->{private}->{deleted} = 1 ;
			eval {
				$this->{private}->{proto}->DeleteJavaObject($this) ;
			} ;
			croak "In method DESTROY of class $this->{private}->{class}: $@" if $@ ;
		}
		else{
			Inline::Java::debug("Object destructor called more than once!") ;
		}
	}
}



######################## Hash Methods ########################



sub TIEHASH {
	my $class = shift ;

	return $class->SUPER::TIEHASH(@_) ;
}


sub STORE {
	my $this = shift ;
	my $key = shift ;
	my $value = shift ;

	if ($key eq "private"){
		return $this->SUPER::STORE($key, $value) ;
	}

	my $inline = $Inline::Java::INLINE->{$this->{private}->{module}} ;
	my $fields = $inline->get_fields($this->{private}->{java_class}) ;

	if ($fields->{$key}){
		my $list = $fields->{$key} ;

		my $matched_protos = [] ;
		my $new_arguments = [] ;
		my $scores = [] ;
		foreach my $f (@{$list}){
			my $new_args = undef ;
			my $score = undef ;
			eval {
				($new_args, $score) = Inline::Java::Class::CastArguments([$value], [$f], $this->{private}->{module}) ;
			} ;
			if ($@){
				# We croaked, so we assume that we were not able to cast 
				# the arguments to the prototype
				next ;
			}
			# We passed!
			push @{$matched_protos}, [$f] ;
			push @{$new_arguments}, $new_args ;
			push @{$scores}, $score ;
		}

		if (! scalar(@{$matched_protos})){
			my $name = $this->{private}->{class} ;
			my $msg = "For member $key of class $name: Can't assign passed value to variable " .
				"this variable can accept:\n"  ;
			foreach my $f (@{$list}){
				$msg .= "\t$f\n" ;
			}
			chomp $msg ;
			croak $msg ;
		}

		# Amongst the ones that matched, we need to select the one with the 
		# highest score. For now, the last one will do.

		my $nb = scalar(@{$matched_protos}) ;
		$this->{private}->{proto}->SetJavaMember($key, $matched_protos->[$nb - 1], $new_arguments->[$nb - 1]) ;
	}
	else{
		croak "No public member variable $key defined for class $this->{private}->{class}" ;
	}
}


sub FETCH {
 	my $this = shift ;
 	my $key = shift ;

 	if ($key eq "private"){
 		return $this->SUPER::FETCH($key) ;
	}

	Inline::Java::debug("fetching member variable $key") ;

	my $inline = $Inline::Java::INLINE->{$this->{private}->{module}} ;
	my $fields = $inline->get_fields($this->{private}->{java_class}) ;

	if ($fields->{$key}){
		# Here when the user is requesting a field, we can't know which
		# one the user wants, so we select the first one.
		my $proto = $fields->{$key}->[0] ;

		my $ret = $this->{private}->{proto}->GetJavaMember($key, [$proto], [undef]) ;
		Inline::Java::debug("returning member ($ret)") ;
	
		return $ret ;
	}
	else{
		croak "No public member variable $key defined for class $this->{private}->{class}" ;
	}
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

	my $inline = $Inline::Java::INLINE->{$this->{private}->{module}} ;
	my $fields = $inline->get_fields($this->{private}->{java_class}) ;

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


package Inline::Java::Object ;


1 ;


__DATA__

