#!/usr/bin/perl

package t::MOD_PERL ;

use strict ;

use CGI ;

use Inline (
	Java => '/home/patrickl/perl/dev/Inline-Java/t/counter.java',
	DIRECTORY => '/home/patrickl/perl/dev/Inline-Java/_Inline_web_test',
	BIN => '/usr/java/jdk1.3.1/bin',
	NAME => 't::MOD_PERL',
	SHARED_JVM => 1,
) ;


Inline::Java::release_JVM() ;

my $cnt = new t::MOD_PERL::counter() ;


sub handler {
	my $gnb = $cnt->gincr() ;
	my $nb = $cnt->incr() ;

	my $q = new CGI() ;
	print 
		$q->start_html() .
		"Inline-Java says this page received $gnb hits!<BR>" .
		"Inline-Java says this MOD_PERL ($$) served $nb of those hits." .
		$q->end_html() ;
}


1 ;

