package Inline::Java::Init ;


use strict ;

$Inline::Java::Init::VERSION = '0.10' ;

my $DATA = join('', <DATA>) ;
my $OBJECT_DATA = join('', <Inline::Java::Object::DATA>) ;
my $ARRAY_DATA = join('', <Inline::Java::Array::DATA>) ;
my $CLASS_DATA = join('', <Inline::Java::Class::DATA>) ;
my $PROTO_DATA = join('', <Inline::Java::Protocol::DATA>) ;


sub DumpUserJavaCode {
	my $fh = shift ;
	my $modfname = shift ;
	my $code = shift ;

	print $fh $code ;
}


sub DumpServerJavaCode {
	my $fh = shift ;
	my $modfname = shift ;

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
	public ServerSocket ss ;
	boolean debug = false ;

	public HashMap objects = new HashMap() ;
	public int objid = 1 ;

	// This constructor is used in JNI mode
	InlineJavaServer(boolean d) {
		debug = d ;
	}


	// This constructor is used in server mode
	InlineJavaServer(String[] argv) {
		String mode = argv[0] ;
		debug = new Boolean(argv[1]).booleanValue() ;

		if (mode.equals("report")){
			Report(argv, 2) ;
		}
		else if (mode.equals("run")){
			int port = Integer.parseInt(argv[2]) ;

			try {
				ss = new ServerSocket(port) ;
				Socket client = ss.accept() ;

				BufferedReader br = new BufferedReader(
					new InputStreamReader(client.getInputStream())) ;
				BufferedWriter bw = new BufferedWriter(
					new OutputStreamWriter(client.getOutputStream())) ;

				while (true){
					String cmd = br.readLine() ;

					String resp = ProcessCommand(cmd) ;
					bw.write(resp) ;
					bw.flush() ;
				}
			}
			catch (IOException e){
				System.err.println("Can't open server socket on port " + String.valueOf(port)) ;
			}
			System.exit(1) ;
		}
		else{
			System.err.println("Invalid startup mode " + mode) ;
			System.exit(1) ;
		}
	}


	public String ProcessCommand(String cmd){
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
			System.exit(1) ;
		}

		return resp ;
	}


	/*
		Returns a report on the Java classes, listing all public methods
		and members
	*/
	void Report(String [] class_list, int idx) {
		String module = class_list[idx] ;
		idx++ ;

		// First we must open the file
		try {
			File dat = new File(module + ".jdat") ;
			PrintWriter pw = new PrintWriter(new FileWriter(dat)) ;

			String data = ProcessReport(class_list, idx) ;
			pw.print(data) ; 
			pw.close() ;
		}
		catch (IOException e){
			System.err.println("Problems writing to " + module + ".jdat file: " + e.getMessage()) ;
			System.exit(1) ;			
		}
	}


	String ProcessReport(String [] class_list, int idx){
		StringBuffer pw = new StringBuffer() ;

		try {
			for (int i = idx ; i < class_list.length ; i++){
				if (! class_list[i].startsWith("InlineJavaServer")){
					StringBuffer name = new StringBuffer(class_list[i]) ;
					name.replace(name.length() - 6, name.length(), "") ;
					Class c = Class.forName(name.toString()) ;
															
					pw.append("class " + c.getName() + "\n") ;
					Constructor constructors[] = c.getConstructors() ;
					Method methods[] = c.getMethods() ;
					Field fields[] = c.getFields() ;

					for (int j = 0 ; j < constructors.length ; j++){
						Constructor x = constructors[j] ;
						String sign = CreateSignature(x.getParameterTypes()) ;
						Class decl = x.getDeclaringClass() ;
						pw.append("constructor" + " " + sign + "\n") ;
					}
					for (int j = 0 ; j < methods.length ; j++){
						Method x = methods[j] ;
						String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
						String sign = CreateSignature(x.getParameterTypes()) ;
						Class decl = x.getDeclaringClass() ;
						pw.append("method" + stat + decl.getName() + " " + x.getName() + sign + "\n") ;
					}
					for (int j = 0 ; j < fields.length ; j++){
						Field x = fields[j] ;
						String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
						Class decl = x.getDeclaringClass() ;
						Class type = x.getType() ;
						pw.append("field" + stat + decl.getName() + " " + x.getName() + " " + type.getName() + "\n") ;
					}
				}
			}
		}
		catch (ClassNotFoundException e){
			System.err.println("Can't find class: " + e.getMessage()) ;
			System.exit(1) ;
		}

		return pw.toString() ;
	}


	/*
		Creates a string representing a method signature
	*/
	String CreateSignature(Class param[]){
		return CreateSignature(param, ", ") ;
	}


	String CreateSignature(Class param[], String del){
		StringBuffer ret = new StringBuffer() ;
		for (int i = 0 ; i < param.length ; i++){
			if (i > 0){
				ret.append(del) ;
			}
			ret.append(param[i].getName()) ;
		}

		return "(" + ret.toString() + ")" ;
	}


	public void debug(String s) {
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
}
