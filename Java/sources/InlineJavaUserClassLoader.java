import java.net.* ;
import java.util.* ;


public class InlineJavaUserClassLoader extends URLClassLoader {
    private HashMap urls = new HashMap() ;


    public InlineJavaUserClassLoader(){
        super(new URL [] {}) ;
    }


    public void AddPath(URL u){
        if (urls.get(u) == null){
            urls.put(u, "1") ;
            addURL(u) ;
        }
    }
}
