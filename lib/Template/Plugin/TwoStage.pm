package Template::Plugin::TwoStage;

use warnings;
use strict;

use base qw( Template::Plugin Class::Data::Inheritable );
use Template::Plugin;
use Template::Parser;
use Template::Exception;

use File::Path qw( rmtree mkpath );
use File::Spec ();
use Digest::SHA1 qw( sha1_hex );

use constant { 
	DEBUG => 0,
	UNSAFE => '^A-Za-z0-9_',
	CACHE_DIR_NAME => 'TT_P_TwoStage'
};

BEGIN  { 
	eval qq|
	use URI::Escape::XS qw( uri_escape );
	|;

	if ($@) {
		print STDERR "URI::Escape::XS not available ($@)...\n" if DEBUG;
		eval qq|
		use URI::Escape qw( uri_escape );
		|;
		die "URI::Escape not available ($@)..." if $@;
	} else {
		print STDERR "URI::Escape::XS available ...\n" if DEBUG;
	}
};

our $TAG_STYE_unquotemeta = {
	map { 
		my @tags = @{$Template::Parser::TAG_STYLE->{$_}}; 
		( $_, [ map { $_ =~ s/\\([^A-Za-z_0-9]{1})/$1/g; $_ } @tags ] )
	} keys %$Template::Parser::TAG_STYLE
};

=head1 NAME

Template::Plugin::TwoStage - two stage processing of template blocks with first stage caching

=head1 VERSION

Version 0.01_01

=cut

our $VERSION = '0.01_01';


=head1 SYNOPSIS

This is a plugin for the Template Toolkit that facilitates a two stage processing of BLOCKs with first stage caching. Processing results of the first (precompilation) stage are cached away for subsequent repeated processing in the second (runtime) stage. Precompilation and runtime tags are seperated by using different tag styles.

