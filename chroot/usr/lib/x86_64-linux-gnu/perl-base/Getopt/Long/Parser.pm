#! perl

# Parser.pm -- Getopt::Long object oriented interface
# Author          : Johan Vromans
# Created On      : Thu Nov  9 10:37:00 2023
# Last Modified On: Sat Nov 11 17:48:49 2023
# Update Count    : 13
# Status          : Released

package Getopt::Long::Parser;

our $VERSION = 2.57;

# Getopt::Long has a stub for Getopt::Long::Parser::new.
use Getopt::Long ();
no warnings 'redefine';

sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my %atts = @_;

    # Register the callers package.
    my $self = { caller_pkg => (caller)[0] };

    bless ($self, $class);

    my $default_config = Getopt::Long::_default_config();

    # Process config attributes.
    if ( defined $atts{config} ) {
	my $save = Getopt::Long::Configure ($default_config, @{$atts{config}});
	$self->{settings} = Getopt::Long::Configure ($save);
	delete ($atts{config});
    }
    # Else use default config.
    else {
	$self->{settings} = $default_config;
    }

    if ( %atts ) {		# Oops
	die(__PACKAGE__.": unhandled attributes: ".
	    join(" ", sort(keys(%atts)))."\n");
    }

    $self;
}

use warnings 'redefine';

sub configure {
    my ($self) = shift;

    # Restore settings, merge new settings in.
    my $save = Getopt::Long::Configure ($self->{settings}, @_);

    # Restore orig config and save the new config.
    $self->{settings} = Getopt::Long::Configure ($save);
}

sub getoptions {
    my ($self) = shift;

    return $self->getoptionsfromarray(\@ARGV, @_);
}

sub getoptionsfromarray {
    my ($self) = shift;

    # Restore config settings.
    my $save = Getopt::Long::Configure ($self->{settings});

    # Call main routine.
    my $ret = 0;
    $Getopt::Long::caller = $self->{caller_pkg};

    eval {
	# Locally set exception handler to default, otherwise it will
	# be called implicitly here, and again explicitly when we try
	# to deliver the messages.
	local ($SIG{__DIE__}) = 'DEFAULT';
	$ret = Getopt::Long::GetOptionsFromArray (@_);
    };

    # Restore saved settings.
    Getopt::Long::Configure ($save);

    # Handle errors and return value.
    die ($@) if $@;
    return $ret;
}

1;
