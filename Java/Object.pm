package Inline::Java::Object ;
@Inline::Java::Object::ISA = qw(Inline::Java::Object::Tie) ;

use strict ;

$Inline::Java::Object::VERSION = '0.10' ;

use Inline::Java::Protocol ;
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

	my $priv = Inline::Java::Object::Private->new($class, $java_class, $inline) ;
	$PRIVATES->{$knot} = $priv ;

	if ($objid <= -1){
		eval {
			$this->__get_private()->{proto}->CreateJavaObject($java_class, $proto, $args) ;
		} ;		
		croak "In method new of class $class: $@" if $@ ;
	}
	else{
		$this->__get_private()->{id} = $objid ;
		Inline::Java::debug("Object created in java ($class):") ;
	}

	Inline::Java::debug_obj($this) ;

	return $this ;
}


sub __get_private {
	my $this = shift ;
	
	my $knot = tied(%{$this}) || $this ;

	my $priv = $PRIVATES->{$knot} ;
	if (! defined($priv)){
		croak "Unknown Java object reference $knot" ;
	}

	return $priv ;
}


# Checks to make sure all the arguments can be "cast" to prototype
# types.
sub __validate_prototype {
	my $this = shift ;
	my $method = shift ;
	my $args = shift ;
	my $protos = shift ;
	my $static = shift ;
	my $inline = shift ;

	my $matched_protos = [] ;
	my $new_arguments = [] ;
	my $scores = [] ;

	my $prototypes = [] ;
	foreach my $s (values %{$protos}){
		if ($static == $s->{STATIC}){
			push @{$prototypes}, $s->{SIGNATURE} ;
		}
	}
 
	my $nb_proto = scalar(@{$prototypes}) ;
	my @errors = () ;
	foreach my $proto (@{$prototypes}){
		my $new_args = undef ;
		my $score = undef ;
		eval {
			($new_args, $score) = Inline::Java::Class::CastArguments($args, $proto, $inline->{modfname}) ;
		} ;
		if ($@){
			if ($nb_proto == 1){
				# Here we have only 1 prototype, so we return the error.
				croak $@ ;
			}
			push @errors, $@ ;
			Inline::Java::debug("Error trying to fit args to prototype: $@") ;
			next ;
		}

		# We passed!
		push @{$matched_protos}, $proto ;
		push @{$new_arguments}, $new_args ;
		push @{$scores}, $score ;
	}

	if (! scalar(@{$matched_protos})){
		my $name = $this->__get_private()->{class} ;
		my $sa = Inline::Java::Protocol->CreateSignature($args) ;
		my $msg = "In method $method of class $name: Can't find any signature that matches " .
			"the arguments passed $sa.\nAvailable signatures are:\n"  ;
		my $i = 0 ;
		foreach my $proto (@{$prototypes}){
			my $s = Inline::Java::Protocol->CreateSignature($proto) ;
			$msg .= "\t$method$s\n" ;
			$msg .= "\t\terror was: $errors[$i]" ;
			$i++ ;
		}
		chomp $msg ;
		croak $msg ;
	}

	# Amongst the ones that matched, we need to select the one with the 
	# highest score. For now, the last one will do.
	
	my $nb = scalar(@{$matched_protos}) ;
	return ($matched_protos->[$nb - 1], $new_arguments->[$nb - 1]) ;
}


sub __isa {
	my $this = shift ;
	my $proto = shift ;

	eval {
		$this->__get_private()->{proto}->ISA($proto) ;
	} ;

	return $@ ;
}


sub __get_member {
	my $this = shift ;
	my $key = shift ;

	if ($this->__get_private()->{class} eq "Inline::Java::Object"){
		croak "Can't get member $key for an object that is not bound to Perl" ;
	}

	Inline::Java::debug("fetching member variable $key") ;

	my $inline = Inline::Java::get_INLINE($this->__get_private()->{module}) ;
	my $fields = $inline->get_fields($this->__get_private()->{java_class}) ;

	if ($fields->{$key}){
		my $proto = $fields->{$key}->{TYPE} ;

		my $ret = $this->__get_private()->{proto}->GetJavaMember($key, [$proto], [undef]) ;
		Inline::Java::debug("returning member (" . ($ret || '') . ")") ;
	
		return $ret ;
	}
	else{
		my $name = $this->__get_private()->{class} ;
		croak "No public member variable $key defined for class $name" ;
	}
}


