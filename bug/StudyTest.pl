# Detta är en fil som använder Javaklasser fast med Inline.

use strict;
use FindBin ;
use lib $FindBin::Bin ;

use Time::HiRes; #För prestandatest!
my $Tstart = [Time::HiRes::gettimeofday];
use Inline ( Java => 'DATA',
            SHARED_JVM => 1, JNI => 0 );

Inline::Java::reconnect_JVM() ;


# Börja programmet!
use Person;
my $him = new Person;
$him->name('Nisse');
print ($him->name . "\n");
for(my $i; $i<1000;$i++) {
    my $javaVariable = new Program; 	# Skapa "javakontakt"
    $javaVariable->work;              	# Kör skriptet
    # print ($him->name . "\n");
    # print ("Hans polare är: ", join(", ", $him->peers), "\n");
}
# Programmet slut!
my $Tend = [Time::HiRes::gettimeofday];
my $tot = Time::HiRes::tv_interval($Tstart,$Tend);
print('Detta program tog: ' . $tot . ' sekunder att köra.' . "\n");

# Metod som används av Java!
sub perlMethods($$@) {                  # Kör perlmetoder på uppdrag av Java!
    my($objectName, $methodName,@inParam) = @_;
    return eval($objectName)->$methodName(@inParam);
}


__END__

__Java__

import org.perl.inline.java.*;

class Program {

    // Grundvärden
    PerlObject him = new PerlObject("$him");

    // Konstruktor
    public Program() throws InlineJavaException {
    }
    // Metod som gör något...
    public void work () {
       // Här skrivs skriptet i Java!


       String T = (String)him.method("name");
        if (T.equals("Nisse") )
            //him.method("name","Knut-Göran");
            him.method("name", new Object[] {"Knut-Göran" } );
        else
            him.method("name","Kurt-Arne");
        him.method("peers", new Object[] {"Tuve", "Bernt-Arne", "Nyman"} );


       // Här slutar skriptet som skrivits i Java!
    }
} ;

// Metodklass som används av Java!
class PerlObject extends InlineJavaPerlCaller {
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
} ;

