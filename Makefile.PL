use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME => 'Inline::Java',
	      VERSION_FROM => 'Java.pm',
	      clean => {FILES => '_Inline_test/'},
	     );
