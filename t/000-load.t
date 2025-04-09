#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

our $VERSION = '0.10';

plan tests => 1;

BEGIN {
    use_ok( 'WWW::Mechanize::Chrome::DOMops' ) || print "Bail out!\n";
}

diag( "Testing WWW::Mechanize::Chrome::DOMops $WWW::Mechanize::Chrome::DOMops::VERSION, Perl $],
 $^X" );

