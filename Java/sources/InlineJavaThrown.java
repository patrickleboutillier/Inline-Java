class InlineJavaThrown {
	Throwable t = null ;

	InlineJavaThrown(Throwable _t){
		t = _t ;
	}

	Throwable GetThrowable(){
		return t ;
	}
}
