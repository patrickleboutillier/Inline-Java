import org.perl.inline.java.*;

public class Program {

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
}
