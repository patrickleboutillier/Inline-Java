package Inline::Java::Class ;


use strict ;

$Inline::Java::Class::VERSION = '0.01' ;

use Carp ;


my $RANGE = {
	'java.lang.Byte' => {
		REGEXP => '^\d+$',
		MAX => 127,
		MIN => -128,
	},
	'java.lang.Short' => {
		REGEXP => '^\d+$',
		MAX => 32767,
		MIN => -32768,
	},
	'java.lang.Integer' => {
		REGEXP => '^\d+$',
		MAX => 2147483647,
		MIN => -2147483648,
	},
	'java.lang.Long' => {
		REGEXP => '^\d+$',
		MAX => 9223372036854775807,
		MIN => -9223372036854775808,
	},
	'java.lang.Float' => {
		REGEXP => '^\d+$',
		MAX => 3.4028235e38,
		MIN => 1.4e-45,
	},
	'java.lang.Double' => {
		REGEXP => '^\d+$',
		MAX => 1.7976931348623157e308,
		MIN => 4.9e-324,
	},
} ;
$RANGE->{byte} = $RANGE->{'java.lang.Byte'} ;
$RANGE->{short} = $RANGE->{'java.lang.Short'} ;
$RANGE->{int} = $RANGE->{'java.lang.Integer'} ;
$RANGE->{long} = $RANGE->{'java.lang.Long'} ;
$RANGE->{float} = $RANGE->{'java.lang.Float'} ;
$RANGE->{double} = $RANGE->{'java.lang.Double'} ;



# This method makes sure that the class we are asking for
# has the correct form for a Java class.
sub ValidateClass {
	my $class = shift ;

	if ($class !~ /^(\w+)((\.(\w+))+)?/){
		croak "Protocol: Invalid Java class name $class" ;
	}	

	return $class ;
}


sub CastArguments {
	my $class = shift ;
	my $method = shift ;
	my $args = shift ;
	my $proto = shift ;

	Inline::Java::debug_obj($args) ;
	Inline::Java::debug_obj($proto) ;

	if (scalar(@{$args}) != scalar(@{$proto})){
		croak "Wrong number of arguments for method $method of class $class" ;
	}

	my $ret = [] ;
	for (my $i = 0 ; $i < scalar(@{$args}) ; $i++){
		$ret->[$i] = CastArgument($class, $method, $args->[$i], $proto->[$i]) ;
	}

	return $ret ;
}


sub CastArgument {
	my $class = shift ;
	my $method = shift ;
	my $arg = shift ;
	my $proto = shift ;

	if ((ClassIsReference($proto))&&(! UNIVERSAL::isa($arg, "Inline::Java::Object"))){
		croak "Can't convert $arg to $proto in method $method of class $class" ;
	}
	if ((ClassIsPrimitive($proto))&&(ref($arg))){
		croak "Can't convert $arg to $proto in method $method of class $class" ;
	}

	if (ClassIsNumeric($proto)){
		if (! defined($arg)){
			return 0 ;
		}
		my $re = $RANGE->{$proto}->{REGEXP} ;
		my $min = $RANGE->{$proto}->{MIN} ;
		my $max = $RANGE->{$proto}->{MAX} ;
		Inline::Java::debug("min = $min, max = $max, val = $arg") ;
		if ($arg =~ /$re/){
			if (($arg >= $min)&&($arg <= $max)){
				return $arg ;
			}
			croak "$arg out of range for type $proto in method $method of class $class" ;			
		}
		croak "Can't convert $arg to $proto in method $method of class $class" ;
	}
	elsif (ClassIsChar($proto)){
		if (! defined($arg)){
			return "\0" ;
		}
		if (length($arg) == 1){
			return $arg ;
		}
		croak "Can't convert $arg to $proto in method $method of class $class" ;
	}
	elsif (ClassIsBool($proto)){
		if ($arg){
			return "true" ;
		}
		else{
			return "false" ;
		}
	}
	elsif (ClassIsString($proto)){
		if (! defined($arg)){
			return "" ;
		}
		return $arg ;
	}
	else{
		return $arg ;
	}
}


