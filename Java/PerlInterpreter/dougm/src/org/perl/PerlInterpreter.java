package org.perl;

public class PerlInterpreter {
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
}
