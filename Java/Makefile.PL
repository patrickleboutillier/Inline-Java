use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'Inline::Java::JNI',
	VERSION_FROM => 'JNI.pm',
	INC => join(" ", 
		'-I/usr/java1.2/include',
		'-I/usr/java1.2/include/solaris'
	),
	LIBS => [
		'-L/usr/java1.2/jre/lib/sparc -ljvm'
	],
) ;
