package Inline::Java::private::Protocol ;


use strict ;


use Carp ;
use Data::Dumper ;


# This will be set when the code is loaded.
$Inline::Java::private::Protocol::socket = {} ;


sub new {
	my $class = shift ;
	my $obj = shift ;
	my $module = shift ;

	my $this = {} ;
	$this->{obj_priv} = $obj || {} ;
	if ($obj){
		$this->{pkg} = $obj->{pkg} ;
	}
	$this->{module} = $module ;

	bless($this, $class) ;
	return $this ;
}


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


sub CallStaticJavaMethod {
	my $this = shift ;
	my $class = shift ;
	my $pkg = shift ;
	my $method = shift ;
	my @args = @_ ;

	$this->{pkg} = $pkg ;

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


sub CallJavaMethod {
	my $this = shift ;
	my $method = shift ;
	my @args = @_ ;

	my $id = $this->{obj_priv}->{id} ;
	my $class = $this->{obj_priv}->{class} ;
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


sub DeleteJavaObject {
	my $this = shift ;

	if (defined($this->{obj_priv}->{id})){
		my $id = $this->{obj_priv}->{id} ;
		my $class = $this->{obj_priv}->{class} ;

		Inline::Java::debug("deleting object $this $id ($class)") ;

		my $data = join(" ", 
			"delete_object", 
			$id,
		) ;

		Inline::Java::debug("  packet sent is $data") ;		

		$this->Send($data) ;
	}
}


sub ValidateClass {
	my $this = shift ;
	my $class = shift ;

	if ($class !~ /^(\w+)((\.(\w+))+)?/){
		croak "Invalid Java class name $class" ;
	}	

	return $class ;
}


sub ValidateMethod {
	my $this = shift ;
	my $method = shift ;

	if ($method !~ /^(\w+)$/){
		croak "Invalid Java method name $method" ;
	}	

	return $method ;
}


sub ValidateArgs {
	my $this = shift ;
	my @args = @_ ;

	my @ret = () ;
	foreach my $arg (@args){
		if (! defined($arg)){
			push @ret, "undef:" ;
		}
		elsif (ref($arg)){
			if (! UNIVERSAL::isa($arg, "Inline::Java::private::Object")){
				croak "A Java method can only have Java objects or scalars as arguments" ;
			}
			my $class = $arg->{private}->{class} ;
			my $id = $arg->{private}->{id} ;
			push @ret, "object:$class:$id" ;
		}
		else{
			push @ret, "scalar:" . join(".", unpack("C*", $arg)) ;
		}
	}

	return @ret ;
}


sub Send {
	my $this = shift ;
	my $data = shift ;
	my $const = shift ;

	my $sock = $Inline::Java::private::Protocol::socket->{$this->{module}} ;
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
			$this->{obj_priv}->{class} = $class ;
			$this->{obj_priv}->{id} = $id ;
		}
		else{
			my $perl_class = $class ;
			$perl_class =~ s/[.\$]/::/g ;
			my $pkg = $this->{pkg} ;
			$perl_class = $pkg . "::" . $perl_class ;
			Inline::Java::debug($perl_class) ;

			my $obj = undef ;
			if (defined(${$perl_class . "::" . "EXISTS"})){
				Inline::Java::debug("  returned class exists!") ;
				$obj = $perl_class->__new($class, $pkg, $this->{module}, $id) ;
			}
			else{
				Inline::Java::debug("  returned class doesn't exist!") ;
				$obj = Inline::Java::private::Object->__new($class, $pkg, $this->{module}, $id) ;
			}
			return $obj ;
		}
	}
}


1 ;



__DATA__


class InlineJavaProtocol {
	<INLINE_MODFNAME> main ;
	String cmd ;
	String response ;