sub ClassIsNumeric {
	my $class = shift ;

	my @list = qw(
		java.lang.Byte
		java.lang.Short
		java.lang.Integer
		java.lang.Long
		java.lang.Float
		java.lang.Double
		byte
		short
		int
		long
		float
		double
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsString {
	my $class = shift ;

	my @list = qw(
		java.lang.String
		java.lang.StringBuffer
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsChar {
	my $class = shift ;

	my @list = qw(
		java.lang.Character
		char
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsBool {
	my $class = shift ;

	my @list = qw(
		java.lang.Bolean
		boolean
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsPrimitive {
	my $class = shift ;

	if ((ClassIsNumeric($class))||(ClassIsString($class))||(ClassIsChar($class))||(ClassIsBool($class))){
		return 1 ;
	}

	return 0 ;
}


sub ClassIsReference {
	my $class = shift ;

	if (ClassIsPrimitive($class)){
		return 0 ;
	}

	return 1 ;
}


1 ;



__DATA__

class InlineJavaClass {
	InlineJavaServer ijs ;
	InlineJavaProtocol ijp ;

	InlineJavaClass(InlineJavaServer _ijs, InlineJavaProtocol _ijp){
		ijs = _ijs ;
		ijp = _ijp ;
	}


	/*
		Makes sure a class exists
	*/
	Class ValidateClass(String name) throws InlineJavaException {
		try {
			Class c = Class.forName(name) ;
			return c ;
		}
		catch (ClassNotFoundException e){
			throw new InlineJavaException("Class " + name + " not found") ;
		}
	}

	/*
		This is the monster method that determines how to cast arguments
	*/
	Object [] CastArguments (String class_name, String method_name, Class [] params, ArrayList args) throws InlineJavaException {
		Object ret[] = new Object [params.length] ;
	
		// Used for exceptions
		String msg = " in method " + method_name + " of class " + class_name ;

		for (int i = 0 ; i < params.length ; i++){	
			// Here the args are all strings or objects (or undef)
			// we need to match them to the prototype.
			Class p = params[i] ;
			ijs.debug("    arg " + String.valueOf(i) + " of signature is " + p.getName()) ;

			ArrayList tokens = new ArrayList() ;
			StringTokenizer st = new StringTokenizer((String)args.get(i), ":") ;
			for (int j = 0 ; st.hasMoreTokens() ; j++){
				tokens.add(j, st.nextToken()) ;
			}
			if (tokens.size() == 1){
				tokens.add(1, "") ;
			}
			String type = (String)tokens.get(0) ;
			
			// We need to separate the primitive types from the 
			// reference types.
			boolean num = ClassIsNumeric(p) ;
			if ((num)||(ClassIsString(p))){
				if (type.equals("undef")){
					if (num){
						ijs.debug("  args is undef -> forcing to " + p.getName() + " 0") ;
						ret[i] = ijp.CreateObject(p, new Object [] {"0"}) ;
					}
					else{
						ijs.debug("  args is undef -> forcing to " + p.getName() + " ''") ;
						ret[i] = ijp.CreateObject(p, new Object [] {""}) ;
					}
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = ijp.pack((String)tokens.get(1)) ;
					ijs.debug("  args is scalar -> forcing to " + p.getName()) ;
					try	{							
						ret[i] = ijp.CreateObject(p, new Object [] {arg}) ;
						ijs.debug("    result is " + ret[i].toString()) ;
					}
					catch (NumberFormatException e){
						throw new InlineJavaCastException("Can't convert " + arg + " to " + p.getName() + msg) ;
					}
				}
				else{
					throw new InlineJavaCastException("Can't convert reference to " + p.getName() + msg) ;
				}
			}
			else if (ClassIsBool(p)){
				if (type.equals("undef")){
					ijs.debug("  args is undef -> forcing to bool false") ;
					ret[i] = new Boolean("false") ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = ijp.pack(((String)tokens.get(1)).toLowerCase()) ;
					ijs.debug("  args is scalar -> forcing to bool") ;
					if ((arg.equals(""))||(arg.equals("0"))){
						arg = "false" ;
					}
					else{
						arg = "true" ;
					}
					ret[i] = new Boolean(arg) ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else{
					throw new InlineJavaCastException("Can't convert reference to " + p.getName() + msg) ;
				}
			}
			else if (ClassIsChar(p)){
				if (type.equals("undef")){
					ijs.debug("  args is undef -> forcing to char '\0'") ;
					ret[i] = new Character('\0') ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = ijp.pack((String)tokens.get(1)) ;
					ijs.debug("  args is scalar -> forcing to char") ;
					char c = '\0' ;
					if (arg.length() == 1){
						c = arg.toCharArray()[0] ;
					}
					else if (arg.length() > 1){
						throw new InlineJavaCastException("Can't convert " + arg + " to " + p.getName() + msg) ;
					}
					ret[i] = new Character(c) ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else{
					throw new InlineJavaCastException("Can't convert reference to " + p.getName() + msg) ;
				}
			}
			else {
				ijs.debug("  class " + p.getName() + " is reference") ;
				// We know that what we expect here is a real object
				if (type.equals("undef")){
					ijs.debug("  args is undef -> forcing to null") ;
					ret[i] = null ;
				}
				else if (type.equals("scalar")){
					// Here if we need a java.lang.Object.class, it's probably
					// because we can store anything, so we use a String object.
					if (p == java.lang.Object.class){
						String arg = ijp.pack((String)tokens.get(1)) ;
						ret[i] = arg ;
					}
					else{
						throw new InlineJavaCastException("Can't convert primitive type to " + p.getName() + msg) ;
					}
				}
				else{
					// We need an object and we got an object...
					ijs.debug("  class " + p.getName() + " is reference") ;

					String c_name = (String)tokens.get(1) ;
					String objid = (String)tokens.get(2) ;

					Class c = ValidateClass(c_name) ;
					// We need to check if c extends p
					Class parent = c ;
					boolean got_it = false ;
					while (parent != null){
						ijs.debug("    parent is " + parent.getName()) ;
						if (parent == p){
							got_it = true ;
							break ;
						}
						parent = parent.getSuperclass() ;
					}

					if (got_it){
						ijs.debug("    " + c.getName() + " is a kind of " + p.getName() + msg) ;
						// get the object from the hash table
						Integer oid = new Integer(objid) ;
						Object o = ijs.objects.get(oid) ;
						if (o == null){
							throw new InlineJavaException("Object " + oid.toString() + " of type " + c_name + " is not in object table " + msg) ;
						}
						ret[i] = o ;
					}
					else{
						throw new InlineJavaCastException("Can't cast a " + c.getName() + " to a " + p.getName() + msg) ;
					}
				}
			}			
		}

		return ret ;
	}



	/*
		Finds the wrapper class for the passed primitive type.
	*/
	Class FindWrapper (Class p){
		Class [] list = {
			byte.class,
			short.class,
			int.class,
			long.class,
			float.class,
			double.class,
			boolean.class,
			char.class,
		} ;
		Class [] listw = {
			java.lang.Byte.class,
			java.lang.Short.class,
			java.lang.Integer.class,
			java.lang.Long.class,
			java.lang.Float.class,
			java.lang.Double.class,
			java.lang.Boolean.class,
			java.lang.Character.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			if (p == list[i]){
				return listw[i] ;
			}
		}

		return p ;
	}


	boolean ClassIsPrimitive (Class p){
		String name = p.getName() ;

		if ((ClassIsNumeric(p))||(ClassIsString(p))||(ClassIsChar(p))||(ClassIsBool(p))){
			return true ;
		}

		ijs.debug("  class " + name + " is reference") ;
		return false ;
	}


	/*
		Determines if class is of numerical type.
	*/
	boolean ClassIsNumeric (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.Byte.class,
			java.lang.Short.class,
			java.lang.Integer.class,
			java.lang.Long.class,
			java.lang.Float.class,
			java.lang.Double.class,
			byte.class,
			short.class,
			int.class,
			long.class,
			float.class,
			double.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			ijs.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive numeric") ;
				return true ;
			}
		}

		return false ;
	}


	/*
		Class is String or StringBuffer
	*/
	boolean ClassIsString (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.String.class,
			java.lang.StringBuffer.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			ijs.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive string") ;
				return true ;
			}
		}

		return false ;
	}


	/*
		Class is Char
	*/
	boolean ClassIsChar (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.Character.class,
			char.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			ijs.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive char") ;
				return true ;
			}
		}

		return false ;
	}


	/*
		Class is Bool
	*/
	boolean ClassIsBool (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.Boolean.class,
			boolean.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			ijs.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive bool") ;
				return true ;
			}
		}

		return false ;
	}

	
	/*
		Determines if a class is not of a primitive type or of a 
		wrapper class.
	*/
	boolean ClassIsReference (Class p){
		String name = p.getName() ;

		if (ClassIsPrimitive(p)){
			return false ;
		}

		ijs.debug("  class " + name + " is reference") ;

		return true ;
	}
}
