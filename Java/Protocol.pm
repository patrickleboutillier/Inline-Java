package Inline::Java::Protocol ;


use strict ;

$Inline::Java::Protocol::VERSION = '0.40' ;

use Inline::Java::Object ;
use Inline::Java::Array ;
use Carp ;


sub new {
	my $class = shift ;
	my $obj = shift ;
	my $inline = shift ;

	my $this = {} ;
	$this->{obj_priv} = $obj || {} ;
	$this->{module} = $inline->get_api('modfname') ;

	bless($this, $class) ;
	return $this ;
}


sub ServerType {
	my $this = shift ;

	Inline::Java::debug(3, "getting server type") ;

	my $data = "server_type" ;

	return $this->Send($data, 1) ;
}


sub Report {
	my $this = shift ;
	my $classes = shift ;

	Inline::Java::debug(3, "reporting on $classes") ;

	my $data = join(" ", 
		"report", 
		$this->ValidateArgs([$classes]),
	) ;

	return $this->Send($data, 1) ;
}


sub ISA {
	my $this = shift ;
	my $proto = shift ;

	my $class = $this->{obj_priv}->{java_class} ;

	Inline::Java::debug(3, "checking if $class is a $proto") ;

	my $data = join(" ", 
		"isa", 
		Inline::Java::Class::ValidateClass($class),
		Inline::Java::Class::ValidateClass($proto),
	) ;

	return $this->Send($data, 1) ;
}


sub ObjectCount {
	my $this = shift ;

	Inline::Java::debug(3, "getting object count") ;

	my $data = join(" ", 
		"obj_cnt", 
	) ;

	return $this->Send($data, 1) ;
}


