#!/usr/bin/perl

# tland.pl - Taskwarrior landscape
# Copyright 2015, Fidel Mato.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# http://www.opensource.org/licenses/mit-license.php

#  *************************************************************************************
#  * WARNING : Under developement, not production state. Watch your data: make backups *
#  *************************************************************************************

#  *************************************************************************************
# Program flow
#  *************************************************************************************

use strict;
use warnings;
use utf8;
binmode( STDOUT, ":utf8" );    # or use open ":utf8", ":std";

# -------------------------------------------------------------------------------- General
my ( @tasks, $day, $date, $datebeg, $dateend );
my $period              ;                                  # time interval to scan
#my $tags                ;                                  # optional tags
my $zero = "" ;                                            # auxiliary
my $secsaday  = 24*3600 ;                                  # seconds per day
my $epochnow  = time()  ;
my $now       = time()  ;
my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime($now);
my $month     = $mon;                                      # current month
my ( $rows, $cols ) = split( / /, `stty size` );           # Unix only , terminal size

# -------------------------------------------------------------------------- Configuration
my $seltags   = "'(status:pending or status:waiting)' and -rev " ;   # selection tags
my $AMPMlim   = 1500 ;                                     # AM/PM limit 15.00h army style

my @wday      = qw/LUNES MARTES MIÉRCOLES JUEVES VIERNES SÁBADO DOMINGO/;
my @months    =            qw/ENERO FEBRERO MARZO ABRIL MAYO JUNIO JULIO AGOSTO/;
   @months    = (@months , qw/SEPTIEMBRE OCTUBRE NOVIEMBRE DICIEMBRE/);
my $today     = "HOY" ;
my $tomorrow  = "MAÑANA" ;

# on-the-fly custom report definition (showing also waiting tasks):
my $cmd_pres  = "temp rc.report.temp.columns:id,description.count rc.verbose=nothing" ;

my $timeunits = "d"  ;                                     # default, days
my $arg       = "2d" ;                                     # default argument (period)

my $bar       = " ~"  ;                                    # week day limit bar
my $barwe     = "="   ;                                    # week-end day limit bar
my $bap       = " . " ;                                    # AM/PM limit bar

# ---------------------------------------------------------------------- Parsing arguments
# Just 0/1 (first) argument allowed; following discarded.
if ( scalar(@ARGV) != 0 ) {
    $arg = shift ;
}
if( $arg =~ m/^([0-9]+)d?$/ ) {                            # 'tland 15' or 'tland 15d', days
    $period = $1 ;
    $timeunits = "d" ;
}
elsif( $arg =~ m/^([0-9]+)w$/ || $arg eq "w" ) {           # 'tland 2w', weeks.
    $timeunits = "w" ;
    $period = $1 ;
    if( $arg eq "w" ) { $period = 1 ; }                    # 'tland w' == 'tland 1w'
}
elsif( $arg =~ m/^([0-9]+)m$/ ) {                          # 'tland 3m' , months.
    $timeunits = "w" ;                                     # fake months. TODO.
    $period = $1*4 ;
}
else{ print( "argument not understood; going with default period.\n" ) ; }

# Transforming periods to days, depending on units:
if( $timeunits eq "w" ){
    $period = 7*$period - ( $wday - 1 ) ;                  # wk 1 == rest of current wk
}

$bar      = $bar x ( int($cols - 1)/length($bar) )."\n";   # week day limit bar
$barwe    = $barwe x ( $cols - 1 )."\n";                   # week-end day limit bar
$bap      = $bap x ( int((($cols - 1)/length($bap)))*(3/4) )."\n"; # AM/PM limit bar

system( 'clear' );  # system $^O eq 'MSWin32' ? 'cls' : 'clear';

