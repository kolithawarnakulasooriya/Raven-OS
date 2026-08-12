package Debian::AdduserLogging 3.139;
use 5.36.0;
use utf8;

# Adduser logging Subroutines
#
# Subroutines shared by the "adduser" and "deluser" utilities.
#
# Copyright (C) 2024-2025 Marc Haber <mh+debian-packages@zugschlus.de>
#
# License: GPL-2+

use parent qw(Exporter);

use vars qw(@EXPORT $VAR1);

sub progname {
    $0 =~ m|(.*/)?(.*)|;
    return ($2);
}

BEGIN {
    local $ENV{PERL_DL_NONLAZY}=1;
    eval {
        require Locale::gettext;
        Locale::gettext->import(qw(gettext textdomain LC_MESSAGES));
    };
    if ($@) {
        *gettext = sub { shift };
        *textdomain = sub { "" };
        *LC_MESSAGES = sub { 5 };
    } else {
        Locale::gettext::textdomain("adduser");
    }
}


@EXPORT = (
    'gtx',
    'mtx',
    'log_trace',
    'log_debug',
    'log_info',
    'log_warn',
    'log_err',
    'log_fatal',
    'set_msglevel'
);

my $stderrmsglevel="error";
my $stdoutmsglevel="error";
my $logmsglevel="info";;
my $loggerparms="";
my $has_sys_admin;
my $logger_id_option;
my $logtrace=$ENV{"ADDUSER_LOGTRACE"};

sub gtx {
    return gettext( shift );
}

# this is used as a marker for a string that should be translated
# it returns the untranslated string
# use this for a message that is passed to messagef
sub mtx {
    return shift;
}

sub numeric_msglevel {
    # map from symbolic value to numerical order
    my ($msglevel) = @_;
    # error values from Log4perl::Level
    my %map = (
        logtrace => 1000,
        trace => 5000,
        debug => 10000,
        info => 20000,
        warn => 30000,
        err => 40000,
        error => 40000,
        fatal => 50000
    );
    logtrace( sprintf( 'numeric_msglevel("%s") called', $msglevel ) );
    if( defined($map{$msglevel}) ) {
        my $ret = $map{$msglevel};
        logtrace( sprintf( 'numeric_msglevel("%s") returns %s', $msglevel, $ret ) );
        return $ret;
    } else {
        # this should be croak(), but we'd need perl-modules for that
        die("undefined msglevel: $msglevel handed to numeric_msglevel");
    }
};

sub logmsglevel {
    # map log message level from symbolic value to string
    my ($msglevel) = @_;
    my %map = (
        logtrace => "debug",
        trace => "debug",
        debug => "debug",
        info => "info",
        warn => "warning",
        err => "error",
        error => "error",
        fatal => "crit"
    );
    if( defined($map{$msglevel}) ) {
        return $map{$msglevel};
    } else {
        # this shuld be croak(), but we'd need perl-modules for that
        die("undefined msglevel: $msglevel handed to logmsglevel");
    }
};

sub check_sys_admin {
    # this checks for SYS_ADMIN privilege, see #1074567
    return $has_sys_admin if defined $has_sys_admin;
    open my $fh, '<', '/proc/self/status' or return 0;

    while (my $line = <$fh>) {
        if ($line =~ /^CapEff:\s+[0-9a-fA-F]{10}([0-9a-fA-F]+)/) {
            my $cap_eff = hex($1);
            # Check if the CAP_SYS_ADMIN bit (21st bit) is set
            $has_sys_admin = $cap_eff & (1 << 21);
            last;
        }
    }
    close $fh;
    return $has_sys_admin;
}

sub log_to_syslog {
    # use a pipe or system to logger, which is in bsdutils and thus essential
    # use --id=adduser[pid]
    # make logger parameters configurable (--udp, --journald, for example)
    my ($prio, $data) = @_;
    my $facility = 'user';
    if( ! defined $logger_id_option ) {
        # $$ would be $PID of we had English.pm
        $logger_id_option="--id=". $$;
        $logger_id_option="" if ! check_sys_admin;
    }
    $facility =~ /([a-zA-Z0-9]*)/;
    my $utfacility = $1;
    $prio =~ /([a-zA-Z0-9]*)/;
    my $utprio = $1;
    $loggerparms =~ /([-\sa-zA-Z0-9]*)/;
    my $utloggerparms = $1;
    my $utdata="";
    # note that the two regexps are differnt in [^ and [
    $data =~ s/[^-`'\s()\]\[{}?*+#\.:,;!"$%&\/=a-zA-Z0-9]/_/g;
    if ($data =~ /^([-`'\s()\]\[{}?*+#\.:,;!"$%&\/=a-zA-Z0-9]+)$/) {
        $utdata = $1;
    }
    my @command= ("logger",
        $logger_id_option,
        "--tag=". progname(),
        "--priority=". $utfacility.".".$utprio,
        $utloggerparms, "--",
        $utdata);
    system(@command) == 0
        or printf STDERR ( gtx("logging to syslog failed: command line %s returned error: %s\n"), join(' ', @command), $?);
}

