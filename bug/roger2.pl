#!/usr/bin/perl -w

use warnings;

use Inline (
			Java => 'DATA',
			DEBUG => 0,
) ;

my $obj = JavaTestClass->new();

$obj->test();

#------------------------------------------------------------------------

package MODULE;

use Exporter;

@ISA       = ('Exporter');
@EXPORT_OK = ();

use strict;

sub new{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless($self,$class);
  return($self);
};

1;

package main ;
__DATA__

__Java__


import org.perl.inline.java.* ;

class JavaTestClass extends InlineJavaPerlCaller {

	public JavaTestClass() throws InlineJavaException
	{ System.out.println("JavaTestClass::Constructor");	}

	public void test() throws InlineJavaPerlException
	{
	  System.out.println("JavaTestClass::test");
	  try
		{
		  // require("MODULE");
		  InlineJavaPerlObject po = new InlineJavaPerlObject("MODULE", null );
		  System.out.println("created InlineJavaPerlObject");
		}  catch (InlineJavaException e) { e.printStackTrace(); }
		
	}
}

