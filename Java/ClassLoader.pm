package Inline::Java::ClassLoader ;


use strict ;

$Inline::Java::ClassLoader::VERSION = '0.35' ;


use Carp ;


1 ;


__DATA__


public class InlineJavaClassLoader extends URLClassLoader {
	private static InlineJavaClassLoader instance = null ;
	private HashMap urls = new HashMap() ;


	InlineJavaClassLoader(URL u){
		super(new URL [] {u}) ;
		instance = this ;
	}


	public static void AddPath(URL u){
		if (instance.urls.get(u) != null){
			instance.urls.put(u, "1") ;
			instance.addURL(u) ;
		}
	}	


    public static void main(String[] argv) {
		String path = argv[0] ;
		File p = new File(path) ;

		try {
			InlineJavaClassLoader cl = 
				new InlineJavaClassLoader(p.toURL()) ;
			Class sc = Class.forName("InlineJavaServer", true, cl) ;
			Constructor c = sc.getConstructor(
				new Class [] {argv.getClass()}) ;
			c.newInstance(new Object [] {argv}) ;
		}
		catch (MalformedURLException me){
			System.err.println("Invalid classpath entry '" + path + "': " + 
				me.getMessage()) ;
			System.err.flush() ;
        }
		catch (Exception e){
            System.err.println("Problem (" + e.getClass().getName() + 
				") loading InlineJavaServer class: " +
                e.getMessage()) ;
            System.err.flush() ;
		}
    }


    public static InlineJavaServer jni_main(int debug) {
        return new InlineJavaServer(debug) ;
    }
}