sub logtrace {
    my ($fmt, @data ) = @_;

    my $outstring = sprintf($fmt, @data);
    if ($logtrace) {
        printf STDOUT ( "logtrace: %s\n", $outstring );
        log_to_syslog( "debug", "logtrace: ". $outstring. "\n" );
    } else {
        if ( $stderrmsglevel eq "logtrace" ) {
            printf STDERR ( "logtrace: ". $outstring. "\n" );
        } elsif ( $stdoutmsglevel eq "logtrace" ) {
            printf STDOUT ( "logtrace: ". $outstring. "\n" );
        }
        if ( $logmsglevel eq "logtrace" ) {
            log_to_syslog( "debug", "logtrace: ". $outstring );
        }
    }
}

sub logf {
    my ($msglevel, @data ) = @_;
    my $outstring;
    my $loutstring;
    # outstring is what we log to syslog
    # loutstring (language outstring) is what we print to the console
    if ( scalar(@data) == 1 ) {
        logtrace("single element data");
        $outstring = join(" ", @data);
        $loutstring = gettext($outstring);
    } else {
        my $fmt=shift(@data),
        my @dta= map( $_ // "(undef)", @data );
        my $outfmt = $fmt;
        chomp($outfmt);
        logtrace("multiple element data: format %s, data %s", $outfmt, join("-", @dta));
        $outstring = sprintf( $fmt, @dta );
        $loutstring = sprintf( gettext($fmt), @dta );
    }
    logtrace("outstring %s", $outstring);
    logtrace("loutstring %s", $loutstring);
    logtrace("msglevel %s (%d), stdoutmsglevel %s (%d), stderrmsglevel %s (%d), logmsglevel %s (%d)", $msglevel, numeric_msglevel($msglevel), $stdoutmsglevel, numeric_msglevel($stdoutmsglevel), $stderrmsglevel, numeric_msglevel($stderrmsglevel), $logmsglevel, numeric_msglevel($logmsglevel));
    if ( numeric_msglevel($msglevel) >= numeric_msglevel($stderrmsglevel) ) {
        printf STDERR ( "%s: %s\n", $msglevel, $loutstring );
    } elsif ( numeric_msglevel($msglevel) >= numeric_msglevel($stdoutmsglevel) ) {
        printf STDOUT ( "%s: %s\n", $msglevel, $loutstring );
    }
    if ( numeric_msglevel($msglevel) >= numeric_msglevel($logmsglevel) ) {
        log_to_syslog( logmsglevel($msglevel), $outstring );
    }
};

sub log_trace {
    my (@data) = @_;
    logf( "trace", @data);
}

sub log_debug {
    my (@data) = @_;
    logf( "debug", @data);
}

sub log_info {
    my (@data) = @_;
    logf( "info", @data );
}

sub log_warn {
    my (@data) = @_;
    logf( "warn", @data );
}

sub log_err {
    my (@data) = @_;
    logf( "err", @data );
}

sub log_fatal {
    my (@data) = @_;
    logf( "fatal", @data );
}

sub set_msglevel {
    ($stderrmsglevel, $stdoutmsglevel, $logmsglevel) = @_;
    logtrace("set_msglevel %s (%d) %s (%d) %s (%d)", $stdoutmsglevel, numeric_msglevel($stdoutmsglevel), $stderrmsglevel, numeric_msglevel($stderrmsglevel), $logmsglevel, numeric_msglevel($logmsglevel));
}

sub set_loggerparms {
    ($loggerparms) = @_;
}

1;

# Local Variables:
# mode:cperl
# End:

# vim: tabstop=4 shiftwidth=4 expandtab