sub __set_member {
	my $this = shift ;
	my $key = shift ;
	my $value = shift ;

	if ($this->__get_private()->{class} eq "Inline::Java::Object"){
		croak "Can't set member $key for an object that is not bound to Perl" ;
	}

	my $inline = Inline::Java::get_INLINE($this->__get_private()->{module}) ;
	my $fields = $inline->get_fields($this->__get_private()->{java_class}) ;

	if ($fields->{$key}){
		my $proto = $fields->{$key}->{TYPE} ;
		my $new_args = undef ;
		my $score = undef ;

		($new_args, $score) = Inline::Java::Class::CastArguments([$value], [$proto], $this->__get_private()->{module}) ;
		$this->__get_private()->{proto}->SetJavaMember($key, [$proto], $new_args) ;
	}
	else{
		my $name = $this->__get_private()->{class} ;
		croak "No public member variable $key defined for class $name" ;
	}
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

	my $name = (ref($this) ? $this->__get_private()->{class} : $this) ;
	if ($name eq "Inline::Java::Object"){
		croak "Can't call method $func_name on an object that is not bound to Perl" ;
	}

	croak "No public method $func_name defined for class $name" ;
}


sub DESTROY {
	my $this = shift ;
	
	my $knot = tied %{$this} ;
	if (! $knot){
		Inline::Java::debug("Destroying Inline::Java::Object::Tie") ;
		
		if (! Inline::Java::get_DONE()){
			eval {
				$this->__get_private()->{proto}->DeleteJavaObject($this) ;
			} ;
			my $name = $this->__get_private()->{class} ;
			croak "In method DESTROY of class $name: $@" if $@ ;
		}
		
		# Here we have a circular reference so we need to break it
		# so that the memory is collected.
		my $priv = $this->__get_private() ;
		my $proto = $priv->{proto} ;
		$priv->{proto} = undef ;
		$proto->{obj_priv} = undef ;
		$PRIVATES->{$this} = undef ;
	}
	else{
		# Here we can't untie because we still have a reference in $PRIVATES
		# untie %{$this} ;
		Inline::Java::debug("Destroying Inline::Java::Object") ;
	}
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

	my $inline = Inline::Java::get_INLINE($this->__get_private()->{module}) ;
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
}




######################## Static Member Methods ########################
package Inline::Java::Object::StaticMember ;
@Inline::Java::Object::StaticMember::ISA = qw(Tie::StdScalar) ;


use Tie::Scalar ;
use Carp ;

my $DUMMIES = {} ;


sub TIESCALAR {
	my $class = shift ;
	my $dummy = shift ;
	my $name = shift ;

	my $this = $class->SUPER::TIESCALAR(@_) ;

	$DUMMIES->{$this} = [$dummy, $name] ;

	return $this ;
}


sub STORE {
	my $this = shift ;
	my $value = shift ;

	my ($obj, $key) = @{$DUMMIES->{$this}} ;

	return $obj->__set_member($key, $value) ;
}


sub FETCH {
 	my $this = shift ;

	my ($obj, $key) = @{$DUMMIES->{$this}} ;

	return $obj->__get_member($key) ;
}


sub DESTROY {
	my $this = shift ;
}



######################## Private Object ########################
package Inline::Java::Object::Private ;

sub new {
	my $class = shift ;
	my $obj_class = shift ;
	my $java_class = shift ;
	my $inline = shift ;
	
	my $this = {} ;
	$this->{class} = $obj_class ;
	$this->{java_class} = $java_class ;
	$this->{module} = $inline->{modfname} ;
	$this->{proto} = new Inline::Java::Protocol($this, $inline) ;

	bless($this, $class) ;

	return $this ;
}


sub DESTROY {
	my $this = shift ;

	Inline::Java::debug("Destroying Inline::Java::Object::Private") ;
}




package Inline::Java::Object ;


1 ;


__DATA__

