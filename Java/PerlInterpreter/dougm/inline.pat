--- Java/JNI.xs~	Mon Jun  3 08:50:57 2002
+++ Java/JNI.xs	Sat Dec 14 18:42:20 2002
@@ -17,6 +17,7 @@
 	jmethodID process_command_mid ;
 	jint debug ;
 	int destroyed ;
+        int embedded ;
 } InlineJavaJNIVM ;
 
 
@@ -137,6 +138,7 @@
 	RETVAL->ijs = NULL ;
 	RETVAL->debug = debug ;
 	RETVAL->destroyed = 0 ;
+	RETVAL->embedded = SvIV(get_sv("Inline::Java::JVM", TRUE)) == 2 ? 1 : 0;
 
 	options[0].optionString = ((RETVAL->debug > 5) ? "-verbose" : "-verbose:") ;
 	cp = (char *)malloc((strlen(classpath) + 128) * sizeof(char)) ;
@@ -148,8 +150,23 @@
 	vm_args.nOptions = 2 ;
 	vm_args.ignoreUnrecognized = JNI_FALSE ;
 
-	/* Create the Java VM */
-	res = JNI_CreateJavaVM(&(RETVAL->jvm), (void **)&(env), &vm_args) ;
+        if (RETVAL->embedded) {
+            /* we are already inside a JVM */
+            jint n = 0;
+
+            res = JNI_GetCreatedJavaVMs(&(RETVAL->jvm), 1, &n);
+            env = get_env(RETVAL);
+            RETVAL->destroyed = 1; /* do not shutdown */
+
+            if (n <= 0) {
+                /* res == 0 even if no JVMs are alive */
+                res = -1;
+            }
+        }
+        else {
+              /* Create the Java VM */
+              res = JNI_CreateJavaVM(&(RETVAL->jvm), (void **)&(env), &vm_args) ;
+        }
 	if (res < 0) {
 		croak("Can't create Java interpreter using JNI") ;
 	}
--- Java/JVM.pm~	Thu Jul  4 09:56:25 2002
+++ Java/JVM.pm	Sat Dec 14 18:41:10 2002
@@ -37,7 +37,7 @@
 	Inline::Java::debug(1, "starting JVM...") ;
 
 	$this->{owner} = 1 ;
-	if ($o->get_java_config('JNI')){
+	if (($Inline::Java::JVM = $o->get_java_config('JNI'))){
 		Inline::Java::debug(1, "JNI mode") ;
 
 		my $jni = new Inline::Java::JNI(
