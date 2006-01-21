#!/usr/bin/perl
use strict;
use warnings;

use Inline Java => "DATA";

my $cnt = 0 ;
my $greeter = MyButton->new();
$greeter->StartCallbackLoop() ;
print "loop done\n" ;


###########################################


sub button_pressed {
  $cnt++ ;
  print "Button Pressed $cnt times (from perl)\n" ;
  if ($cnt > 10){
	 print "sleep starting\n" ;
	 sleep(10) ;
	 print "sleep stopping\n" ;
	 # $greeter->StopCallbackLoop() ;
  }
 
  return $cnt ;
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
  private String cnt = "0" ;

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
      if (cnt.equals("10")){
        InterruptWaitForCallback() ;
      }
      cnt = (String)CallPerlSub("main::button_pressed", new Object [] {});
      System.out.println("Button Pressed " + cnt + " times (from java)") ;
    }
    catch (InlineJavaPerlException pe)  { }
    catch (InlineJavaException pe) { pe.printStackTrace() ;}
  }
}
