import java.util.*;
import org.perl.inline.java.*;

public class XDB_TestHarness extends InlineJavaPerlCaller
        {
        static private InlineJavaPerlInterpreter pi = null;

        public XDB_TestHarness() throws InlineJavaException 
                {
    }

        public static void main(String argv[]) throws InlineJavaPerlException,
InlineJavaException
                {
                System.out.println("Test Harness for XDB Java <> Perl Bridge");
                if(argv.length != 4)
                        {
                        System.out.println("Usage\n$java XDB_TestHarness dbUserName dbPassword dbHost xdbDbDefinitionFilePath");
                        return;
                        }
                
                String sDbUser                                                                = argv[0];
                String sDbPassword                                                = argv[1];
                String sDbHost                                                                = argv[2];
                String sDbDefinitionFilePath        = argv[3];

                XDB xdb = null;

                System.out.println("Instantiating XDB...");
                try
                        {
                        xdb = new XDB(sDbUser, sDbPassword, sDbHost, sDbDefinitionFilePath);
                        }
                catch(InlineJavaPerlException pe)
                        {
                        System.out.println("PerlException: " + pe.GetString());
                        }
                catch(InlineJavaException je)
                        {
                        System.out.println("JavaException: " + je.getMessage());
                        }
                
                System.out.println("XDB object created.");

    pi.destroy();

                System.out.println("Done.");
                }
        };

class XDB
        {
        static private InlineJavaPerlInterpreter pi = null;
        static private InlineJavaPerlObject xdb = null;

        public XDB(String sDbUser, String sDbPassword, String sDbHost, String
sDbDefinitionFilePath) throws InlineJavaPerlException, InlineJavaException
                {
                System.out.print("Creating Perl interpreter...");
                pi = InlineJavaPerlInterpreter.create();
// this bit won't work unless you've got a module called "XDB" installed in @INC somewhere
//                pi.require_module("XDB");
                System.out.println("OK");

                System.out.print("Creating XDB instance...");

                HashMap hshDbConnection = new HashMap();
                hshDbConnection.put("User", sDbUser);
                hshDbConnection.put("Password", sDbPassword);
                hshDbConnection.put("Host", sDbHost);

/*
// this bit won't work unless you've got a module called "XDB" installed in @INC
somewhere
                xdb = (InlineJavaPerlObject) pi.CallPerlSub("XDB::new", new Object [] {"XDB",
hshDbConnection }, InlineJavaPerlObject.class);
                System.out.println("OK");

                System.out.print("Initializing XDB instance...");
                Integer ok = (Integer) xdb.InvokeMethod("DataDefinition", new Object [] {
sDbDefinitionFilePath }, Integer.class);
                if(ok.intValue() == 0)
                        {
                        String sError = (String) xdb.InvokeMethod("LastError", new Object [] {
sDbDefinitionFilePath }, String.class);
                        throw new InlineJavaPerlException("Error setting DataDefinition property: " +
sError);
                        }
*/
                System.out.println("OK");
    }

        protected void finalize()
                {
                System.out.println("finalizing");
                try
                        {
                        xdb.Dispose();
                        }
                catch(InlineJavaPerlException pe)
                        {
                        System.out.println("PerlException: " + pe.GetString());
                        }
                catch(InlineJavaException je)
                        {
                        System.out.println("JavaException: " + je.getMessage());
                        }
                }
        };
