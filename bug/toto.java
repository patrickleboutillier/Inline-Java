import java.util.* ;

class toto {
	static public void main(String args[]){
		HashMap h = new HashMap() ; 

		h.put("key", "value") ;
		Object valArr[] = h.entrySet().toArray() ;

		for (int i = 0 ; i < valArr.length ; i++){
			System.out.println(valArr[i]) ;
		}
	}
}
