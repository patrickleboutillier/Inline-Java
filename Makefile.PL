use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'Inline::Java',
	VERSION_FROM => 'Java.pm',
	PREREQ_PM => {
		Inline	=> 0.31
	},
	# INC => join(" ", 
	# 	'-I/usr/java1.2/include',
	# 	'-I/usr/java1.2/include/solaris'
	# ),
	# LIBS => [
	# 	'-L/usr/java1.2/jre/lib/sparc -ljava'
	# ],
	clean => {FILES => '_Inline_test/'},
) ;
