package Inline::Java::private::Init ;

my $DATA = join('', <DATA>) ;
my $OBJECT_DATA = join('', <Inline::Java::private::Object::DATA>) ;
my $PROTO_DATA = join('', <Inline::Java::private::Protocol::DATA>) ;

sub DumpJavaCode {
	my $fh = shift ;
	my $modfname = shift ;
	my $code = shift ;

	my $java = $DATA ;
	my $java_obj = $OBJECT_DATA ;
	my $java_proto = $PROTO_DATA ;

	$java =~ s/<INLINE_JAVA_OBJECT>/$java_obj/g ;
	$java =~ s/<INLINE_JAVA_PROTOCOL>/$java_proto/g ;
	$java =~ s/<INLINE_JAVA_CODE>/$code/g ;

	$java =~ s/<INLINE_MODFNAME>/$modfname/g ;

	print $fh $java ;
}



1 ;



__DATA__

import java.net.* ;
import java.io.* ;
import java.util.* ;
import java.lang.reflect.* ;


<INLINE_JAVA_CODE>


public class <INLINE_MODFNAME> {
	public ServerSocket ss ;
	String module = "<INLINE_MODFNAME>" ;
	boolean debug = false ;

	public HashMap objects = new HashMap() ;
	public int objid = 1 ;

	<INLINE_MODFNAME>(String[] argv) {
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
					debug("  packet recv is " + cmd) ;

					if (cmd != null){
						InlineJavaProtocol ijp = new InlineJavaProtocol(this, cmd) ;
						try {
							ijp.Do() ;
							debug("  packet sent is " + ijp.response) ;
							bw.write(ijp.response + "\n") ;
							bw.flush() ;					
						}
						catch (InlineJavaException e){
							String err = "error scalar:" + ijp.unpack(e.getMessage()) ;
							debug("  packet sent is " + err) ;
							bw.write(err + "\n") ;
							bw.flush() ;
						}
					}
					else{
						System.exit(1) ;
					}
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


	void Report (String [] class_list, int idx){
		// First we must open the file
		try {
			File dat = new File(module + ".jdat") ;
			PrintWriter pw = new PrintWriter(new FileWriter(dat)) ;

			for (int i = idx ; i < class_list.length ; i++){
				if (! class_list[i].startsWith(module)){
					StringBuffer name = new StringBuffer(class_list[i]) ;
					name.replace(name.length() - 6, name.length(), "") ;
					Class c = Class.forName(name.toString()) ;
															
					pw.println("class " + c.getName()) ;
					Constructor constructors[] = c.getConstructors() ;
					Method methods[] = c.getMethods() ;
					Field fields[] = c.getFields() ;

					for (int j = 0 ; j < constructors.length ; j++){
						Constructor x = constructors[j] ;
						String sign = CreateSignature(x.getParameterTypes()) ;
						Class decl = x.getDeclaringClass() ;
						pw.println("constructor" + " " + sign) ;
					}
					for (int j = 0 ; j < methods.length ; j++){
						Method x = methods[j] ;
						String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
						String sign = CreateSignature(x.getParameterTypes()) ;
						Class decl = x.getDeclaringClass() ;
						pw.println("method" + stat + decl.getName() + " " + x.getName() + sign) ;
					}
					for (int j = 0 ; j < fields.length ; j++){
						Field x = fields[j] ;
						String stat = (Modifier.isStatic(x.getModifiers()) ? " static " : " instance ") ;
						Class decl = x.getDeclaringClass() ;
						Class type = x.getType() ;
						pw.println("field" + stat + decl.getName() + " " + x.getName() + " " + type.getName()) ;
					}					
				}
			}

			pw.close() ; 
		}
		catch (IOException e){
			System.err.println("Problems writing to " + module + ".jdat file: " + e.getMessage()) ;
			System.exit(1) ;			
		}
		catch (ClassNotFoundException e){
			System.err.println("Can't find class: " + e.getMessage()) ;
			System.exit(1) ;
		}
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


	public static void main(String[] argv) {
		new <INLINE_MODFNAME>(argv) ;
	}


	public void debug(String s) {
		if (debug){
			System.err.println("java: " + s) ;
		}
	}


	<INLINE_JAVA_OBJECT>



	<INLINE_JAVA_PROTOCOL>


	class InlineJavaException extends Exception {
		InlineJavaException(String s) {
			super(s) ;
		}
	}


	class InlineJavaCastException extends InlineJavaException {
		InlineJavaCastException(String m){
			super(m) ;
		}
	}
}



