package org.perl.inline.java ;

/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	private Thread creator ;

	public InlineJavaPerlCaller() throws InlineJavaException {
		Thread t = Thread.currentThread() ;
		if (InlineJavaServer.GetInstance().IsThreadPerlContact(t)){
			creator = t ;
		}
		else{
			throw new InlineJavaException("InlineJavaPerlCaller objects can only be created by threads that communicate directly with Perl") ;
		}
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaException, InlineJavaPerlException {
		return CallPerl(pkg, method, args, null) ;
	}


	public Object CallPerl(String pkg, String method, Object args[], String cast) throws InlineJavaException, InlineJavaPerlException {
		return InlineJavaServer.GetInstance().Callback(pkg, method, args, cast) ;
	}

	
	public void wait_for_callbacks(){
		// Not sure how this will work just yet...
	}
}
