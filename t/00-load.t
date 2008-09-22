#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Template::Plugin::TwoStage' );
}

diag( "Testing Template::Plugin::TwoStage $Template::Plugin::TwoStage::VERSION, Perl $], $^X" );
