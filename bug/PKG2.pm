package PKG2;

use strict;
use warnings;
use PKG1 ;

sub callpkg1 {
	print "allo1\n" ;
	print PKG1::PKG1->hello() ;
	print "allo2\n" ;
}


1 ;
