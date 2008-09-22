package Template::Plugin::TwoStage::Test;
use strict;
use warnings;
use base qw( Template::Plugin::TwoStage );
use File::Spec ();
use Cwd ();
use Template::Test ();

$Template::Test::DEBUG = 1;
$Template::Test::PRESERVE = 1;

__PACKAGE__->caching_dir( &Template::Plugin::TwoStage::_concat_path( File::Spec->tmpdir(), [qw( alt_tt2_TwoStage )] ) );

sub read_test_file { 
	my ( $class, $test_file ) = @_;
	local $/;
	open( FH, "< ".&Template::Plugin::TwoStage::_concat_path( Cwd::cwd(), [ 't', $test_file ] ) ) or die $!;
	my $tests = <FH>;
	close FH;
	$tests;
}

sub tt_config {
 	my ( $class, $config ) = @_;

	return( 
	  {
		INCLUDE_PATH => [ &Template::Plugin::TwoStage::_concat_path( Cwd::cwd(), [ 't', 'tt' ] ) ], 
		POST_CHOMP => 1,
		PLUGIN_BASE => 'Template::Plugin',
		EVAL_PERL => 1,
		( defined $config ? %{$config} : () )
	  }
	);
}

sub dump_options {
	my $self = shift;
	
	my $options_dump = '';
	map { $options_dump.= "$_: ".( defined $self->{CONFIG}->{$_} ? $self->{CONFIG}->{$_} : '' )."\n" } sort keys %{$self->{CONFIG}};
	$options_dump;
}

1;
