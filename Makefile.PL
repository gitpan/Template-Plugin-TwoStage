
use strict;
use warnings;

BEGIN { require 5.006; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'two stage processing of template blocks with first stage caching',
  'AUTHOR' => 'Alexander Kühne <alexk@cpan.org>',
  'BUILD_REQUIRES' => {
    'Template::Test' => '0',
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Template-Plugin-TwoStage',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Template::Plugin::TwoStage',
  'PREREQ_PM' => {
    'Class::Data::Inheritable' => '0',
    'Cwd' => '0',
    'Digest::SHA1' => '0',
    'Encode' => '0',
    'File::Path' => '0',
    'File::Spec' => '0',
    'Template' => '2.01',
    'Template::Exception' => '0',
    'Template::Parser' => '0',
    'Template::Plugin' => '0',
    'Template::Provider' => '0',
    'URI::Escape' => '0',
    'constant' => '0'
  },
  'VERSION' => '0.05',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



