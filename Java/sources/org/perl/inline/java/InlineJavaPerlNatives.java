package org.perl.inline.java ;

import java.lang.reflect.* ;
import java.util.* ;
import java.io.* ;


public class InlineJavaPerlNatives extends InlineJavaPerlCaller {
	static private boolean inited = false ;
    static private ResourceBundle resources = null ;
	static private HashMap registered_classes = new HashMap() ;
	static private HashMap registered_methods = new HashMap() ;


	protected InlineJavaPerlNatives() throws InlineJavaException {
		init() ;
		RegisterPerlNatives(new Caller().getCaller()) ;
	}


	static protected void init() throws InlineJavaException {
		init("install") ;
	}


	synchronized static protected void init(String mode) throws InlineJavaException {
		if (! inited){
			try {
				resources = ResourceBundle.getBundle("InlineJava") ;

				String jni_so_built = resources.getString("jni_so_built") ;
				if (! jni_so_built.equals("true")){
					throw new InlineJavaException("Can't use the PerlNatives " +
						"functionnality because the JNI extension was not built " +
						"when Inline::Java was installed.") ;
				}

				boolean load_libperl_so = true ;
				InlineJavaServer ijs = InlineJavaServer.GetInstance() ;
				if ((ijs != null)&&(ijs.IsJNI())){
					// InlineJavaServer is loaded and in JNI mode, no need to load Perl.
					load_libperl_so = false ;
				}

				if (load_libperl_so){
					// Load the perl shared object			
					load_so_from_property("libperl_so") ;
				}

				// Load the JNI shared object
				load_so_from_property("inline_java_jni_so_" + mode) ;

				inited = true ;
			}
			catch (MissingResourceException mre){
				throw new InlineJavaException("Error loading InlineJava.properties resource: " + mre.getMessage()) ;
			}
		}
	}


	synchronized static private void load_so_from_property(String prop) throws MissingResourceException, InlineJavaException {
		String so = resources.getString(prop) ;
		InlineJavaUtils.debug(2, "loading shared library " + so) ;
		System.load(so) ;
	}


	// This method actually does the real work of registering the methods.
	synchronized public void RegisterPerlNatives(Class c) throws InlineJavaException {
		if (registered_classes.get(c) == null){
			InlineJavaUtils.debug(3, "registering natives for class " + c.getName()) ;

			Constructor constructors[] = c.getDeclaredConstructors() ;
			Method methods[] = c.getDeclaredMethods() ;

			registered_classes.put(c, c) ;
			for (int i = 0 ; i < constructors.length ; i++){
				Constructor x = constructors[i] ;
				if (Modifier.isNative(x.getModifiers())){
					RegisterMethod(c, "new", x.getParameterTypes(), c) ;
				}
			}

			for (int i = 0 ; i < methods.length ; i++){
				Method x = methods[i] ;
				if (Modifier.isNative(x.getModifiers())){
					RegisterMethod(c, x.getName(), x.getParameterTypes(), x.getReturnType()) ;
				}
			}
		}
	}


	private void RegisterMethod(Class c, String mname, Class params[], Class rt) throws InlineJavaException {
		String cname = c.getName() ;
		InlineJavaUtils.debug(3, "registering native method " + mname + " for class " + cname) ;

		// Check return type
		if ((! Object.class.isAssignableFrom(rt))&&(rt != void.class)){
			throw new InlineJavaException("Perl native method " + mname + " of class " + cname + " can only have Object or void return types (not " + rt.getName() + ")") ;
		}

		// fmt starts with the return type, which for now is Object only (or void).
		StringBuffer fmt = new StringBuffer("L") ;
		StringBuffer sign = new StringBuffer("(") ;
		for (int i = 0 ; i < params.length ; i++){
			if (! Object.class.isAssignableFrom(params[i])){
				throw new InlineJavaException("Perl native method " + mname + " of class " + cname + " can only have Object arguments (not " + params[i].getName() + ")") ;
			}
			sign.append(InlineJavaClass.FindJNICode(params[i])) ;
			fmt.append("L") ;
		}
		sign.append(")") ;

		sign.append(InlineJavaClass.FindJNICode(rt)) ;
		InlineJavaUtils.debug(3, "signature is " + sign) ;
		InlineJavaUtils.debug(3, "format is " + fmt) ;

		// For now, no method overloading so no signature necessary
		registered_methods.put(cname + "." + mname, fmt.toString()) ;

		// call the native method to hook it up
		RegisterMethod(c, mname, sign.toString()) ;
	}


