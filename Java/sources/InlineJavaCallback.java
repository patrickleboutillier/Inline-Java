package org.perl.inline.java ;

import java.util.* ;


/*
	Callback to Perl...
*/
class InlineJavaCallback {
	private String pkg = null ;
	private String method = null ;
	private Object args[] = null ;
	private String cast = null ;

	InlineJavaCallback(String _pkg, String _method, Object _args[], String _cast) {
		pkg = _pkg ;
		method = _method ;
		args = _args ;
		cast = _cast ;	
	}

	String GetCommand(InlineJavaProtocol ijp) throws InlineJavaException {
		StringBuffer cmdb = new StringBuffer("callback " + pkg + " " + method + " " + cast) ;
		if (args != null){
			for (int i = 0 ; i < args.length ; i++){
				 cmdb.append(" " + ijp.SerializeObject(args[i])) ;
			}
		}
		return cmdb.toString() ;
	}
}