Basic usage in the a TT2-template:

   [% 	USE cache = TwoStage( namespace => application.name ); # make an application specific namespace 
	cache.process( 'template' => 'cached_page', keys => { 'bar' => bar  }, ttl => 60 * 60 );
   	BLOCK cached_page; 
		# use precompile tags or runtime tags here
   %]
		[* foo # runtime stage evaluation *]	
		[% IF bar; # precompilation stage evaluation 
			# ... 
		   ELSE;
		   	# ...
		   END;
		%]	
   [%	END %]

=head2 More features 

=over

=item * subclassable

Make your own application specific subclass of this module and avoid repeated application wide configuration of the plugin on each use in different templates.

=item * parameterized precompilation of a single block

Pass keys as additional identifiers of a BLOCK, based upon which the BLOCK produces a different precompiled output/version of the BLOCK. 

=item * expiration 

Give the precompiled BLOCKs a 'time to live' before they expire.

=item * namespaces

Distinguish different e.g. applications in one process by the use of namespaces.

=item * development mode

Edit your templates with caching turned off. The development mode also gives you convenient access to the precompiled versions produced for validation of your separation of precompilation and runtime directives.

=item * flexible customization

Set your basic configuration in a subclass, and override any configuration option on plugin instantiation or even on specific plugin method calls in the templates.

=back

=head1 MOTIVATIONS FOR USE

You might benefit from this module if ... 

=over 4

=item  

... you have static external content e.g. from databases or .po-files that you want to pull into your templates only once while still being able to insert dynamic data into the same template

=item 

... you are following the DRY principle by having a central BLOCK library that you use to style your GUI HTML components

=item 

... you do not want to use ttree because you prefer "lazy" precompilation (only on demand), and you want to see your changes to the template without running an external program first

=back

=head1 SUBCLASSING 

This plugin is subclassable. Though it is possible to use this module without subclassing it, subclassing has many benefits and is the recommended way of use. Subclassing allows you to customize your plugin behaviour at a single place, and extend the template signature by some default keys. Still it lets you override the configuration on plugin instantiation or even on the call of the include() or precompile()-methods at your will with only local scope.

=head2 Sample code

   package Your::Application::Template::Plugin::TwoStage;
   use base qw( Template::Plugin::TwoStage Your::Application );

   __PACKAGE__->caching_dir( __PACKAGE__->Application->config->tmp_dir() );
   __PACKAGE__->dev_mode( 1 );
   __PACKAGE__->ttl( 60 * 60 ); # 1 h
   __PACKAGE__->dir_keys( 1 );
   __PACKAGE__->runtime_tag_style( 'html' );

   sub extend_keys {
        my ( $self, $keys ) = @_;
        my $context = $self->{CONTEXT};
        my $stash = $context->stash();

        # hook method for adding standard keys - return the keys => value -hash by reference! 
        { domain => __PACKAGE__->Application->request->uri->authority,
	  language => __PACKAGE__->Application->request->language,
	  logged_in => __PACKAGE__->Application->request->session->logged_in,
	  gui_style => __PACKAGE__->Application->request->session->preferences->gui_style
	};

   }

Don't forget to add your sublcass to the plugin base of your TT2-configuration:

	PLUGIN_BASE => [ 'Your::Application::Template::Plugin' ]

or declare it via the PLUGINS TT2-configuration option

	PLUGINS => { TwoStage => 'Your::Application::Template::Plugin::TwoStage', ... }

=cut


=head2 Configuration Options 

Configuration options may be set with different scopes. When subclassing this module a subclass wide configuration can be achieved by using the inheritable class data accessors provided via Class::Data::Inheritable. See also the sample code above.

The following configuration options may be set 

   ... as class data for this module or a derived class:
       
	caching_dir
	dev_mode
	ttl
	namespace
	dir_keys
	runtime_tag_style

	__PACKAGE__->caching_dir( $some_path );

   ... on plugin instantiation for the scope of the plugin object
   ... and on the call of the include() or precompile()-methods valid for the present call:

	dev_mode
	ttl
	namespace
	dir_keys
	runtime_tag_style

	[% TwoStage = USE TwoStage( ttl => 3600 ); 
	   ...
	   TwoStage.process( template => 'some_template', ttl => 1800 );
	%]

=head3 caching_dir

The directory 'TT_P_TwoStage' in your platform specific tmp-directory determined with the help of File::Spec->tmpdir() is the default setting here. Pass a path in order to change it to some other directory - it will also be extended by a subdirectory 'TT_P_TwoStage'. In contrast to all the other configuration options this option can only be set as class data.

=cut

sub caching_dir {
   my $class = shift;
   
   if (@_) {
    	# we also include $class to distinguish applications in the file system
	return
	$class->_caching_dir(
		&_concat_path( 
			shift, 
			[ 	CACHE_DIR_NAME, 
				do {
					uri_escape( $class, UNSAFE ) 
				}
			]
		)

	);
   }
   $class->_caching_dir;
}
__PACKAGE__->mk_classdata( '_caching_dir' );

=head3 dev_mode

Set this configuration option to a TRUE value in order to disable the use of cached files and see your changes to cached BLOCKs immediately while still having access to the precompiled versions on disc for their validation.

See also the configuration option 'dir_keys' as another interesting feature for development.

=cut

__PACKAGE__->mk_classdata( dev_mode => 0 );

=head3 ttl

Specify the "time to live" for the precompiled versions of the BLOCKs in seconds - 0 is 'no expiration' and the default setting.

=cut

__PACKAGE__->mk_classdata( ttl => 0 ); 

=head3 dir_keys

Usually the keys connected to a precompiled version are included among other things into the file name of a BLOCK in order to identify a precompiled cached BLOCK on disc. This is accomplished by using the SHA1 hash function.

To make the retrieval of a certain caching file easier for humans, the configuration parameter 'dir_keys' lets you include the keys into the file path of the precompiled cached BLOCK. This behaviour might be handy in cases where one wants to inspect the precompiled versions produced.

Set 'dir_keys' either to an array reference holding a selection of keys or a scalar holding a TRUE value for all keys. This feature is available in development mode only! See also configuration option 'dev_mode'.   

See also the section PLUGIN OBJECT METHODS for more on the 'keys' parameter.

=cut

__PACKAGE__->mk_classdata( dir_keys => undef ); 
						
=head3 namespace

By default we incorporate the BLOCK name together with the TT2 meta variables 'component.callers' and 'component.name' - which in turn is the call stack of BLOCKs and templates to the BLOCK from the outermost file the BLOCK was included in - into the caching signature in order to achieve the used BLOCK name is having only file scope.

Furthermore we avoid interference of template signatures of different subclasses of this module by file system paths.

If you choose not to subclass this module for an application you can ensure the segmentation of applications by setting the 'namespace' configuration option accordingly. This approach has the drawback that you need to set this configuration option in each template on plugin instantiation: 

    USE TwoStage( namespace => application_name );

=cut

__PACKAGE__->mk_classdata( namespace => undef );

=head3 runtime_tag_style

Set this option to one of the predefined tag styles TT is offering like 'php', 'mason', 'html', ..., and that are accepted by TT as a value to its 'TAG_STYLE' configuration option or 'TAGS' directive. Default is: star ([* *]).

Excursus: precompilation tag style

The precompilation tag style is always the tag style set in the TT configuration or 'default'. A tag style defined local to the file the plugin is being called in ( by means of the 'TAGS'-directive at the beginning of the file) will be handled correctly - this file scoped tag style will also be used in the BLOCK to be precompiled as precompilation tag style.

Changing the tag style only for a certain BLOCK that is to be precompiled is not possible, as the 'TAGS' directive can be set only on per template file basis. A centralized configuration of the precompilation tag style to be used is not available to date.

=cut

__PACKAGE__->mk_classdata( runtime_tag_style => 'star' );

__PACKAGE__->mk_classdata( precompile_tag_style => undef ); # is always the configured tag style of Template - NO TwoStage econfig option

=head2 Object hook methods 

=head3 extend_keys

With this callback method it is possible to merge some default keys into the template signature. The values of the keys introduced this way will be dominated by the values of identical keys passed to process() or include(). Return a hash reference mapping standard signature keys to its values! Have a look at the sample code above.

=cut

sub extend_keys {
    my $self = shift;
    my $context = $self->{CONTEXT};
    my $stash = $context->stash();

    # hook method for adding standard keys - return the keys => value -hash by reference! 
    {};
}

=head2 Exports

None. 

=cut

# TT2 PLUGIN HOOK METHODS

sub load {
    my ($class, $context) = @_;
    
    # register cache_dir with TT2-config variable INCLUDE_PATH
    $class->caching_dir || $class->caching_dir( File::Spec->tmpdir() ); 
    
    unshift @{$context->{CONFIG}->{INCLUDE_PATH}}, 
    do { 
        my ($volume, $directories, $file) = File::Spec->splitpath( $class->caching_dir, 1 );
    	File::Spec->catpath(
    		$volume,
		File::Spec->catdir( 
			do { my @dirs = File::Spec->splitdir( $directories ); pop @dirs; @dirs }
		) 
    		,
		$file
    	);
    }; 
    mkpath( $class->caching_dir, 0, 0700 ) if !-e $class->caching_dir;
    
    print STDERR "$class:\nwe use caching dir ".$class->caching_dir()."\n" if DEBUG;
    return $class;
}


sub new {     
    my ($class, $context, @params) = @_;
    
    print STDERR "new $class\n" if DEBUG;
    $class->create($context, @params); 
}    	

sub error {
    my $proto = shift;
    $proto->SUPER::error(@_);
    die( Template::Exception->new( 'TwoStage', $proto->SUPER::error ) );
}

sub create {
    my ($class, $context, $params) = @_;

    print STDERR "create \n" if DEBUG;

    # let %params overwrite any configurations from drawn from class data 
    # - 'configuration' might end up also in CONFIG but will never be retrieved from there later in the code
    bless {
 	CONTEXT => $context,
	CONFIG => { 
		dev_mode => $class->dev_mode, 
		namespace => $class->namespace, 
		ttl => $class->ttl,
		dir_keys => $class->dir_keys,
		precompile_tag_style => ( $class->precompile_tag_style || $context->{CONFIG}->{TAG_STYLE} || 'default' ),
		runtime_tag_style => $class->runtime_tag_style,
		( 	defined $params ? 
			do{ delete $params->{caching_dir}; delete $params->{precompile_tag_style}; %$params } : 
			() 
		)
	}
    }, $class;
}

=head1 PLUGIN OBJECT METHODS

Once the plugin object has been pulled into the template by means of the 'USE' directive, calling the plugin object methods include() or process() against it will insert the BLOCK content with all the precompilation and caching magic delivered by this plugin into the template.

Named parameters of process/include:

=over 4

=item * template 

Specify the name of the BLOCK to be processed/included into the template here. Its name does not have to be template spanning unique. The plugin takes care that the name is local to the template it is defined in. 

=item * keys (optional)

Use this parameter in situations where you want to evaluate a certain stash variable in the precompilation stage, and that variable can take on only a limited set of discrete values but has considerable influence on the precompiled versions. Examples for such variables might be: template language, user preferences, user privileges, ...

Each combination of the values of the variables passed as 'keys' parameter will produce a distinct precompiled version of the BLOCK in question. Take care not to choose to many keys with to many values in order to produce only a reasonable number of precompiled versions.

If you find some keys are supposed to be added to each and every call to process() or include() consider subclassing this plugin and using the extend_keys() hook method (see also above).

=item * all of the available configuration options (optional)

For more on those options see section "Configuration Options" in this documentation.

=back

include() is exposing an identical behaviour as process() with the exception that it does stash localisation in the runtime stage.

=cut

sub process {
    my $self = shift;
    my $params = shift;
    my $localize = shift || 0;
    my $context = $self->{CONTEXT};
    my $stash = $context->stash();

    exists( $params->{template} ) || $self->error( "Pass template => \$name !" );
    $self->{prec_template} = {}; # reset template properties
    $self->{params} = $params; # parameters handed to process()
    $self->{params}->{keys} = $self->_complement_keys( $params->{keys} || {} );

    local $self->{CONFIG} = 
    { 
    	%{$self->{CONFIG}},
	do{ my %p = %{$params};
	    delete $p{template};
	    delete $p{keys}; 
	    delete $p{caching_dir}; 
	    delete $p{precompile_tag_style}; 
	    %p 
	} 
    }; # making the config options local to this call

    if ( $stash->get( 'TwoStage.precompile_mode') ) {    
    	# don't do runtime phase processing if the template is called in precompilation mode
    	print STDERR "$params->{template}: precompile_mode ack..." if DEBUG;
	return $context->process( $params->{template}, {}, 1 );	
    }

    # stat() it first to play safely with negative caching of TT2 introduced in recent versions 
    # in combination with a positive STAT_TTL!
    if ( !$self->{CONFIG}->{dev_mode} ) {
    	print STDERR 
	"try using cached version of component ($params->{template}) ".$self->_signature."\n"
      	."INCLUDE_PATH: ".join( ' : ', @{$context->{CONFIG}->{INCLUDE_PATH}} )."\n" 
		if DEBUG;

    	print STDERR "keys: \n".( join "\n", map { "$_ -> $self->{params}->{keys}->{$_}" } keys %{$self->{params}->{keys}} )."\n\n" if DEBUG;

	my @stat = stat( $self->_file_path );

	print STDERR "ttl: $self->{CONFIG}->{ttl} ".time()." <= ".( $stat[9] + $self->{CONFIG}->{ttl})."\n" 
		if DEBUG && scalar( @stat ); 

        if ( scalar( @stat ) 
	     && 
	     ( !$self->{CONFIG}->{ttl} || time() <= ($stat[9] + $self->{CONFIG}->{ttl}) ) 
	) {
    		print STDERR "file ".$self->_file_path." successfully stat()ed\n" if DEBUG;
		my $output;
		eval {
			$output = 
			$context->process( 
				uri_escape( ref($self), UNSAFE ).'/'
				.( do { my $dirs = join( '/', @{$self->_dynamic_dir_segments} ); $dirs ? $dirs.'/' : '' } )
				.$self->_signature, 
				{},
				$localize
			);  
    		};
	    	$self->error( "Retrieval though stat()'ed successfully (".$self->_file_path."): FAILED ($@)\n" ) if $@;
        	print STDERR "Using cached output:\n\n $output\n\n" if DEBUG;
    		return $output;
	}
    }

    # process precompiled component
    return $context->process( $self->_precompile, {}, $localize ); 
}

sub include {
    (shift)->process( @_, 1 );
}

=head1 CACHING

Having precompiled a BLOCK the TwoStage plugin assigns a unique identity (signature) to it, and writes it to the disk using a SHA1 fingerprint of the signature as the filename. Now all processes sharing the same caching directory and namespace will always retrieve this precompiled version of the BLOCK.

The precompiled version is retrieved using the standard loading mechanism of the Template Toolkit as any other template. Please note that the STAT_TTL configuration of TT however will not work for those cached precompiled versions as you make modifications to the "source" BLOCKS of those cached templates.

In order to set back caching remove the cached templates from your caching directory. Maybe a script to assist you in this task will be shipped together with a future version of this plugin.

=head2 purge 

Using purge() you remove all files from the caching directory of the class - use this to set back caching from within templates. This method is used mainly in the self tests of this module. Maybe there are even more useful applications for it - so it became a public class method.

	[% TwoStage = USE TwoStage; 
	   TwoStage.purge;
	%]

=cut

sub purge {
    my $self = shift;
    my $class = ref($self);
   
    my $CACHE_DIR_NAME = CACHE_DIR_NAME;
    rmtree( $class->caching_dir, 0, 1 ) 
    if 
    do { my $class_ue = uri_escape($class, UNSAFE ); $class->caching_dir =~ /$class_ue/; } 
    && $class->caching_dir =~ /${CACHE_DIR_NAME}/
    && -e $class->caching_dir 
    && -d $class->caching_dir; # kind of paranoia
    '';
}

sub _complement_keys {
    my $self = shift;
    my $keys = shift;

    my $callers = $self->{CONTEXT}->stash->get( 'component.callers' );

    return( 
    	{ 
		%{ $self->extend_keys }, 
		%{$keys}, 
		'_file_scope' => 
		( ref($callers) ? join( '\\', @{$callers} ) : '' )
		.$self->{CONTEXT}->stash->get( 'component.name' ) 
			# For making BLOCK name in template file scoped we need a unique identifier:
			# component.callers + component.name 
			# This approach introduces the drawback that a BLOCK defined in a template being 
			# included in different other templates as an "intra" is cached for each call stack
			# path seperately! But it is a feasable workaround as we don't know how to figure
			# out the name of the template the BLOCK was defined in.
	} 
    );
}

sub _precompile {
    my $self = shift;
    my $context = $self->{CONTEXT};
    my $stash = $context->stash();
    
    my $TAGS_tag = 
    $TAG_STYE_unquotemeta->{ $self->{CONFIG}->{precompile_tag_style}  }->[0]
    .' TAGS '.$self->{CONFIG}->{runtime_tag_style}.' '
    .$TAG_STYE_unquotemeta->{ $self->{CONFIG}->{precompile_tag_style} }->[1]."\n";

    print STDERR "We are using tag style: $self->{CONFIG}->{precompile_tag_style}\n" if DEBUG;

    my $template;
    eval {
	$template = $context->process( $self->{params}->{template}, { TwoStage => { precompile_mode => 1 } }, 1 );
    };
    if ( $@ ) {
	print STDERR "\tFAILED ($@)\n"  if DEBUG;
	$self->error( "Precompilation of module $self->{params}->{template}: $@ \n" );
    }

    print STDERR "storing ".$self->_signature."\n\n" if DEBUG;

    eval { mkpath( $self->_file_dir, 0, 0700 ) };
    if ($@) {
    	$self->error( "Couldn't create ".$self->_file_dir.": $@" );
    }

    open( FH, "> ".$self->_file_path ) || $self->error( "Could not get a filehandle! Error: $!" );
    

    print FH 
    $TAGS_tag
    .( 	$self->{CONFIG}->{dev_mode} 
    	&& 
    	$TAG_STYE_unquotemeta->{ $self->{CONFIG}->{runtime_tag_style} }->[0]
	."# This precompiled template ( $self->{params}->{template} ) is stored together with the following keys:\n\t"
	.join( "\n\t", map { "$_ => $self->{params}->{keys}->{$_}" } keys %{$self->{params}->{keys}} )."\n "
	.$TAG_STYE_unquotemeta->{ $self->{CONFIG}->{runtime_tag_style} }->[1]."\n"
	|| 
	'' 
    )
    .$template; 
     
    close FH;

    return \($TAGS_tag.$template);
}

sub _signature {
    my $self = shift;
    # produce signature
   
    $self->{prec_template}->{signature} 
    ||=
    sha1_hex(
    	join(
        	':',
            	(
                	$self->{params}->{template},
                	map { "$_=".( $self->{params}->{keys}->{$_} || '' ) } keys %{$self->{params}->{keys}}
            	)
    	)
    );
} 

sub _dynamic_dir_segments {
    my $self = shift;
   
    $self->{prec_template}->{dynamic_dir_segments}
    ||=
    [
	# include a possible namespace
	( $self->{CONFIG}->{namespace} ? $self->{CONFIG}->{namespace} : () ),
	# include dir_keys - we offer this feature only in testing mode!
	( 	$self->{CONFIG}->{dev_mode} && $self->{CONFIG}->{dir_keys}
 		?
  		(	
			$self->{params}->{template},
			map { 	uri_escape( $_, UNSAFE ),
		      		uri_escape( 'value-'.$self->{params}->{keys}->{$_}, UNSAFE ) 
			} 		
			( ref( $self->{CONFIG}->{dir_keys} ) 
			  ? 
			  grep( { exists $self->{params}->{keys}->{$_} } @{$self->{CONFIG}->{dir_keys}} ) 
			  : 
			  keys %{$self->{params}->{keys}} 
			)
		)
  		:
	  	()
	)
    ];
}

sub _rel_file_path {
    my $self = shift; 

    $self->{prec_template}->{rel_file_path} ||= &_concat_path( $self->_rel_file_dir, $self->_signature );
}

sub _file_path {
    my $self = shift; 

    $self->{prec_template}->{file_path} ||= &_concat_path( ref($self)->caching_dir, $self->_rel_file_path );
}

sub _rel_file_dir {
    my $self = shift;
    
    $self->{prec_template}->{rel_file_dir} ||= File::Spec->catdir( @{$self->_dynamic_dir_segments} );
}

sub _file_dir {
    my $self = shift;

    $self->{prec_template}->{file_dir} ||= &_concat_path( ref($self)->caching_dir, $self->_rel_file_dir );
}

# helpers



sub _concat_path {
    my ( $base_path, $append_dirs ) = @_;
    # $base_dir: base path (no filename) as string
    # $append_dirs: directories to append as string or an array reference
    
    my ($base_volume, $base_directories, $base_file) = File::Spec->splitpath( $base_path, 1 );
    File::Spec->catpath(
    	$base_volume,
		File::Spec->catdir( 
			File::Spec->splitdir( $base_directories ),
			( ref($append_dirs) ? @{$append_dirs} : File::Spec->splitdir( $append_dirs ) )
		) 
    	,
	$base_file
    );
}

=head1 HEURISTICS 

In order to avoid common pitfalls when using this module you find some tips and reminders below:

=over

=item * 

Templates used as "intras" with runtime directives ought to be controlled by the TwoStage plugin themselves! This ensures that such templates can be included into another template either at runtime or at precompilation stage.

=item * 

Upstream keys from included templates ( "intras" ) must be incorporated into the 'keys' option of the including template! Explanation: They have to be known ex ante meaning prior to a test for a cached version of a template and can therefor not easily be collected from upstream templates automatically!

=item * 

Situation: A template A includes another template B while both are using the TwoStage plugin. In addition you pass parameters on invocation of INCLUDE, PROCESS to template B. Add those parameters to the 'keys' option when calling the TwoStage plugin in template B and use them at precompilation stage. This way you can include template B at runtime and at precompilation at your will.

=item * 

Ensure there are no BLOCK definitions inside the BLOCK to be TwoStage processed! This is nothing specific to the TwoStage plugin really, but is a common mistake. Simply put those BLOCKs outside the BLOCK to be TwoStage processed. They will be visible to it anyway.

=back

=cut

# TODO Point to Template::Provider::Preload. Explain how to integrate with it. E.g. use namespace 'preload' and let ::Preload suck precompiled template versions saved to the according namespace directory into a persistent prefork environment on start up.

=head1 CAVEATS

=over 

=item * INCLUDE_PATH

Setting the INCLUDE_PATH option in the TT configuration is a must as of this version. But even setting it to a reference to an empty array is sufficient here.

=item * CACHE_SIZE

As one can produce a lot of versions of a single BLOCK using the 'keys' feature of process()/include(), it might be advisable in some situations to set the CACHE_SIZE TT configuration option to a positive value in order to curb memory consumption when having a TT singleton object around in a persistent environment like e.g. mod_perl.

=back

=head1 AUTHOR

Alexander Kühne, C<< <alexk at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-template-plugin-twostage at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Template-Plugin-TwoStage>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Template::Plugin::TwoStage


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Template-Plugin-TwoStage>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Template-Plugin-TwoStage>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Template-Plugin-TwoStage>

=item * Search CPAN

L<http://search.cpan.org/dist/Template-Plugin-TwoStage>

=back


=head1 ACKNOWLEDGEMENTS

This module was inspired to some extent by Perrin Harkins L<http://search.cpan.org/dist/Template-Plugin-Cache> and not least by my CO2 footprint.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Alexander Kühne, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

Template::Plugin, L<http://search.cpan.org/dist/Template-Plugin-Cache>

=cut

1; # End of Template::Plugin::TwoStage
