package Template::Plugin::TwoStage::Test;
BEGIN {
  $Template::Plugin::TwoStage::Test::VERSION = '0.05';
}
# ABSTRACT: derived class for self-tests only

use strict;
use warnings;
use base qw( Template::Plugin::TwoStage );
use File::Spec ();
use Cwd ();

__PACKAGE__->caching_dir( Template::Plugin::TwoStage::_concat_path( File::Spec->tmpdir(), [qw( alt_tt2_TwoStage )] ) );


sub read_test_file { 
	my ( $class, $test_file ) = @_;
	local $/;
	open( my $fh, "<", Template::Plugin::TwoStage::_concat_path( Cwd::cwd(), [ 't', $test_file ] ) ) or die $!;
	my $tests = <$fh>;
	close $fh;
	$tests;
}


sub tt_config {
 	my ( $class, $config ) = @_;

	return( 
	  {
		INCLUDE_PATH => [ Template::Plugin::TwoStage::_concat_path( Cwd::cwd(), [ 't', 'tt' ] ) ], 
		POST_CHOMP => 1,
		PLUGIN_BASE => 'Template::Plugin',
		EVAL_PERL => 1,
		( defined $config ? %{$config} : () )
	  }
	);
}


1;

__END__
=pod

=head1 NAME

Template::Plugin::TwoStage::Test - derived class for self-tests only

=head1 VERSION

version 0.05

=head2 METHODS

=head3 read_test_file

Pass name of text file containing test definitions suitable to be fed to Template::Test . Files are expected to reside in the t/ directory of this distribution.

=head3 tt_config

Returns a reference to a configuration hash with reasonable defaults suitable to be passed straight on to the TT constructor for working with test files included in this distribution. Accepts a reference to a configuration hash as first parameter that will be merged into the default configuration hash.

=for Pod::Coverage read_test_file tt_config

=head1 AUTHOR

Alexander Kühne <alexk@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Alexander Kühne.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

