/*
	This object can have user visibility and therefore
	must have public methods.
*/

class InlineJavaPerlException extends Exception {
	private Object obj = null ;


	InlineJavaPerlException(Object o) {
		obj = o ;
	}

	public Object GetObject(){
		return obj ;
	}

	public String GetString(){
		return (String)obj ;
	}
}
