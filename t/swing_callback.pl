#!/usr/bin/perl
use strict;
use warnings;

use Inline Java => "DATA";

my $greeter = MyButton->new();
while (1) { sleep(100000) };

###########################################

sub button_pressed
{
  print "Button Pressed (from perl)\n"
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
      CallPerl("main", "button_pressed", new Object [] {});
    }
    catch (InlineJavaPerlException pe)  { }
    catch (InlineJavaException pe) { }
  }
}