	InlineJavaProtocol(<INLINE_MODFNAME> _m, String _cmd) {
		main = _m ;
		cmd = _cmd ;
	}


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
			throw new InlineJavaException("You are not allowed to invoke static method " + name) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments for static method " + name + " are incompatible:" + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Method " + name + " threw exception " + type + ": " + msg) ;
		}
	}


	void CallJavaMethod(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;
		String class_name = st.nextToken() ;
		String method = st.nextToken() ;
		Class c = ValidateClass(class_name) ;
		ArrayList f = ValidateMethod(false, c, method, st) ;

		Method m = (Method)f.get(0) ;
		String name = m.getName() ;
		Integer oid = new Integer(id) ;
		Object o = main.objects.get(oid) ;
		if (o == null){
			throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
		}
		Object p[] = (Object [])f.get(1) ;
		try {
			Object ret = m.invoke(o, p) ;
			SetResponse(ret) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to invoke method " + name) ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments for static " + name + " are incompatible:" + e.getMessage()) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Method " + name + " threw exception " + type + ": " + msg) ;
		}
	}


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


	void DeleteJavaObject(StringTokenizer st) throws InlineJavaException {
		int id = Integer.parseInt(st.nextToken()) ;

		Integer oid = new Integer(id) ;
		Object o = main.objects.remove(oid) ;

		SetResponse(null) ;
	}

	
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
			throw new InlineJavaException("Constructor for class " + name + " with specified signature not found") ;
		}
		catch (InstantiationException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name) ;
		}
		catch (IllegalAccessException e){
			throw new InlineJavaException("You are not allowed to instantiate object of class " + name + " using the specified constructor") ;
		}
		catch (IllegalArgumentException e){
			throw new InlineJavaException("Arguments to constructor are incompatible for class " + name) ;
		}
		catch (InvocationTargetException e){
			Throwable t = e.getTargetException() ;
			String type = t.getClass().getName() ;
			String msg = t.getMessage() ;
			throw new InlineJavaException(
				"Constructor for class " + name + " threw exception " + type + ": " + msg) ;
		}

		return ret ;
	}


	Class ValidateClass(String name) throws InlineJavaException {
		try {
			Class c = Class.forName(name) ;
			return c ;
		}
		catch (ClassNotFoundException e){
			throw new InlineJavaException("Class " + name + " not found") ;
		}
	}


	ArrayList ValidateMethod(boolean constructor, Class c, String name, StringTokenizer st) throws InlineJavaException {
		Member ma[] = (constructor ? (Member [])c.getConstructors() : (Member [])c.getMethods()) ;
		ArrayList ret = new ArrayList(ma.length) ;

		// Extract the arguments
		ArrayList args = new ArrayList() ;
		while (st.hasMoreTokens()){
			args.add(args.size(), st.nextToken()) ;
		}

		ArrayList ml = new ArrayList(ma.length) ;
		for (int i = 0 ; i < ma.length ; i++){
			Member m = ma[i] ;
			if (m.getName().equals(name)){
				main.debug("found a " + name + (constructor ? " constructor" : " method")) ;

				Class params[] = null ;
				if (constructor){
					params = ((Constructor)m).getParameterTypes() ;
				}
				else{
					params = ((Method)m).getParameterTypes() ;
				}
			 	if (params.length == args.size()){
					// We have the same number of arguments
					ml.add(ml.size(), m) ;
					main.debug("  has the correct number of params (" +  String.valueOf(args.size()) + ") and signature is " + CreateSignature(params)) ;
				}
			}
		}

		// Now we got a list of matching methods. 
		// We have to figure out which one we will call.
		if (ml.size() == 0){
			throw new InlineJavaException(
				(constructor ? "Constructor " : "Method ") + 
				name + " with " + String.valueOf(args.size()) + " parameters not found in class " + c.getName()) ;
		}
		else if (ml.size() == 1){
			// Now we need to force the arguments received to match
			// the methods signature.
			Member m = (Member)ml.get(0) ;
			Class params[] = null ;
			if (constructor){
				params = ((Constructor)m).getParameterTypes() ;
			}
			else{
				params = ((Method)m).getParameterTypes() ;
			}
			ret.add(0, m) ;
			ret.add(1, CastArguments(params, args)) ;
		}
		else{
			throw new InlineJavaException("Don't know which signature of " + name + " to call") ;
		}

		return ret ;
	}


	Object [] CastArguments (Class [] params, ArrayList args) throws InlineJavaException {
		Object ret[] = new Object [params.length] ;
	
		for (int i = 0 ; i < params.length ; i++){	
			// Here the args are all strings or objects (or undef)
			// we need to match them to the prototype.
			Class p = params[i] ;
			main.debug("    arg " + String.valueOf(i) + " of signature is " + p.getName()) ;

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
				String text = "string" ;
				if (num){
					text = "number" ;
				}
				if (type.equals("undef")){
					main.debug("  args is undef -> forcing to " + text + " 0") ;
					ret[i] = CreateObject(p, new Object [] {"0"}) ;
					main.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = pack((String)tokens.get(1)) ;
					main.debug("  args is scalar -> forcing to " + text) ;
					try	{							
						ret[i] = CreateObject(p, new Object [] {arg}) ;
						main.debug("    result is " + ret[i].toString()) ;
					}
					catch (NumberFormatException e){
						throw new InlineJavaCastException("Can't convert " + arg + " to some primitive " + text) ;
					}
				}
				else{
					throw new InlineJavaCastException("Can't convert reference to primitive " + text) ;
				}
			}
			else if ((p == java.lang.Boolean.class)||(p == boolean.class)){
				main.debug("  class java.lang.Boolean is primitive bool") ;
				if (type.equals("undef")){
					main.debug("  args is undef -> forcing to bool false") ;
					ret[i] = new Boolean("false") ;
					main.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = pack(((String)tokens.get(1)).toLowerCase()) ;
					main.debug("  args is scalar -> forcing to bool") ;
					if ((arg.equals(""))||(arg.equals("0"))||(arg.equals("false"))){
						arg = "false" ;
					}
					else{
						arg = "true" ;
					}
					ret[i] = new Boolean(arg) ;
					main.debug("    result is " + ret[i].toString()) ;
				}
				else{
					throw new InlineJavaCastException("Can't convert reference to primitive bool") ;
				}
			}
			else if ((p == java.lang.Character.class)||(p == char.class)){
				main.debug("  class java.lang.Character is primitive char") ;
				if (type.equals("undef")){
					main.debug("  args is undef -> forcing to char '\0'") ;
					ret[i] = new Character('\0') ;
					main.debug("    result is " + ret[i].toString()) ;
				}
				else if (type.equals("scalar")){
					String arg = pack((String)tokens.get(1)) ;
					main.debug("  args is scalar -> forcing to char") ;
					char c = '\0' ;
					if (arg.length() == 1){
						c = arg.toCharArray()[0] ;
					}
					else if (arg.length() > 1){
						throw new InlineJavaCastException("Can't convert " + arg + " to primitive char") ;
					}
					ret[i] = new Character(c) ;
					main.debug("    result is " + ret[i].toString()) ;
				}
				else{
					throw new InlineJavaCastException("Can't convert reference to primitive char") ;
				}
			}
			else {
				main.debug("  class " + p.getName() + " is reference") ;
				// We know that what we expect here is a real object
				if (type.equals("undef")){
					main.debug("  args is undef -> forcing to null") ;
					ret[i] = null ;
				}
				else if (type.equals("scalar")){
					if (p == java.lang.Object.class){
						String arg = pack((String)tokens.get(1)) ;
						ret[i] = arg ;
					}
					else{
						throw new InlineJavaCastException("Can't convert primitive to reference") ;
					}
				}
				else{
					// We need an object and we got an object...
					main.debug("  class " + p.getName() + " is reference") ;

					String class_name = (String)tokens.get(1) ;
					String objid = (String)tokens.get(2) ;

					Class c = ValidateClass(class_name) ;
					// We need to check if c extends p
					Class parent = c ;
					boolean got_it = false ;
					while (parent != null){
						main.debug("    parent is " + parent.getName()) ;
						if (parent == p){
							got_it = true ;
							break ;
						}
						parent = parent.getSuperclass() ;
					}

					if (got_it){
						main.debug("    " + c.getName() + " is a kind of " + p.getName()) ;
						// get the object from the hash table
						Integer oid = new Integer(objid) ;
						Object o = main.objects.get(oid) ;
						if (o == null){
							throw new InlineJavaException("Object " + oid.toString() + " is not in HashMap!") ;
						}
						ret[i] = o ;
					}
					else{
						throw new InlineJavaCastException("Can't cast a " + c.getName() + " to a " + p.getName()) ;
					}
				}
			}			
		}

		return ret ;
	}


	String CreateSignature (Class param[]){
		StringBuffer ret = new StringBuffer() ;
		for (int i = 0 ; i < param.length ; i++){
			if (i > 0){
				ret.append(", ") ;
			}
			ret.append(param[i].getName()) ;
		}

		return "(" + ret.toString() + ")" ;
	}


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
			void.class,
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
			java.lang.Void.class,
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
			java.lang.Void.class,
			boolean.class,
			char.class,
			void.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			main.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				main.debug("  class " + name + " is primitive") ;
				return true ;
			}
		}

		main.debug("  class " + name + " is reference") ;
		return false ;
	}


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
			main.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				main.debug("  class " + name + " is primitive numeric") ;
				return true ;
			}
		}

		return false ;
	}


	boolean ClassIsString (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.String.class,
			java.lang.StringBuffer.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			main.debug("  comparing " + name + " with " + list[i].getName()) ;
			if (p == list[i]){
				main.debug("  class " + name + " is primitive string") ;
				return true ;
			}
		}

		return false ;
	}

	
	boolean ClassIsReference (Class p){
		String name = p.getName() ;

		if (ClassIsPrimitive(p)){
			return false ;
		}

		main.debug("  class " + name + " is reference") ;

		return true ;
	}


	void SetResponse (Object o){
		if (o == null){
			response = "ok undef:" ;
		}
		// Split between Numeric, String, Boolean and Character and Void
		else if (ClassIsPrimitive(o.getClass())){
			response = "ok scalar:" + unpack(o.toString()) ;
		}
		else {
			// Here we need to register the object in order to send
			// it back to the Perl script.
			main.objects.put(new Integer(main.objid), o) ;
			response = "ok object:" + String.valueOf(main.objid) +
				":" + o.getClass().getName() ;
			main.objid++ ;
		}
	}


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


	public void test(String argv[]){
		Class list[] = {
			java.lang.Exception.class,
//			java.lang.Byte.class,
//			java.lang.Short.class,
//			java.lang.Integer.class,
//			java.lang.Long.class,
//			java.lang.Float.class,
//			java.lang.Double.class,
//			java.lang.String.class,
//			java.lang.StringBuffer.class,
//			java.lang.Boolean.class,
//			java.lang.Character.class,
		} ;

		ArrayList args[] = new ArrayList [1] ;
		for (int j = 0 ; j < 1 ; j++){
			args[j] = new ArrayList(1) ;
		}
		args[0].add(0, "object:666:java.lang.Exception") ;
//		args[0].add(0, "undef:") ;
//		args[1].add(0, "scalar:66") ;
//		args[2].add(0, "scalar:666") ;
//		args[3].add(0, "scalar:a") ;
//		args[4].add(0, "scalar:AB") ;
//		args[5].add(0, "scalar:1") ;
//		args[6].add(0, "scalar:") ;

		for (int j = 0 ; j < args.length ; j++){
			for (int i = 0; i < list.length ; i++){
				Class proto[] = new Class[1] ;
				proto[0] = list[i] ;
				try	{
					CastArguments(proto, args[j]) ;
				}
				catch (InlineJavaException e){
					main.debug("InlineJavaException caught: " + e.getMessage()) ;
				}			
			}
			main.debug("") ;
		}
	}
}

