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
	static private HashMap thread_callback_queues = new HashMap() ;


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


	public Object CallPerl(InlineJavaCallback ijc) throws InlineJavaException, InlineJavaPerlException {
		Thread t = Thread.currentThread() ;
		if (t == creator){
			ijc.Process() ;
			return ijc.GetResponse() ;
		}
		else{
			// Enqueue the callback into the creator thread's queue and notify it
			// that there is some work for him.
			ijc.ClearResponse() ;
			ArrayList queue = GetQueue(creator) ;
			synchronized (queue){
				InlineJavaUtils.debug(3, "enqueing callback for processing for " + creator.getName() + " in " + t.getName() + "...") ;
				EnqueueCallback(queue, ijc) ;
				InlineJavaUtils.debug(3, "notifying that a callback request is available for " + creator.getName() + " in " + t.getName() + " (monitor = " + this + ")") ;
				queue.notify() ;
			}

			// Now we must wait until the callback is processed and get back the result...
			return ijc.WaitForResponse(t) ;
		}
	}


	public void StartCallbackLoop() throws InlineJavaException, InlineJavaPerlException {
		Thread t = Thread.currentThread() ;
		if (! ijs.IsThreadPerlContact(t)){
			throw new InlineJavaException("InlineJavaPerlCaller.StartCallbackLoop() can only be called by threads that communicate directly with Perl") ;
		}

		ArrayList queue = GetQueue(t) ;
		stop_loop = false ;
		while (! stop_loop){
			synchronized (queue){
				while (! CheckForCallback(queue)){
					try {
						InlineJavaUtils.debug(3, "waiting for callback request in " + t.getName() + " (monitor = " + this + ")...") ;
						queue.wait() ;
						InlineJavaUtils.debug(3, "waiting for callback request finished " + t.getName() + " (monitor = " + this + ")...") ;
					}
					catch (InterruptedException ie){
						// Do nothing, return and wait() some more...
					}						
				}
				InlineJavaUtils.debug(3, "processing callback request in " + t.getName() + "...") ;
				ProcessCallback(t, queue) ;
			}
		}
	}


	private boolean CheckForCallback(ArrayList q) throws InlineJavaException, InlineJavaPerlException {
		return (q.size() > 0) ;
	}


	private void ProcessCallback(Thread t, ArrayList q) throws InlineJavaException, InlineJavaPerlException {
		InlineJavaCallback ijc = DequeueCallback(q) ;
		if (ijc != null){
			ijc.Process() ;
			ijc.NotifyOfResponse(t) ;
		}
	}


	public void StopCallbackLoop() throws InlineJavaException {
		ArrayList queue = GetQueue(creator) ;
		stop_loop = true ;
		queue.notify() ;
	}


	/*
		Here the prototype accepts Threads because the JNI thread
		calls this method also.
	*/
	static synchronized void AddThread(Thread t){
		thread_callback_queues.put(t, new ArrayList()) ;
	}


	static synchronized void RemoveThread(InlineJavaServerThread t){
		thread_callback_queues.remove(t) ;
	}


	static private ArrayList GetQueue(Thread t) throws InlineJavaException {
		ArrayList a = (ArrayList)thread_callback_queues.get(t) ;

		if (a == null){
			throw new InlineJavaException("Can't find thread " + t.getName() + "!") ;
		}
		return a ;
	}


	static synchronized void EnqueueCallback(ArrayList q, InlineJavaCallback ijc) throws InlineJavaException {
		q.add(ijc) ;
	}


	static synchronized InlineJavaCallback DequeueCallback(ArrayList q) throws InlineJavaException {
		if (q.size() > 0){
			return (InlineJavaCallback)q.remove(0) ;
		}
		return null ;
	}
}
