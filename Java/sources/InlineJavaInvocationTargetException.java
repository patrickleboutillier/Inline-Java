class InlineJavaInvocationTargetException extends InlineJavaException {
	private Throwable t = null ;


	InlineJavaInvocationTargetException(String m, Throwable _t){
		super(m) ;
		t = _t ;
	}

	Throwable GetThrowable(){
		return t ;
	}
}
