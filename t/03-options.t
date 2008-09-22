#!/usr/bin/perl -w
use lib qw( ./lib ../blib );
use strict;
use warnings;
use Template::Test;
use Template::Plugin::TwoStage::Test;

test_expect(
	Template::Plugin::TwoStage::Test->read_test_file( 'options.tests' ), 
	Template::Plugin::TwoStage::Test->tt_config( { PLUGINS => { TwoStage => 'Template::Plugin::TwoStage::Test'} } ) 
);
