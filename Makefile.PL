use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Template::Plugin::TwoStage',
    AUTHOR              => 'Alexander Kühne <alexander.kuehne@gmx.de>',
    VERSION_FROM        => 'lib/Template/Plugin/TwoStage.pm',
    ABSTRACT_FROM       => 'lib/Template/Plugin/TwoStage.pm',
    PL_FILES            => {},
#    EXE_FILES		=> [], # for a possible 'bin/purge_twostage_cache.pl' script
    PREREQ_PM => {
        'constant' => 0, # tested with 1.05
        'Test::More' => 0, # tested with 0.78
	'Class::Data::Inheritable' => 0, # tested with 0.04
	'Digest::SHA1' => 0, # tested with 2.11
	'Template' => 0, # tested with 2.19
	'URI::Escape' => 0, # tested with 3.28
	'File::Path' => 0, # tested with 1.08 
	'File::Spec' => 0, # tested with 3.12  
	'Cwd' => 0 # tested with 3.12
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Template-Plugin-TwoStage-*' },
);
