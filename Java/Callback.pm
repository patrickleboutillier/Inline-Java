package Inline::Java::Callback ;


use strict ;

$Inline::Java::Callback::VERSION = '0.31' ;


use Carp ;


__DATA__

/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	protected InlineJavaPerlCaller(){
	}


	class InlineJavaPerlCallerException extends Exception {
		InlineJavaPerlCallerException(String s) {
			super(s) ;
		}
	}


	protected Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaPerlCallerException {
		try {
			return InlineJavaServer.instance.Callback(pkg, method, args) ;
		}
		catch (InlineJavaServer.InlineJavaException e){
			throw new InlineJavaPerlCallerException(e.getMessage()) ;
		}
	}
}


