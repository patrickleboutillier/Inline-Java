package Inline::Java::Init ;


use strict ;

$Inline::Java::Init::VERSION = '0.30' ;

my $DATA = join('', <DATA>) ;
my $OBJECT_DATA = join('', <Inline::Java::Object::DATA>) ;
my $ARRAY_DATA = join('', <Inline::Java::Array::DATA>) ;
my $CLASS_DATA = join('', <Inline::Java::Class::DATA>) ;
my $PROTO_DATA = join('', <Inline::Java::Protocol::DATA>) ;

my $CALLBACK_DATA = join('', <Inline::Java::Callback::DATA>) ;


sub DumpUserJavaCode {
	my $fh = shift ;
	my $code = shift ;

	print $fh $code ;
}


sub DumpServerJavaCode {
	my $fh = shift ;

	my $java = $DATA ;
	my $java_obj = $OBJECT_DATA ;
	my $java_array = $ARRAY_DATA ;
	my $java_class = $CLASS_DATA ;
	my $java_proto = $PROTO_DATA ;

	$java =~ s/<INLINE_JAVA_OBJECT>/$java_obj/g ;
	$java =~ s/<INLINE_JAVA_ARRAY>/$java_array/g ;
	$java =~ s/<INLINE_JAVA_CLASS>/$java_class/g ;
	$java =~ s/<INLINE_JAVA_PROTOCOL>/$java_proto/g ;

	print $fh $java ;
}


sub DumpCallbackJavaCode {
	my $fh = shift ;

	my $java = $CALLBACK_DATA ;

	print $fh $java ;
}



1 ;



__DATA__
import java.net.* ;
import java.io.* ;
import java.util.* ;
import java.lang.reflect.* ;


/*
	This is the server that will answer all the requests for and on Java
	objects.
*/
public class InlineJavaServer {
	static public InlineJavaServer instance = null ;
	private boolean debug ;
	private int port = 0 ;
	private boolean shared_jvm = false ;

	private HashMap thread_objects = new HashMap() ;
	private int objid = 1 ;

	// This constructor is used in JNI mode
	InlineJavaServer(boolean d) {
		init() ;
		debug = d ;

		thread_objects.put(Thread.currentThread().getName(), new HashMap()) ;		
	}


	// This constructor is used in server mode
	InlineJavaServer(String[] argv) {
		init() ;
		debug = new Boolean(argv[0]).booleanValue() ;
		port = Integer.parseInt(argv[1]) ;
		shared_jvm = new Boolean(argv[2]).booleanValue() ;

		ServerSocket ss = null ;
		try {
			ss = new ServerSocket(port) ;	
		}
		catch (IOException e){
			System.err.println("Can't open server socket on port " + String.valueOf(port)) ;
			System.exit(1) ;
		}

		while (true){
			try {
				InlineJavaThread ijt = new InlineJavaThread(this, ss.accept()) ;
				ijt.start() ;
				if (! shared_jvm){
					try {
						ijt.join() ; 
					}
					catch (InterruptedException e){
					}
					break ;
				}
			}
			catch (IOException e){
				System.err.println("IO error: " + e.getMessage()) ;
			}
		}

		System.exit(1) ;
	}


	private void init(){
		instance = this ;		
	}