# ----------------------------------------------------------------------------- Processing
for ( my $k = 0 ; $k < $period ; $k++ ) {

    my ( @all, @timed, @AM, @untimed, @timedPM, @PM ) ;    # tasks buffers 
    my $time  = $now + $k*$secsaday;                       # in seconds
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime($time);

    # --------------------------------------------------------- Day, week, month delimiter
    $day      = $wday[ $wday - 1 ];
    if (length($mday)<2) { $mday = "0".$mday ; }
    if (length($mon)<2) {
        $zero  = "0" ;
    } else {
        $zero  = "" ;
    }
    $date     = sprintf( "%s%s%s%s", $year + 1900, $zero , $mon + 1 , $mday     );
    $datebeg  = "$date"."000000";                          # beggining
    $dateend  = "$date"."235959";                          # end of day
    $day      = $day." ".$mday ;

    if($mon != $month) {                                   # month change alert
        $day   = "** ".$months[$mon]." **            ".$day ;
        $month = $mon ;
    }
    if( $k == 0) { $day = "$today ".$day } elsif( $k == 1 ) { $day = "$tomorrow ".$day } 
    # week OR week-end day limit bar:
    if( $wday == 0 || $wday == 1 || $wday == 6 ){ print $barwe; } else { print $bar; }
    print( " " x ( $cols - length( $day ) - 3 )." $day\n" );

    # ---------------------------------------------------------------------- Getting tasks
    # export is the Taskwarrior recomended way to get tasks to helper scripts.
    # export outputs json data.
#    print( "task rc.verbose=nothing rc.dateformat='YMDHNS' $seltags and '((due <= $dateend) and (due >= $datebeg))' export\n" ); exit 0;
# orig:   foreach( `task rc.verbose=nothing rc.dateformat='YMDHNS' $seltags and '((due <= $dateend) and (due >= $datebeg))' export` ) { 
    foreach( `task rc.verbose=nothing rc.dateformat='YMDHNS' $seltags and '(((due:$dateend) or (due.before:$dateend)) and ((due:$datebeg) or (due.after:$datebeg)))' export` ) { 
        if( $_ =~ /^.*"id":(\d+).*?"description":"(.*?)".*$/ ) { push( @all , "$2 $1" ) }
    }

    # ------------------------------------------------------------------ Classifying tasks
    if( @all ) { 
        foreach( @all ) {
            if    ( $_ =~ /^\s*AM.*\b(\d+)\s*$/ ) { push( @AM, $1 ) }
            elsif ( $_ =~ /^\s*PM.*\b(\d+)\s*$/ ) { push( @PM, $1 ) }
            elsif ( $_ =~ /^\s*(\d{1,2})\.?(\d{0,2})\s*h.*\b(\d+)\s*$/ ) {  # timed tasks
                # building a normalized time tag (army style: 1730):
                my $hours = $1 ; my $mins  = $2 ;
#    print("$hours$mins $3\n"); # DEBUG
                if ( $hours > 24 ) { # this can't be an hour
                    push( @untimed, $3 ) ;
                } else {
                    while( length($hours) < 2 ) { $hours = "0".$hours }
                    while( length($mins)  < 2 ) { $mins  = $mins."0" }
                    push( @timed, "$hours$mins $3");
                }
            }
            else { if( $_ =~ /.*\b(\d+)\s*$/ ){ push( @untimed, $1 ) } }    # untimed
        }
        if( @timed ) {
        # splitting timed tasks in AM and PM (PM pass to @timedPM , AM remain in @timed):
            @timed = sort( @timed );                       # earlier hourmin first
            while( scalar(@timed) != 0 ) {
                my $time = pop(@timed);
                $time =~ /^(\d+).*\b(\d+)\s*$/ ;
                if( $1 >= $AMPMlim ) { unshift( @timedPM, $2 ) }
                else { push(@timed,$time); last; }
            }
            # stripping time tag (only task ID left):
            for (my $k = 0; $k < @timed; $k++) {
                my $time = $timed[$k];
                $time =~ /^(\d+).*\b(\d+)\s*$/ ;
                $timed[$k] = $2;
            }
        }
        # ----------------------------------------------------------------------- Showtime
        # Order is hardwired: timed(AM), AM, untimed | timed-PM , PM: 
        my $flagmark = 0;
        if( int(@timed) != 0 ) { 
            # print( (join( "," , @all)) , "|\n" );
            system("task ". ( join( "," , @timed ) ) . " $cmd_pres" );
        }
        if( int(@AM) != 0 ) { 
            # print( (join( "," , @all)) , "|\n" );
            system("task ". ( join( "," , @AM ) ) . " $cmd_pres" );
        }
        if( int(@untimed) != 0 ) { 
            # print( (join( "," , @all)) , "|\n" );
            system("task ". ( join( "," , @untimed ) ) . " $cmd_pres" );
            print( $bap ); $flagmark = 1;              # AM to PM mark
        }
        if( int(@timedPM)  != 0 ) {
            if( $flagmark != 1 ){ print( $bap ) ; $flagmark = 1 }       # AM to PM mark
            system("task ". ( join( "," , @timedPM ) ) . " $cmd_pres" );
        }
        if( int(@PM)  != 0 ) {
            if( $flagmark != 1 ){ print( $bap ) }       # AM to PM mark
            system("task ". ( join( "," , @PM ) ) . " $cmd_pres" );
        }
    }
}
# Ending week OR week-end (sábado, domingo) day limit bar:
if( $wday == 6 || $wday == 0 ) { print $barwe; } else { print $bar; }
print( "\n" );

__END__
# -------------------------------------------------------------------------------- __END__

