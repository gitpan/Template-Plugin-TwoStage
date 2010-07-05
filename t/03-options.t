#!/usr/bin/perl -w
use lib qw( ./lib ../blib );
use strict;
use warnings;
use Template::Test;
use Template::Plugin::TwoStage::Test;
$Template::Test::DEBUG = 1;
$Template::Test::PRESERVE = 1;

my $tt1 = 
Template->new( 
	Template::Plugin::TwoStage::Test->tt_config( 
		{ 	PLUGINS => { TwoStage => 'Template::Plugin::TwoStage::Test' }, 
			TwoStage => { namespace => 'foo' } 
		} 
	) 
);

my $tt2 = 
Template->new( 
	Template::Plugin::TwoStage::Test->tt_config( 
		{ 	TwoStage => { namespace => 'foo' } 
		} 
	) 
);

test_expect(
	Template::Plugin::TwoStage::Test->read_test_file( 'options.tests' ), 
	[ derived => $tt1, base => $tt2 ] 
);
