use warnings;

use Inline (
			Java => 'DATA',
			DEBUG => 0,
) ;

package UPPER_MODULE::LOWER_MODULE;

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

package main ;


my $obj = JavaTestClass->new();

$obj->test();


__DATA__

__Java__


import org.perl.inline.java.* ;

class JavaTestClass extends InlineJavaPerlCaller {

	public JavaTestClass() throws InlineJavaException
	{ System.out.println("JavaTestClass::Constructor"); 
	  try
		{
		  // require("UPPER_MODULE::LOWER_MODULE");
		  InlineJavaPerlObject po = new InlineJavaPerlObject("UPPER_MODULE::LOWER_MODULE", new Object [] {} );
		  System.out.println("created InlineJavaPerlObject");
		}
		catch (InlineJavaPerlException pe) { pe.printStackTrace();}
	    catch (InlineJavaException e) { e.printStackTrace(); }
	}

	public void test() throws InlineJavaPerlException
	{
	  System.out.println("JavaTestClass::test");
	}
}
