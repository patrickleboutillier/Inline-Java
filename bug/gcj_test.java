import java.lang.reflect.* ;


public class gcj_test {
	public static void main(String[] args){
		try	{
			obj o = new obj() ;
			Class c = Class.forName("obj") ;

			Method methods[] = c.getMethods() ;
			Field fields[] = c.getFields() ;
			Method m = null ;
			Field f = null ;
			for (int i = 0 ; i < methods.length ; i++){
				if (methods[i].getName().equals("f")){
					m = methods[i] ;
					break ;
				}
			}
			for (int i = 0 ; i < fields.length ; i++){
				if (fields[i].getName().equals("s")){
					f = fields[i] ;
					break ;
				}
			}


			Object a[] = {"test"} ;
			m.invoke(o, a) ;
			f.set(o, "test") ;
			System.out.println("s set to 'test'") ;
			System.out.println("s = " + (String)f.get(o)) ;
			a[0] = null ;
			m.invoke(o, a) ;
			f.set(o, null) ;
			System.out.println("s set to null") ;
			System.out.println("s = " + (String)f.get(o)) ;
			f.get(o) ;
		}
		catch (Exception e){
			System.err.println(e.getClass().getName() + ": " + e.getMessage()) ;
			System.exit(1) ;
		}

		System.out.println("Done") ;
	}
}


class obj {
	public String s = null ;

	public void f(String s){
		System.out.println("f invoked with param " + s) ;
	}
}