	/*
		Since this function is also called from the JNI XS extension,
		it's best if it doesn't throw any exceptions.
	*/
	private String ProcessCommand(String cmd) {
		debug("  packet recv is " + cmd) ;

		String resp = null ;
		if (cmd != null){
			InlineJavaProtocol ijp = new InlineJavaProtocol(this, cmd) ;
			try {
				ijp.Do() ;
				debug("  packet sent is " + ijp.response) ;
				resp = ijp.response + "\n" ;
			}
			catch (InlineJavaException e){
				String err = "error scalar:" + ijp.unpack(e.getMessage()) ;
				debug("  packet sent is " + err) ;
				resp = err + "\n" ;
			}
		}
		else{
			if (! shared_jvm){
				// Probably connection dropped...
				debug("  Lost connection with client in single client mode. Exiting.") ;
				System.exit(1) ;
			}
			else{
				debug("  Lost connection with client in shared JVM mode.") ;
				return null ;
			}
		}

		return resp ;
	}

	
	public Object GetObject(int id) throws InlineJavaException {
		Object o = null ;
		String name = Thread.currentThread().getName() ;
		HashMap h = (HashMap)thread_objects.get(name) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + name + "!") ;
		}
		else{
			o = h.get(new Integer(id)) ;
			if (o == null){
				throw new InlineJavaException("Can't find object " + id + " for thread " + name) ;
			}
		}

		return o ;
	}


	synchronized public void PutObject(int id, Object o) throws InlineJavaException {
		String name = Thread.currentThread().getName() ;
		HashMap h = (HashMap)thread_objects.get(name) ;

		if (h == null){
			throw new InlineJavaException("Can't find thread " + name + "!") ;
		}
		else{
			h.put(new Integer(id), o) ;
			objid++ ;
		}
	}


	public Object DeleteObject(int id) {
		Object o = null ;
		try {
			String name = Thread.currentThread().getName() ;
			HashMap h = (HashMap)thread_objects.get(name) ;

			if (h == null){
				throw new InlineJavaException("Can't find thread " + name + "!") ;
			}
			else{
				o = h.remove(new Integer(id)) ;
				if (o == null){
					throw new InlineJavaException("Can't find object " + id + " for thread " + name) ;
				}
			}
		}
		catch (InlineJavaException e){
			debug(e.getMessage()) ;
		}

		return o ;
	}


	public int ObjectCount() {
		int i = -1 ;
		try {
			String name = Thread.currentThread().getName() ;
			HashMap h = (HashMap)thread_objects.get(name) ;

			if (h == null){
				throw new InlineJavaException("Can't find thread " + name + "!") ;
			}
			else{
				i = h.values().size() ;
			}
		}
		catch (InlineJavaException e){
			debug(e.getMessage()) ;
		}

		return i ;
	}


	public Object Callback(String pkg, String method, Object args[]) throws InlineJavaException {
		try {
			Thread t = Thread.currentThread() ;
			if (t instanceof InlineJavaThread){
				// Client-server mode
				InlineJavaProtocol ijp = new InlineJavaProtocol(this, null) ;
				StringBuffer cmd = new StringBuffer("callback " + pkg + " " + method) ;
				if (args != null){
					for (int i = 0 ; i < args.length ; i++){
						 cmd.append(" " + ijp.SerializeObject(args[i])) ;
					}
				}
				System.out.println("Callback command: " + cmd.toString()) ;
				debug("Callback command: " + cmd.toString()) ;

				InlineJavaThread ijt = (InlineJavaThread)t ;
				ijt.bw.write(cmd.toString() + "\n") ;
				ijt.bw.flush() ;			

				String resp = ijt.br.readLine() ;

				System.out.println("Callback response: " + resp) ;
			}
			else{
				// JNI mode
			}
		}
		catch (IOException e){
			throw new InlineJavaException("IO error: " + e.getMessage()) ;
		}

		return null ;
	}


	/*
		Creates a string representing a method signature
	*/
	public String CreateSignature(Class param[]){
		return CreateSignature(param, ", ") ;
	}


	public String CreateSignature(Class param[], String del){
		StringBuffer ret = new StringBuffer() ;
		for (int i = 0 ; i < param.length ; i++){
			if (i > 0){
				ret.append(del) ;
			}
			ret.append(param[i].getName()) ;
		}

		return "(" + ret.toString() + ")" ;
	}


	synchronized public void debug(String s) {
		if (debug){
			System.err.println("java: " + s) ;
			System.err.flush() ;
		}
	}


	/*
		Startup
	*/
	public static void main(String[] argv) {
		new InlineJavaServer(argv) ;
	}


	public static InlineJavaServer jni_main(boolean debug) {
		return new InlineJavaServer(debug) ;
	}
	
	<INLINE_JAVA_OBJECT>

	<INLINE_JAVA_ARRAY>

	<INLINE_JAVA_CLASS>

	<INLINE_JAVA_PROTOCOL>

	/*
		Exception thrown by this code.
	*/
	class InlineJavaException extends Exception {
		InlineJavaException(String s) {
			super(s) ;
		}
	}


	/*
		Exception thrown by this code while trying to cast arguments
	*/
	class InlineJavaCastException extends InlineJavaException {
		InlineJavaCastException(String m){
			super(m) ;
		}
	}


	class InlineJavaInvocationTargetException extends InlineJavaException {
		Throwable t = null ;

		InlineJavaInvocationTargetException(String m, Throwable _t){
			super(m) ;
			t = _t ;
		}

		public Throwable getThrowable(){
			return t ;
		}
	}

	
	class InlineJavaThread extends Thread {
		InlineJavaServer ijs ;
		Socket client ;
		BufferedReader br ;
		BufferedWriter bw ;

		InlineJavaThread(InlineJavaServer _ijs, Socket _client) throws IOException {
			super() ;
			client = _client ;
			ijs = _ijs ;

			br = new BufferedReader(
				new InputStreamReader(client.getInputStream())) ;
			bw = new BufferedWriter(
				new OutputStreamWriter(client.getOutputStream())) ;
		}


		public void run(){
			try {
				ijs.thread_objects.put(getName(), new HashMap()) ;

				while (true){
					String cmd = br.readLine() ;

					String resp = ijs.ProcessCommand(cmd) ;
					if (resp != null){
						bw.write(resp) ;
						bw.flush() ;
					}
					else {
						break ;
					}
				}
			}
			catch (IOException e){
				System.err.println("IO error: " + e.getMessage()) ;
			}
			finally {
				ijs.thread_objects.remove(getName()) ;
			}
		}

		public void test(){
		}
	}
}


class InlineJavaServerThrown {
	Throwable t = null ;

	InlineJavaServerThrown(Throwable _t){
		t = _t ;
	}

	public Throwable getThrowable(){
		return t ;
	}
}