# Called to create a Java object
sub CreateJavaObject {
	my $this = shift ;
	my $class = shift ;
	my $proto = shift ;
	my $args = shift ;

	Inline::Java::debug(3, "creating object new $class" . $this->CreateSignature($args)) ; 	

	my $data = join(" ", 
		"create_object", 
		Inline::Java::Class::ValidateClass($class),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

	return $this->Send($data, 1) ;
}


# Calls a Java method.
sub CallJavaMethod {
	my $this = shift ;
	my $method = shift ;
	my $proto = shift ;
	my $args = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug(3, "calling object($id).$method" . $this->CreateSignature($args)) ;

	my $data = join(" ", 
		"call_method", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMethod($method),
		$this->CreateSignature($proto, ","),
		$this->ValidateArgs($args),
	) ;

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
	Inline::Java::debug(3, "setting object($id)->{$member} = " . ($arg->[0] || '')) ;
	my $data = join(" ", 
		"set_member", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMember($member),
		Inline::Java::Class::ValidateClass($proto->[0]),
		$this->ValidateArgs($arg),
	) ;

	return $this->Send($data) ;
}


# Gets a member variable.
sub GetJavaMember {
	my $this = shift ;
	my $member = shift ;
	my $proto = shift ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug(3, "getting object($id)->{$member}") ;

	my $data = join(" ", 
		"get_member", 
		$id,
		Inline::Java::Class::ValidateClass($class),
		$this->ValidateMember($member),
		Inline::Java::Class::ValidateClass($proto->[0]),
		"undef:",
	) ;

	return $this->Send($data) ;
}


# Deletes a Java object
sub DeleteJavaObject {
	my $this = shift ;
	my $obj = shift ;

	if (defined($this->{obj_priv}->{id})){
		my $id = $this->{obj_priv}->{id} ;
		my $class = $this->{obj_priv}->{java_class} ;

		Inline::Java::debug(3, "deleting object $obj $id ($class)") ;

		my $data = join(" ", 
			"delete_object", 
			$id,
		) ;

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
	my $callback = shift ;

	my @ret = () ;
	foreach my $arg (@{$args}){
		if (! defined($arg)){
			push @ret, "undef:" ;
		}
		elsif (ref($arg)){
			if ((! UNIVERSAL::isa($arg, "Inline::Java::Object"))&&(! UNIVERSAL::isa($arg, "Inline::Java::Array"))){
				if (! $callback){
					croak "A Java method or member can only have Java objects, Java arrays or scalars as arguments" ;
				}
				else{
					croak "A Java callback function can only return Java objects, Java arrays or scalars" ;
				}
			}

			my $obj = $arg ;
			if (UNIVERSAL::isa($arg, "Inline::Java::Array")){
				$obj = $arg->__get_object() ; 
			}
			my $class = $obj->__get_private()->{java_class} ;
			my $id = $obj->__get_private()->{id} ;
			push @ret, "object:$class:$id" ;
		}
		else{
			push @ret, "scalar:" . encode($arg) ;
		}
	}

	return @ret ;
}


sub CreateSignature {
	my $this = shift ;
	my $proto = shift ;
	my $del = shift || ", " ;

	my @p = map {$_ || ''} @{$proto} ;

	return "(" . join($del, @p) . ")" ;
}


# This actually sends the request to the Java program. It also takes
# care of registering the returned object (if any)
sub Send {
	my $this = shift ;
	my $data = shift ;
	my $const = shift ;

	my $inline = Inline::Java::get_INLINE($this->{module}) ;
	my $resp = Inline::Java::__get_JVM()->process_command($inline, $data) ;

	if ($resp =~ /^error scalar:([\d.-]*)$/){
		my $msg = decode($1) ;
		Inline::Java::debug(3, "packet recv error: $msg") ;
		croak $msg ;
	}
	elsif ($resp =~ s/^ok //){
		return $this->DeserializeObject($const, $resp) ;
	}

	croak "Malformed response from server: $resp" ;
}


sub DeserializeObject {
	my $this = shift ;
	my $const = shift ;
	my $resp = shift ;

	if ($resp =~ /^scalar:([\d.-]*)$/){
		return decode($1) ; 
	}
	elsif ($resp =~ /^undef:$/){
		return undef ;
	}
	elsif ($resp =~ /^object:([01]):(\d+):(.*)$/){
		# Create the Perl object wrapper and return it.
		my $thrown = $1 ;
		my $id = $2 ;
		my $class = $3 ;

		if ($thrown){
			# If we receive a thrown object, we jump out of 'constructor
			# mode' and process the returned object.
			$const = 0 ;
		}

		if ($const){
			$this->{obj_priv}->{java_class} = $class ;
			$this->{obj_priv}->{id} = $id ;

			return undef ;
		}
		else{
			my $inline = Inline::Java::get_INLINE($this->{module}) ;
			my $pkg = $inline->get_api('pkg') ;

			my $obj = undef ;
			my $elem_class = $class ;

			Inline::Java::debug(3, "checking if stub is array...") ;
			if (Inline::Java::Class::ClassIsArray($class)){
				my @d = Inline::Java::Class::ValidateClassSplit($class) ;
				$elem_class = $d[2] ;
			}


			my $perl_class = "Inline::Java::Object" ;
			if ($elem_class){
				# We have a real class or an array of real classes
				$perl_class = Inline::Java::java2perl($pkg, $elem_class) ;
				if (Inline::Java::Class::ClassIsReference($elem_class)){
					if (! Inline::Java::known_to_perl($pkg, $elem_class)){
						if (($thrown)||($inline->get_java_config('AUTOSTUDY'))){
							$inline->_study([$elem_class]) ;
						}
						else{	
							# Object is not known to Perl, it lives as a 
							# Inline::Java::Object
							$perl_class = "Inline::Java::Object" ;
						}
				 	}
				}
			}
			else{
				# We should only get here if an array of primitives types
				# was returned, and there is nothing to do since
				# the block below will handle it.
			}

			if (Inline::Java::Class::ClassIsArray($class)){
				Inline::Java::debug(3, "creating array object...") ;
				$obj = Inline::Java::Object->__new($class, $inline, $id) ;
				$obj = new Inline::Java::Array($obj) ;
				Inline::Java::debug(3, "array object created...") ;
			}
			else{
				$obj = $perl_class->__new($class, $inline, $id) ;
			}

			if ($thrown){
				Inline::Java::debug(3, "throwing stub...") ;
				my ($msg, $score) = $obj->__isa('IJPerlException') ;
				if ($msg){
					die $obj ;
				}
				else{
					die $obj->GetObject() ;
				}
			}
			else{
				Inline::Java::debug(3, "returning stub...") ;
				return $obj ;
			}
		}
	}
	else{
		croak "Malformed response from server: $resp" ;
	}
}


sub encode {
	my $s = shift ;

	return join(".", unpack("C*", $s)) ;
}


sub decode {
	my $s = shift ;

	return pack("C*", split(/\./, $s)) ;
}


sub DESTROY {
	my $this = shift ;

	Inline::Java::debug(4, "destroying Inline::Java::Protocol") ;
}



1 ;



__END__


RCS file: /cvsroot/inline-java/Inline-Java/Java/Protocol.pm,v
retrieving revision 1.29
diff -r1.29 Protocol.pm
37a38,51
> sub AddClassPath {
>       my $this = shift ;
>       my @paths = @_ ;
>
>       Inline::Java::debug(3, "adding to class path (" .
>               join(", ", map {"'" . $_ . "'"} @paths) . ")") ;
>
>       my $data = "add_classpath " . join(" ", map {encode($_)} @paths) ;
>
>       return $this->Send($data, 1) ;
> }
>
>
>
460a475,477
>               else if (c.equals("add_classpath")){
>                       AddClassPath(st) ;
>               }
553a571,580
>       }
>
>
>       void AddClassPath(StringTokenizer st) throws InlineJavaException {
>               while (st.hasMoreTokens()){
>                       String path = decode(st.nextToken()) ;
>                       InlineJavaServer.instance.AddClassPath(path) ;
>               }
>
>               SetResponse(null) ;
