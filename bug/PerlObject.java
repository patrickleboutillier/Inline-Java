import org.perl.inline.java.*;

// Metodklass som används av Java!
public class PerlObject extends InlineJavaPerlCaller {
    String perlName;
    // Konstruktor
    public PerlObject(String perlName) throws InlineJavaException {
        this.perlName = perlName;
    }
    // Metod för att kalla på Perlobjektens egna metoder.
	public Object method (String methodName) {
	    try {
                Object ret = CallPerl( "main", "perlMethods", new Object[] {perlName, methodName} );
		return ret == null ? new Integer(1) : ret;
            }
	    catch (Exception e) {
                return new Integer(-1);
            }
	}
	public Object method (String methodName, Object arg) {
	    try {
                Object ret = CallPerl( "main", "perlMethods", new Object[] {perlName, methodName, arg} );
		return ret == null ? new Integer(1) : ret;
            }
	    catch (Exception e) {
                return new Integer(-1);
            }
	}
    public Object method (String methodName, Object arg[]) {
        try {
			Object[] perlArg = new Object [arg.length+2];
			perlArg[0] = perlName;
			perlArg[1] = methodName;
			for (int i = 0; i < arg.length; i++) {
		    	perlArg[i+2] = arg[i];
			}
            Object ret = CallPerl( "main", "perlMethods", perlArg );
			return ret == null ? new Integer(1) : ret;
	    }
        catch (Exception e) {
            return new Integer(-1);
        }
    }
}
