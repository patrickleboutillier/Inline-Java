package org.perl.inline.java ;

import java.util.* ;
import java.io.* ;


/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	private InlineJavaServer ijs = InlineJavaServer.GetInstance() ;
	private Thread creator ;
	private boolean stop_loop = false ;
	private InlineJavaCallback queued_callback = null ;
	private Object queued_response = null ;


	/*
		Only thread that communicate with Perl are allowed to create PerlCallers because
		this is where we get the thread that needs to be notified when the callbacks come in.
	*/
	public InlineJavaPerlCaller() throws InlineJavaException {
		Thread t = Thread.currentThread() ;
		if (ijs.IsThreadPerlContact(t)){
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
		InlineJavaCallback ijc = new InlineJavaCallback(pkg, method, args, cast) ;
		return CallPerl(ijc) ;
	}


	synchronized public Object CallPerl(InlineJavaCallback ijc) throws InlineJavaException, InlineJavaPerlException {
		Thread t = Thread.currentThread() ;
		if (t == creator){
			return Callback(ijc) ;
		}
		else{
			// Enqueue the callback into the creator thread's queue and notify it
			// that there is some work for him.
			// ijs.EnqueueCallback(creator, ijc) ;
			queued_callback = ijc ;
			notify() ;

			// Now we must wait until the callback is processed and get back the result...
			while(true){
				try {
					wait() ;
					if (queued_response != null){
						break ;
					}
				}
				catch (InterruptedException ie){
					// Do nothing, return and wait() some more...
				}
			}

			Object resp = queued_response ;
			queued_response = null ;
			
			return resp ;
		}
	}


	synchronized public void StartCallbackLoop() throws InlineJavaException, InlineJavaPerlException {
		Thread t = Thread.currentThread() ;
		if (! ijs.IsThreadPerlContact(t)){
			throw new InlineJavaException("InlineJavaPerlCaller.start_callback_loop() can only be called by threads that communicate directly with Perl") ;
		}

		Object resp = null ;
		CheckForCallback() ;
		stop_loop = false ;
		while (! stop_loop){
			try {
				wait() ;
				CheckForCallback() ;
			}
			catch (InterruptedException ie){
				// Do nothing, return and wait() some more...
			}
		}
	}


	private void CheckForCallback() throws InlineJavaException, InlineJavaPerlException {
		//ijc = ijs.DequeueCallback(t) ;
		//if (ijc != null){
		//	resp = Callback(ijc) ;
		// Send resp back to the calling thread?
		//}
		if (queued_callback != null){
			InlineJavaCallback ijc = queued_callback ;
			queued_callback = null ;
			queued_response = Callback(ijc) ;
			notify() ;
		}
	}


	synchronized public void StopCallbackLoop() {
		stop_loop = true ;
		notify() ;
	}


	private Object Callback(InlineJavaCallback ijcb) throws InlineJavaException, InlineJavaPerlException {
		Object ret = null ;
		try {
			InlineJavaProtocol ijp = new InlineJavaProtocol(ijs, null) ;
			String cmd = ijcb.GetCommand(ijp) ;
			InlineJavaUtils.debug(2, "callback command: " + cmd) ;

			Thread t = Thread.currentThread() ;
			String resp = null ;
			while (true) {
				InlineJavaUtils.debug(3, "packet sent (callback) is " + cmd) ;
				if (! ijs.IsJNI()){
					// Client-server mode.
					InlineJavaServerThread ijt = (InlineJavaServerThread)t ;
					ijt.GetWriter().write(cmd + "\n") ;
					ijt.GetWriter().flush() ;

					resp = ijt.GetReader().readLine() ;
				}
				else{
					// JNI mode
					resp = ijs.jni_callback(cmd) ;
				}
				InlineJavaUtils.debug(3, "packet recv (callback) is " + resp) ;

				StringTokenizer st = new StringTokenizer(resp, " ") ;
				String c = st.nextToken() ;
				if (c.equals("callback")){
					boolean thrown = new Boolean(st.nextToken()).booleanValue() ;
					String arg = st.nextToken() ;
					InlineJavaClass ijc = new InlineJavaClass(ijs, ijp) ;
					ret = ijc.CastArgument(java.lang.Object.class, arg) ;

					if (thrown){
						throw new InlineJavaPerlException(ret) ;
					}

					break ;
				}
				else{
					// Pass it on through the regular channel...
					InlineJavaUtils.debug(3, "packet is not callback response: " + resp) ;
					cmd = ijs.ProcessCommand(resp, false) ;

					continue ;
				}
			}
		}
		catch (IOException e){
			throw new InlineJavaException("IO error: " + e.getMessage()) ;
		}

		return ret ;
	}
}
