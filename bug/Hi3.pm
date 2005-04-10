package Hi3;
use strict;
use warnings;

BEGIN {
	$ENV{CLASSPATH} .= "./Higher.jar";
}

use Inline Java => 'STUDY', STUDY => ['Higher'];

sub new {
	my $class = shift;
#	print "class name is $class \n";
	my $a = shift;
	my $b = shift;
	return Hi3::Higher->Higher($a, $b);
}

1;
