package Inline::Java::Protocol ;


use strict ;

$Inline::Java::Protocol::VERSION = '0.01' ;

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


# Called to create a Java object
sub CreateJavaObject {
	my $this = shift ;
	my $class = shift ;
	my @args = @_ ;

	Inline::Java::debug("creating object new $class(" . join(", ", @args) . ")") ; 	

	my $data = join(" ", 
		"create_object", 
		$this->ValidateClass($class),
		$this->ValidateArgs(@args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;		

	return $this->Send($data, 1) ;
}


# Called to call a static Java method
sub CallStaticJavaMethod {
	my $this = shift ;
	my $class = shift ;
	my $method = shift ;
	my @args = @_ ;

	Inline::Java::debug("calling $class.$method(" . join(", ", @args) . ")") ;

	my $data = join(" ", 
		"call_static_method", 
		$this->ValidateClass($class),
		$this->ValidateMethod($method),
		$this->ValidateArgs(@args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;		

	return $this->Send($data) ;
}


# Calls a regular Java method.
sub CallJavaMethod {
	my $this = shift ;
	my $method = shift ;
	my @args = @_ ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{java_class} ;
	Inline::Java::debug("calling object($id).$method(" . join(", ", @args) . ")") ;

	my $data = join(" ", 
		"call_method", 
		$id,		
		$this->ValidateClass($class),
		$this->ValidateMethod($method),
		$this->ValidateArgs(@args),
	) ;

	Inline::Java::debug("  packet sent is $data") ;		

	return $this->Send($data) ;
}


# Deletes a Java object
sub DeleteJavaObject {
	my $this = shift ;

	if (defined($this->{obj_priv}->{id})){
		my $id = $this->{obj_priv}->{id} ;
		my $class = $this->{obj_priv}->{java_class} ;

		Inline::Java::debug("deleting object $this $id ($class)") ;

		my $data = join(" ", 
			"delete_object", 
			$id,
		) ;

		Inline::Java::debug("  packet sent is $data") ;		

		$this->Send($data) ;
	}
}


# This method makes sure that the class we are asking for
# has the correct form for a Java class.
sub ValidateClass {
	my $this = shift ;
	my $class = shift ;

	if ($class !~ /^(\w+)((\.(\w+))+)?/){
		croak "Protocol: Invalid Java class name $class" ;
	}	

	return $class ;
}


# This method makes sure that the method we are asking for
# has the correct form for a Java method.
sub ValidateMethod {
	my $this = shift ;
	my $method = shift ;

	if ($method !~ /^(\w+)$/){
		croak "Protocol: Invalid Java method name $method" ;
	}	

	return $method ;
}


# Validates the arguments to be used in a method call.
sub ValidateArgs {
	my $this = shift ;
	my @args = @_ ;

	my @ret = () ;
	foreach my $arg (@args){
		if (! defined($arg)){
			push @ret, "undef:" ;
		}
		elsif (ref($arg)){
			if (! UNIVERSAL::isa($arg, "Inline::Java::Object")){
				croak "Protocol: A Java method can only have Java objects or scalars as arguments" ;
			}
			my $class = $arg->{private}->{java_class} ;
			my $id = $arg->{private}->{id} ;
			push @ret, "object:$class:$id" ;
		}
		else{
			push @ret, "scalar:" . join(".", unpack("C*", $arg)) ;
		}
	}

	return @ret ;
}


# This actually sends the request to the Java program. It also takes
# care of registering the returned object (if any)
sub Send {
	my $this = shift ;
	my $data = shift ;
	my $const = shift ;

	my $inline = $Inline::Java::INLINE->{$this->{module}} ;
	my $sock = $inline->{Java}->{socket} ;
	print $sock $data . "\n" or
		croak "Can't send packet over socket: $!" ;

	my $resp = <$sock> ;
	Inline::Java::debug("  packet recv is $resp") ;

	if (! $resp){
		croak "Can't receive packet over socket: $!" ;
	}
	elsif ($resp =~ /^error scalar:([\d.]*)$/){
		croak pack("C*", split(/\./, $1)) ;
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
		}
		else{
			my $perl_class = $class ;
			$perl_class =~ s/[.\$]/::/g ;
			my $pkg = $inline->{pkg} ;
			$perl_class = $pkg . "::" . $perl_class ;
			Inline::Java::debug($perl_class) ;

			my $obj = undef ;
			if (defined(${$perl_class . "::" . "EXISTS"})){
				Inline::Java::debug("  returned class exists!") ;
				$obj = $perl_class->__new($class, $inline, $id) ;
			}
			else{
				Inline::Java::debug("  returned class doesn't exist!") ;
				$obj = Inline::Java::Object->__new($class, $inline, $id) ;
			}
			return $obj ;
		}
	}
}


1 ;



__DATA__


/*
	This is where most of the work of Inline Java is done. Here determine
	the request type and then we proceed to serve it.
*/
class InlineJavaProtocol {
	InlineJavaServer ijs ;
	String cmd ;
	String response ;

	InlineJavaProtocol(InlineJavaServer _ijs, String _cmd) {
		ijs = _ijs ;
		cmd = _cmd ;
	}


	/*
		Starts the analysis of the command line
	*/
	void Do() throws InlineJavaException {
		StringTokenizer st = new StringTokenizer(cmd, " ") ;
		String c = st.nextToken() ;

		if (c.equals("call_static_method")){
			CallStaticJavaMethod(st) ;
		}		
		if (c.equals("call_method")){
			CallJavaMethod(st) ;
		}		
		else if (c.equals("create_object")){
			CreateJavaObject(st) ;
		}
		else if (c.equals("delete_object")){
			DeleteJavaObject(st) ;
		}
	}


	/*
		Calls a static Java method
	*/
	void CallStaticJavaMethod(StringTokenizer st) throws InlineJavaException {
		String class_name = st.nextToken() ;
		String method = st.nextToken() ;
		Class c = ValidateClass(class_name) ;
		ArrayList f = ValidateMethod(false, c, method, st) ;

		Method m = (Method)f.get(0) ;
		String name = m.getName() ;
		Object p[] = (Object [])f.get(1) ;
		try {
			Object ret = m.invoke(null, p) ;
			SetResponse(ret) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to invoke static method " + name + " in class " + class_name) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments for static method " + name + " in class " + class_name + " are incompatible: " + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Static method " + name + " in class " + class_name + " threw exception " + type + ": " + msg) ;
		}
	}


	/*
		Calls a regular Java method
	*/
	void CallJavaMethod(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;
		String class_name = st.nextToken() ;
		String method = st.nextToken() ;
		Class c = ValidateClass(class_name) ;
		ArrayList f = ValidateMethod(false, c, method, st) ;

		Method m = (Method)f.get(0) ;
		String name = m.getName() ;
		Integer oid = new Integer(id) ;
		Object o = ijs.objects.get(oid) ;
		if (o == null){
			throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
		}
		Object p[] = (Object [])f.get(1) ;
		try {
			Object ret = m.invoke(o, p) ;
			SetResponse(ret) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to invoke method " + name + " in class " + class_name) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments for method " + name + " in class " + class_name + " are incompatible: " + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Method " + name + " in class " + class_name + " threw exception " + type + ": " + msg) ;
		}
	}


	/*
		Creates a Java Object with the specified arguments.
	*/
	void CreateJavaObject(StringTokenizer st) throws InlineJavaException {
		String class_name = st.nextToken() ;
		Class c = ValidateClass(class_name) ;

		ArrayList f = ValidateMethod(true, c, class_name, st) ;

		Constructor con = (Constructor)f.get(0) ;
		String name = class_name ;
		Object p[] = (Object [])f.get(1) ;

		Object o = CreateObject(c, p) ;
		SetResponse(o) ;
	}


	/*
		Deletes a Java object
	*/
	void DeleteJavaObject(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		Integer oid = new Integer(id) ;
		Object o = ijs.objects.remove(oid) ;

		SetResponse(null) ;
	}

	
	/*
		Creates a Java Object with the specified arguments.
	*/
	Object CreateObject(Class p, Object args[]) throws InlineJavaException {
		Class clist[] = new Class [args.length] ;
		for (int i = 0 ; i < args.length ; i++){
			clist[i] = args[i].getClass() ;
		}

		p = FindWrapper(p) ;

		String name = p.getName() ;
		Object ret = null ;
		try {
			Constructor con = (Constructor)p.getConstructor(clist) ;
			ret = con.newInstance(args) ;
		}
		catch (NoSuchMethodException e){
			throw new InlineJavaException("Constructor for class " + name + " with signature " + ijs.CreateSignature(clist) + " not found") ;
		}
		catch (InstantiationException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name + " using the constructor with signature " + ijs.CreateSignature(clist)) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments to constructor for class " + name + " with signature " + ijs.CreateSignature(clist) + " are incompatible: " + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Constructor for class " + name + " with signature " + ijs.CreateSignature(clist) + " threw exception " + type + ": " + msg) ;
		}

		return ret ;
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
		Makes sure a method exists
	*/
	ArrayList ValidateMethod(boolean constructor, Class c, String name, StringTokenizer st) throws InlineJavaException {
		Member ma[] = (constructor ? (Member [])c.getConstructors() : (Member [])c.getMethods()) ;
		ArrayList ret = new ArrayList(ma.length) ;

		// Extract the arguments
		ArrayList args = new ArrayList() ;
		while (st.hasMoreTokens()){
			args.add(args.size(), st.nextToken()) ;
		}

		ArrayList ml = new ArrayList(ma.length) ;
		Class params[] = null ;
		for (int i = 0 ; i < ma.length ; i++){
			Member m = ma[i] ;
			if (m.getName().equals(name)){
				ijs.debug("found a " + name + (constructor ? " constructor" : " method")) ;

				if (constructor){
					params = ((Constructor)m).getParameterTypes() ;
				}
				else{
					params = ((Method)m).getParameterTypes() ;
				}
			 	if (params.length == args.size()){
					// We have the same number of arguments
					ml.add(ml.size(), m) ;
					ijs.debug("  has the correct number of params (" +  String.valueOf(args.size()) + ") and signature is " + ijs.CreateSignature(params)) ;
				}
			}
		}

		// Now we got a list of matching methods. 
		// We have to figure out which one we will call.
		if (ml.size() == 0){
			throw new InlineJavaException(
				(constructor ? "Constructor " : "Method ") + 
				name + " for class " + c.getName() + " with signature " +
				ijs.CreateSignature(params) + " not found") ;
		}
		else if (ml.size() == 1){
			// Now we need to force the arguments received to match
			// the methods signature.
			Member m = (Member)ml.get(0) ;
			if (constructor){
				params = ((Constructor)m).getParameterTypes() ;
			}
			else{
				params = ((Method)m).getParameterTypes() ;
			}
			ret.add(0, m) ;
			ret.add(1, CastArguments(c.getName(), name, params, args)) ;
		}
		else{
			throw new InlineJavaException("Automatic method selection when multiple signatures are found not yet implemented") ;
		}

		return ret ;
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
					ijs.debug("  args is undef -> forcing to " + p.getName() + " 0") ;
					ret[i] = CreateObject(p, new Object [] {"0"}) ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = pack((String)tokens.get(1)) ;
					ijs.debug("  args is scalar -> forcing to " + p.getName()) ;
					try	{							
						ret[i] = CreateObject(p, new Object [] {arg}) ;
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
			else if ((p == java.lang.Boolean.class)||(p == boolean.class)){
				ijs.debug("  class java.lang.Boolean is primitive bool") ;
				if (type.equals("undef")){
					ijs.debug("  args is undef -> forcing to bool false") ;
					ret[i] = new Boolean("false") ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = pack(((String)tokens.get(1)).toLowerCase()) ;
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
			else if ((p == java.lang.Character.class)||(p == char.class)){
				ijs.debug("  class java.lang.Character is primitive char") ;
				if (type.equals("undef")){
					ijs.debug("  args is undef -> forcing to char '\0'") ;
					ret[i] = new Character('\0') ;
					ijs.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = pack((String)tokens.get(1)) ;
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
						String arg = pack((String)tokens.get(1)) ;
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

		if ((ClassIsNumeric(p))||(ClassIsString(p))){
			return true ;
		}

		Class [] list = {
			java.lang.Boolean.class,
			java.lang.Character.class,
			boolean.class,
			char.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			ijs.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive") ;
				return true ;
			}
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


	/*
		This sets the response that will be returned to the Perl
		script
	*/
	void SetResponse (Object o){
		if (o == null){
			response = "ok undef:" ;
		}
		else if (ClassIsPrimitive(o.getClass())){
			response = "ok scalar:" + unpack(o.toString()) ;
		}
		else {
			// Here we need to register the object in order to send
			// it back to the Perl script.
			ijs.objects.put(new Integer(ijs.objid), o) ;
			response = "ok object:" + String.valueOf(ijs.objid) +
				":" + o.getClass().getName() ;
			ijs.objid++ ;
		}
	}


	/* Equivalent to Perl pack */
	public String pack(String s){
		StringTokenizer st = new StringTokenizer(s, ".") ;
		StringBuffer sb = new StringBuffer() ;
		while (st.hasMoreTokens()){
			String ss = st.nextToken() ; 
			byte b[] = {(byte)Integer.parseInt(ss)} ;
			sb.append(new String(b)) ;
		}
	
		return sb.toString() ;
	}


	/* Equivalent to Perl unpack */
	public String unpack(String s){
		byte b[] = s.getBytes() ;
		StringBuffer sb = new StringBuffer() ;
		for (int i = 0 ; i < b.length ; i++){
			if (i > 0){
				sb.append(".") ;
			}
			sb.append(String.valueOf(b[i])) ;
		}

		return sb.toString() ;
	}
}

