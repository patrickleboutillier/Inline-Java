import javax.xml.parsers.*;
import org.apache.xerces.jaxp.SAXParserFactoryImpl;

public class Foo {

  // This method works!
  public void test_a() throws 
  javax.xml.parsers.ParserConfigurationException,
  org.xml.sax.SAXException
  {
  javax.xml.parsers.SAXParserFactory si = org.apache.xerces.jaxp.SAXParserFactoryImpl.newInstance() ;
   SAXParser y = si.newSAXParser() ;
  }

public void test_b() throws 
  javax.xml.parsers.ParserConfigurationException,
  org.xml.sax.SAXException
  {
  System.out.println("!!!" + getClass().getClassLoader() + "!!!") ;
  System.setProperty("javax.xml.parsers.SAXParserFactory",
                  "org.apache.xerces.jaxp.SAXParserFactoryImpl");
  SAXParser x = javax.xml.parsers.SAXParserFactory.newInstance().newSAXParser();
  }

  static public void main(String args[]){
	try {
		Foo f = new Foo() ;
	    f.test_a() ;
	    f.test_b() ;
	}
	catch (java.lang.Exception e){
		e.printStackTrace() ;
	}
  }
} 