	// This native method will call RegisterNative to hook up the magic
	// method implementation for the method.
	native private void RegisterMethod(Class c, String name, String signature) throws InlineJavaException ;


	// This method will be called from the native side. We need to figure
	// out who this method is and then look in up in the
	// registered method list and return the format.
	private String LookupMethod() throws InlineJavaException {
		InlineJavaUtils.debug(3, "entering LookupMethod") ;

		String caller[] = GetNativeCaller() ;
		String meth = caller[0] + "." + caller[1]  ;

		String fmt = (String)registered_methods.get(meth) ;
		if (fmt == null){
			throw new InlineJavaException("Native method " + meth + " is not registered") ;
		}

		InlineJavaUtils.debug(3, "exiting LookupMethod") ;

		return fmt ;
	}


	private Object InvokePerlMethod(Object args[]) throws InlineJavaException, InlineJavaPerlException {
		InlineJavaUtils.debug(3, "entering InvokePerlMethod") ;

		String caller[] = GetNativeCaller() ;
		String pkg = caller[0] ;
		String method = caller[1] ;

		// Transform the Java class name into the Perl package name
		StringTokenizer st = new StringTokenizer(pkg, ".") ;
		StringBuffer perl_pkg = new StringBuffer() ;
		while (st.hasMoreTokens()){
			perl_pkg.append(st.nextToken() + "::") ;
		}

		for (int i = 0 ; i < args.length ; i++){
			InlineJavaUtils.debug(3, "InvokePerlMethod argument " + i + " = " + args[i]) ;
		}

		InlineJavaUtils.debug(3, "exiting InvokePerlMethod") ;

		return CallPerl(perl_pkg + "perl", method, args) ;
	}


	// This method must absolutely be called by a method DIRECTLY called
	// by generic_perl_native
	private String[] GetNativeCaller() throws InlineJavaException {
		InlineJavaUtils.debug(3, "entering GetNativeCaller") ;

		Class ste_class = null ;
		try {
			ste_class = Class.forName("java.lang.StackTraceElement") ;
		}
		catch (ClassNotFoundException cnfe){
			throw new InlineJavaException("Can't load class java.lang.StackTraceElement") ;
		}      	

		Throwable exec_point = new Throwable() ;
		try {
			Method m = exec_point.getClass().getMethod("getStackTrace", new Class [] {}) ;
			Object stack = m.invoke(exec_point, new Object [] {}) ;
			if (Array.getLength(stack) <= 2){
				throw new InlineJavaException("Improper use of InlineJavaPerlNatives.GetNativeCaller (call stack too short)") ;
			}

			Object ste = Array.get(stack, 2) ;
			m = ste.getClass().getMethod("isNativeMethod", new Class [] {}) ;
			Boolean is_nm = (Boolean)m.invoke(ste, new Object [] {}) ;
			if (! is_nm.booleanValue()){
				throw new InlineJavaException("Improper use of InlineJavaPerlNatives.GetNativeCaller (caller is not native)") ;
			}

			m = ste.getClass().getMethod("getClassName", new Class [] {}) ;
			String cname = (String)m.invoke(ste, new Object [] {}) ;
			m = ste.getClass().getMethod("getMethodName", new Class [] {}) ;
			String mname = (String)m.invoke(ste, new Object [] {}) ;

			InlineJavaUtils.debug(3, "exiting GetNativeCaller") ;

			return new String [] {cname, mname} ;
		}
		catch (NoSuchMethodException nsme){
			throw new InlineJavaException("Error manipulating java.lang.StackTraceElement classes: " +
				nsme.getMessage()) ;
		}
		catch (IllegalAccessException iae){
			throw new InlineJavaException("Error manipulating java.lang.StackTraceElement classes: " +
				iae.getMessage()) ;
		}
		catch (InvocationTargetException ite){
			// None of the methods invoked throw exceptions, so...
			throw new InlineJavaException("Exception caught while manipulating java.lang.StackTraceElement classes: " +
				ite.getTargetException()) ;
		}
	}


	class Caller extends SecurityManager {
		public Class getCaller(){
			return getClassContext()[2] ;
		}
	}
}
