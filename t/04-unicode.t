#!/usr/bin/perl -w
use lib qw( ./lib ../blib );
use strict;
use warnings;

use Test::More tests => 4;
use Encode qw( encode_utf8 is_utf8 );
use Template;
use Template::Plugin::TwoStage::Test ();

my $out;
my $t = Template->new( Template::Plugin::TwoStage::Test->tt_config() );

$t->process( 'test_chars.tt', {}, \$out );
ok( is_utf8( $out ), "test chars: utf8 flag set." );
#binmode(STDERR, ':encoding(utf8)');
#print STDERR $out;
ok( encode_utf8( $out ) eq encode_utf8( "H\x{00e4}llo Germany!\n" ), "test chars: Cached version is decoded." );

$out = '';
$t->process( 'test_octets.tt', {}, \$out );
ok( !is_utf8( $out ), "test octets: utf8 flag NOT set." );
#print STDERR $out;
ok( $out eq "H\x{00e4}llo Germany!\n", "test octets: Cached version is encoded." );
