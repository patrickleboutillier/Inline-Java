/*
	Callback to Perl...

	This class has user visibility so methods must be public.
*/
class InlineJavaPerlCaller {
	public InlineJavaPerlCaller(){
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaException, InlineJavaPerlException {
		return CallPerl(pkg, method, args, null) ;
	}


	public Object CallPerl(String pkg, String method, Object args[], String cast) throws InlineJavaException, InlineJavaPerlException {
		return InlineJavaServer.instance.Callback(pkg, method, args, cast) ;
	}
}
