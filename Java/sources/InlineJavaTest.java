class InlineJavaTest {
	public static void main(String[] args){
		InlineJavaServer ijs = InlineJavaServer.jni_main(5) ;
		String resp = ijs.ProcessCommand("server_type") ;

		System.out.println(resp) ;
	}
}
