use strict ;

use blib ;


use Inline Java => <<'END_OF_JAVA_CODE' ;
   class Pod_alu extends InlineJavaPerlCaller {
      public Pod_alu(){
      }

      public int add(int i, int j) throws InlineJavaException {
         try {
            CallPerl("main", "tt", null) ;
            CallPerl("main", "tt", new Object [] {"hello"}) ;
            CallPerl("main", "tt", new Object [] {"die"}) ;
         }
         catch (PerlException pe){
			System.out.println("perl died : " + (String)pe.GetObject()) ;
         }
		
         return i + j ;
      }

      public int subtract(int i, int j){
         return i - j ;
      }
   }   
END_OF_JAVA_CODE


sub tt {
	my $arg = shift ;

	print "$arg: it works!\n" ;
	if ($arg eq "die"){
		die("ouch!") ;
	}
}


my $alu = new Pod_alu() ;
print($alu->add(9, 16) . "\n") ; # prints 25
print($alu->subtract(9, 16) . "\n") ; # prints -7


