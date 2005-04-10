package PKG1;

use strict;
use warnings;

use Inline Java => "DATA";

sub new
{
    my $class = shift;
    return  PKG1::PKG1->new(@_);
}

1;

__DATA__
__Java__
import java.util.*;
import java.io.*;

public class PKG1 {
	public static String hello(){
		return "hello" ;
	}
}
