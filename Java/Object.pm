package Inline::Java::private::Object ;
@Inline::Java::private::Object::ISA = qw(Tie::StdHash) ;


use strict ;

use Carp ;
use Data::Dumper ;
use Tie::Hash ;
use Inline::Java::private::Protocol ;



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
	my $pkg = shift ;
	my $module = shift ;
	my $objid = shift ;
	my @args = @_ ;

	my %this = () ;
	tie %this, 'Inline::Java::private::Object' ;
	bless (\%this, $class) ;

	my $this = \%this ;
	$this->{private} = {} ;
	$this->{private}->{class} = $java_class ;
	$this->{private}->{pkg} = $pkg ;
	$this->{private}->{proto} = new Inline::Java::private::Protocol($this->{private}, $module) ;
	if ($objid <= 0){
		$this->{private}->{proto}->CreateJavaObject($java_class, @args) ;
		Inline::Java::debug("Object created in perl script ($class):") ;
	}
	else{
		$this->{private}->{id} = $objid ;
		Inline::Java::debug("Object created in java ($class):") ;
	}
	Inline::Java::debug_obj($this->private()) ;

	return $this ;
}


sub __validate_prototype {
	return undef ;
}


sub private {
	my $this = shift ;

	return $this->{private} ;
}


# Here an object in destroyed
sub DESTROY {
	my $this = shift ;

	if (! $this->{private}->{deleted}){
		$this->{private}->{deleted} = 1 ;
		$this->{private}->{proto}->DeleteJavaObject() ;
	}
}


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

	my $priv = $this->FETCH("private") ;
	$priv->{proto}->SetMember($key, $value) ;
}


sub FETCH {
	my $this = shift ;
	my $key = shift ;

	if ($key eq "private"){
		return $this->SUPER::FETCH($key) ;
	}

	my $priv = $this->FETCH("private") ;
	return $priv->{proto}->GetMember($key) ;
}


sub FIRSTKEY { 
	croak "Operation FIRSTKEY not supported on Java object" ;
}


sub NEXTKEY { 
	croak "Operation NEXTKEY not supported on Java object" ;
}


sub EXISTS { 
	croak "Operation EXISTS not supported on Java object" ;
}


sub DELETE { 
	croak "Operation DELETE not supported on Java object" ;
}


sub CLEAR { 
	croak "Operation CLEAR not supported on Java object" ;
}


# sub AUTOLOAD {
# 	my $this = shift ;
# 	my @args = @_ ;

# 	use vars qw($AUTOLOAD) ;
# 	my $func_name = $AUTOLOAD ;
# 	# Strip package from $func_name, Java will take of finding the correct
# 	# method.
# 	$func_name =~ s/^(.*)::// ;

# 	Inline::Java::debug("$func_name") ;

# 	$this->{private}->{proto}->CallJavaMethod($func_name, @args) ;
# }



1 ;
