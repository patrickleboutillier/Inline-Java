#!/usr/bin/perl
use strict;
use warnings;

use Inline Java => "DATA";

my $cnt = 0 ;
my $greeter = MyButton->new();
eval {
	$greeter->StartCallbackLoop() ;
	print "done\n" ;
} ;
if ($@){
	$@->printStackTrace() ;
}


###########################################


sub button_pressed {
  my $o = shift ;
  my $id = shift ;
  print "Button $id Pressed (from perl)\n" ;
  if ($cnt >= 10){
	 $o->StopCallbackLoop() ;
  }
  $cnt++ ;
}

__DATA__
__Java__

import java.util.*;
import org.perl.inline.java.*;
import javax.swing.*;
import java.awt.event.*;

public class MyButton extends    InlineJavaPerlCaller
                      implements ActionListener
{
  public MyButton() throws InlineJavaException
  {
    // create frame
    JFrame frame = new JFrame("MyButton");
    frame.setSize(200,200);

    // create button
    JButton button = new JButton("Click Me!");
    frame.getContentPane().add(button);

    // tell the button that when it's clicked, report it to
    // this class.
    button.addActionListener(this);

    // all done, everything added, just show it
    frame.show();
  }

  public void actionPerformed(ActionEvent e)
  {
    try
    {
      CallPerl("main", "button_pressed", new Object [] {this,  new Integer(1)});
      CallPerl("main", "button_pressed", new Object [] {this,  new Integer(2)});
      CallPerl("main", "button_pressed", new Object [] {this,  new Integer(3)});
    }
    catch (InlineJavaPerlException pe)  { }
    catch (InlineJavaException pe) { pe.printStackTrace() ;}
  }
}
