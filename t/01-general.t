#!/usr/bin/perl -w
use lib qw( ./lib ../blib );
use strict;
use warnings;
use Template::Test;
use Template::Plugin::TwoStage::Test;

my $tests = Template::Plugin::TwoStage::Test->read_test_file( 'general.tests' );

test_expect($tests, Template::Plugin::TwoStage::Test->tt_config() );
