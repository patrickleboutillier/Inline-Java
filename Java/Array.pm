package Inline::Java::Array ;
@Inline::Java::Array::ISA = qw(Tie::StdArray) ;


use strict ;

$Inline::Java::Array::VERSION = '0.01' ;

use Inline::Java::Object ;
use Tie::Array ;
use Carp ;


# This class is instantiated  to do the conversion between a perl
# array and a Java array. It can take a Perl array, validate it, fill it
# and flatten it or order to send to Java to get an object created.
#
# In the reverse sense, it takes a flattened array from Java and constructs
# a structure of blessed perl arrays that serves as an interface to the 
# array. 
#
# This class in not meant to be instantiated by the user.


# Here we will store each of the arrays in order to be able
# to add extra data.
my $ARRAYS = {} ;

sub new {
	my $class = shift ;
	my $java_class = shift ;
	my $inline = shift ;

	if (! Inline::Java::Class::ClassIsArray($java_class)){
		croak "Can't create Inline::Java::Array object for non-array class $java_class" ;
	}

	my @this = [] ;
	tie @this, 'Inline::Java::Array' ;
	bless (\@this, $class) ;

	my $this = \@this ;
	$ARRAYS->{$this} = {
		array => $this,
		class => $class,
		java_class => $java_class,
		module => $inline->{modfname},
		map => {},
	} ;

	# The first thing we want to do is figure out what kind of array we want,
	# and how many dimensions it should have.
	$this->__analyze_array_class() ;

	# Inline::Java::debug_obj($ARRAYS->{$this}) ;

	return $this ;
}


sub __init_from_array {
	my $this = shift ;
	my $ref = shift ;
	my $inline = shift ;
	my $level = shift ;

	$this->__validate_array($ref, 1) ;

	# Now that we now that this array is valid, we need to carry
	# over the stuff in $ref into ourselves.
	# sub arrays into array_objects
	$this->__import_from_array($ref, $inline, $level) ;

	if (! $level){
		Inline::Java::debug_obj($ARRAYS->{$this}) ;
	}
}


