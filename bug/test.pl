#!/usr/bin/perl

use strict;
use warnings;
use lib "bug" ;
use PKG1;

print PKG1->hello() ;

# use PKG2 ;
# PKG2::callpkg1() ;
 
