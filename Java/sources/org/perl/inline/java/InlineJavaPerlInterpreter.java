package org.perl.inline.java ;


/*
	InlineJavaPerlInterpreter

	This singleton class creates a PerlInterpreter object. To this object is bound
	an instance of InlineJavaServer that will allow communication with Perl.

	All communication with Perl must be done via InlineJavaPerlCaller in order to insure
	thread synchronization.	Therefore all Perl actions will be implemented via functions
	in Inline::Java::PerlInterperter so that they can be called via InlineJavaPerlCaller
*/
public class InlineJavaPerlInterpreter extends InlineJavaPerlCaller {
	static private boolean inited = false ;
	static InlineJavaPerlInterpreter instance = null ;
	private InlineJavaServer isj = null ;


	protected InlineJavaPerlInterpreter(int d) throws InlineJavaPerlException {
		init() ;
		ijs = InlineJavaServer.jni_main(d) ;
	}


	public InlineJavaPerlInterpreter getInstance(int d) throws InlineJavaPerlException {
		if (instance == null){
			instance = new InlineJavaPerlInterpreter(d) ;
		}
		return instance ;
	}


	static protected void init() throws InlineJavaException {
		init("install") ;
	}


	synchronized static protected void init(String mode) throws InlineJavaException {
		InlineJavaPerlCaller.init() ;
		if (! inited){
			try {
				String perlinterpreter_so = GetBundle().getString("inline_java_perlinterpreter_so_" + mode) ;
				File f = new File(natives_so) ;
				if (! f.exists()){
					throw new InlineJavaException("Can't initialize PerlInterpreter " +
						"functionnality: PerlInterpreter extension (" + natives_so +
						") can't be found") ;
				}

				// Load the Natives shared object
				InlineJavaUtils.debug(2, "loading shared library " + perlinterpreter_so) ;
				System.load(perlinterpreter_so) ;

				inited = true ;
			}
			catch (MissingResourceException mre){
				throw new InlineJavaException("Error loading InlineJava.properties resource: " + mre.getMessage()) ;
			}
		}
	}


	/*
    int perlInterpreter = 0;

    public PerlInterpreter() {
        create(null);
    }

    public int getPerlInterpreter() {
        return perlInterpreter;
    }

    private native PerlInterpreter create(PerlInterpreter perl)
        throws RuntimeException;

    public native String eval(String code) throws PerlException;

    public native void destroy();

    public static void main(String[] args) {
        try {
            System.loadLibrary("PerlInterpreter");

            PerlInterpreter perl = new PerlInterpreter();
            System.setProperty("PERL", "XXX");
            String val = perl.eval("require 'test.pl'");
            System.out.println(val);
            perl.destroy();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

	*/
}