sub __import_from_array {
	my $this = shift ;
	my $ref = shift ;
	my $inline = shift ;
	my $level = shift ;

	my $extra = $ARRAYS->{$this} ;

	for (my $i = 0 ; $i < scalar(@{$ref}) ; $i++){
		my $elem = $ref->[$i] ;

		if (UNIVERSAL::isa($elem, "ARRAY")){
			my $java_class = $extra->{java_class} ;

			# We need top drop the array by 1 dimension
			$java_class =~ s/^\[// ;
			my $obj = new Inline::Java::Array($java_class, $inline) ;
			$obj->__init_from_array($elem, $inline, $level + 1) ;
			$elem = $obj ;
		}
		my $nb = scalar(@{$this}) ;
		$this->[$nb] = $elem ;
	}
}


sub __init_from_flat {
	my $this = shift ;
	my $dims = shift ;
	my $list = shift ;
	my $inline = shift ;
	my $level = shift ;

	my $extra = $ARRAYS->{$this} ;
	my $nb_list = scalar(@{$list}) ;
	my $parts = $dims->[0] ;

	my $req_nb_elem = 1 ;
	foreach my $d (@{$dims}){
		$req_nb_elem *= $d ;
	}
	if ($req_nb_elem != $nb_list){
		my $ds = "[" . join("][", @{$dims}) . "]" ;
		croak "Corrupted array: $ds should contain $req_nb_elem elements, has $nb_list" ;
	}

	for (my $i = 0 ; $i < $parts ; $i++){
		my $elem = undef ;
		if (scalar(@{$dims}) == 1){
			# We are at the bottom of the list.
			$elem = $list->[$i] ;
		}
		else{
			my $nb_elems = $nb_list / $parts ;
			my @sub = splice(@{$list}, 0, $nb_elems) ;

			my $java_class = $extra->{java_class} ;
			$java_class =~ s/^\[// ;

			my @dims = @{$dims} ;
			shift @dims ;
			my $obj = new Inline::Java::Array($java_class, $inline) ;
			$obj->__init_from_flat(\@dims, \@sub, $inline, $level + 1) ;
			$elem = $obj ;
		}
		my $nb = scalar(@{$this}) ;
		$this->[$nb] = $elem ;
	}

	if (! $level){
		Inline::Java::debug_obj($ARRAYS->{$this}) ;
	}
}


# Checks if the contents of the Array match the ones prescribed
# by the Java prototype.
sub __analyze_array_class {
	my $this = shift ;
	
	my $extra = $ARRAYS->{$this} ;
	my $java_class = $extra->{java_class} ;

	my ($depth_str, $type, $class) = Inline::Java::Class::ValidateClassSplit($java_class) ;
	$depth_str =~ /^(\[+)/ ;
	my $depth = length($depth_str) ;

	my %map = (
		B => 'byte',
		S => 'short',
		I => 'int',
		J => 'long',
		F => 'float',
		D => 'double',
		C => 'char',
		Z => 'boolean',
		L => $class,
	) ;

	my $pclass = $map{$type} ;
	if (! $pclass){
		croak "Can't determine array type for $java_class" ;
	}

	$extra->{req_element_class} = $pclass ;
	$extra->{req_nb_dim} = $depth ;

	return ;
}


# This method makes sure that we have a valid array that
# can be used in a Java function. It will return an array
# That contains either all scalars or all object references
# at the lowest level.
sub __validate_array {
	my $this = shift ;
	my $ref = shift ;
	my $fill = shift ;
	my $level = shift || 0 ;

	if (! UNIVERSAL::isa($ref, "ARRAY")){
		# We must start with an array of some kind...
		croak "$ref is not an array reference" ;
	}

	$this->__validate_elements($ref, $level) ;

	foreach my $elem (@{$ref}){
		if (UNIVERSAL::isa($elem, "ARRAY")){
			$this->__validate_array($elem, $fill, $level + 1) ;
		}
	}

	if ($fill){
		$this->__fill_array($ref, $level) ;
	}

	my $extra = $ARRAYS->{$this} ;
	my $map = $extra->{map} ;
	if (! $level){
		my @levels = (sort {$a <=> $b} keys %{$map}) ;
		my $nbl = scalar(@levels) ;

		my $last = $levels[$nbl - 1] ;
		my @dims = () ;
		my $max_cells = 1 ;
		foreach my $l (@levels){
			push @dims, ($map->{$l}->{max} || 0) ;
			$max_cells *= $map->{$l}->{max} ;
		}
		my $nb_cells = ($map->{$last}->{count} || 0) ;
		# Inline::Java::debug("array is [" . join("][", @dims) . "]") ;
		# Inline::Java::debug("array has         $nb_cells declared cells") ;
		# Inline::Java::debug("array should have $max_cells declared cells") ;
		$extra->{dim} = \@dims ;
		$extra->{nb_dim} = scalar(@dims) ;

		if ($extra->{nb_dim} != $extra->{req_nb_dim}){
			croak "Java array should have $extra->{req_nb_dim} instead of " .
				"$extra->{nb_dim} dimensions" ;
		}
		
		# Inline::Java::debug_obj($extra) ;
	}
}


# Makes sure that all the elements are of the same type.
sub __validate_elements {
	my $this = shift ;
	my $ref = shift ;
	my $level = shift ;
	
	my $extra = $ARRAYS->{$this} ;
	my $map = $extra->{map} ;

	my $cnt = scalar(@{$ref}) ;
	my $max = $map->{$level}->{max} || 0 ;

	if ($cnt > $max){
		$map->{$level}->{max} = $cnt ;
	}

	foreach my $elem (@{$ref}){		
		if (defined($elem)){
			if (ref($elem)){
				if (UNIVERSAL::isa($elem, "ARRAY")){
					$this->__check_map("ARRAY", $level) ;
				}
				elsif (UNIVERSAL::isa($elem, "Inline::Java::Object")){
					$this->__check_map("Inline::Java::Object", $level) ;
					$this->__cast_array_argument($elem) ;
					push @{$map->{$level}->{list}}, $elem ;
				}
				else{
					croak "A Java array can only contain scalars, Java objects or array references" ;
				}
			}
			else{
				$this->__check_map("SCALAR", $level) ;
				$this->__cast_array_argument($elem) ;
				push @{$map->{$level}->{list}}, $elem ;
			}
		}
	}
}


sub __check_map {
	my $this = shift ;
	my $type = shift ;
	my $level = shift ;

	my $extra = $ARRAYS->{$this} ;
	my $map = $extra->{map} ;

	if (! exists($map->{$level}->{type})){
		$map->{$level}->{type} = $type ;
	}
	elsif ($map->{$level}->{type} ne $type){
		croak "Java array contains mixed types in dimension $level ($type != $map->{$level}->{type})" ;
	}
	$map->{$level}->{count}++ ;
}


sub __cast_array_argument {
	my $this = shift ;
	my $ref = shift ;

	my $extra = $ARRAYS->{$this} ;
	my $element_class = $extra->{req_element_class} ;

	Inline::Java::Class::CastArgument($ref, $element_class) ;
}


# Makes sure that all the dimensions of the array have the same number of elements
sub __fill_array {
	my $this = shift ;
	my $ref = shift ;
	my $level = shift ;

	my $extra = $ARRAYS->{$this} ;
	my $map = $extra->{map} ;

	my $max = $map->{$level}->{max} ;
	my $nb = scalar(@{$ref}) ;

	foreach my $elem (@{$ref}){
		if ($map->{$level}->{type} eq "ARRAY"){
			if (! defined($elem)){
				$elem = [] ;
			}
		}
	}

	if ($nb < $max){
		# We must stuff...
		for (my $i = $nb ; $i < $max ; $i++){
			if ($map->{$level}->{type} eq "ARRAY"){
				my $elem = [] ;
				push @{$ref}, $elem ;
				push @{$map->{$level}->{list}}, $elem ;
			}
			else{
				push @{$ref}, undef ;
				push @{$map->{$level}->{list}}, undef ;
			}			
		}
	}
}


sub __flatten_array {
	my $this = shift ;
	my $level = shift ;

	my $extra = $ARRAYS->{$this} ;
	my $dim = $extra->{dim} ;
	my $last = scalar(@{$dim} - 1) ;
	my $list = $extra->{map}->{$last}->{list} ;
	my $nb_elem = scalar(@{$list}) ;
		
	my $req_nb_elem = 1 ;
	foreach my $d (@{$dim}){
		$req_nb_elem *= $d ;
	}

	if ($req_nb_elem != $nb_elem){
		my $ds = "[" . join("][", @{$dim}) . "]" ;
		croak "Corrupted array: $ds should contain $req_nb_elem elements, has $nb_elem" ;
	}

	my $ret = [$dim, $list] ;

	Inline::Java::debug_obj($ret) ;

	return $ret ;
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

	croak "Can't call method $func_name on Java arrays (can't call any methods for that matter)" ;
}


sub DESTROY {
	my $this = shift ;

	# I think here we should to something similar to Object, to get the object
	# destroyed.
}



######################## Array methods ########################


sub TIEARRAY {
	my $class = shift ;

	return $class->SUPER::TIEARRAY(@_) ;
}


sub FETCHSIZE { 
 	my $this = shift ;

	return $this->SUPER::FETCHSIZE() ;
}             


sub STORE { 
 	my $this = shift ;
 	my $idx = shift ;
 	my $s = shift ;

	return $this->SUPER::STORE($idx, $s) ;
} 


sub FETCH { 
 	my $this = shift ;
 	my $idx = shift ;

	return $this->SUPER::FETCH($idx) ;
}


sub EXISTS {
 	my $this = shift ;
 	my $idx = shift ;

	return $this->SUPER::EXISTS($idx) ;
}


sub STORESIZE {
 	my $this = shift ;
 	my $size = shift ;

	croak "Operation STORESIZE not supported on Java array" ;
}


sub CLEAR {
 	my $this = shift ;

	croak "Operation CLEAR not supported on Java array" ;
}


sub POP {
 	my $this = shift ;

	croak "Operation POP not supported on Java array" ;
}


sub PUSH {
 	my $this = shift ;
	my @list = @_ ;

	croak "Operation PUSH not supported on Java array" ;
}


sub SHIFT {
 	my $this = shift ;

	croak "Operation SHIFT not supported on Java array" ;
} 


sub UNSHIFT {
 	my $this = shift ;
	my @list = @_ ;

	croak "Operation UNSHIFT not supported on Java array" ;
} 


sub DELETE {
 	my $this = shift ;
	my $idx = shift ;

	croak "Operation DELETE not supported on Java array" ;
}

# sub TIEARRAY  { bless [], $_[0] }
# sub FETCHSIZE { scalar @{$_[0]} }             
#sub STORESIZE { $#{$_[0]} = $_[1]-1 }  
#sub STORE     { $_[0]->[$_[1]] = $_[2] }
#sub FETCH     { $_[0]->[$_[1]] }
#sub CLEAR     { @{$_[0]} = () }
#sub POP       { pop(@{$_[0]}) } 
#sub PUSH      { my $o = shift; push(@$o,@_) }
#sub SHIFT     { shift(@{$_[0]}) } 
#sub UNSHIFT   { my $o = shift; unshift(@$o,@_) } 
#sub EXISTS    { exists $_[0]->[$_[1]] }
#sub DELETE    { delete $_[0]->[$_[1]] }

