#!/usr/bin/env perl
#
# git $Id$
#:::::::::::::::::::::::::::::::::::::::::::::::::::::: Hernan G Arango :::
# Copyright (c) 2002-2025 The ROMS Group                                :::
#   Licensed under a MIT/X style license                                :::
#   See License_ROMS.md                                                 :::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::: David Robertson :::
#                                                                       :::
# ROMS-JEDI template-to-yaml processing PERL Script:                    :::
#                                                                       :::
# The "template2yaml.pl" script reads the ROMS "APP_FILE" parameters    :::
# (ASCII file), which contains various key-value pairs. These pairs,    :::
# combined with the "roms-jedi/test/templates" files (*.yaml.tmpl),     :::
# generate all the necessary input YAML configuration files for the     :::
# ROMS-JEDI interface.                                                  :::
#                                                                       :::
# For now, the user must set the "observation block" for the data       :::
# assimilation drivers identified as in the YAML templates:             :::
#                                                                       :::
# (1) __SINGLE_OBSERVATION_DATA__ for single observation test cases     :::
#                                 that may either include a T/S pair,   :::
#     an SST datum, or a couple of ADT measurements. It uses the        :::
#     "roms-jedi/test/Utility/obs_singleObs.yaml.tmpl" as a template    :::
#     to build the observation block in associated YAML files.          :::
#                                                                       :::
# (2) __OBSERVATION_DATA__ for whole set of observations of any of      :::
#                          the following observer types: T, S, TS,      :::
#     TS_GLIDER, SST, SSS, ADT, UV_CODAR, and maybe others.             :::
#     It uses "roms-jedi/test/Utility/observations.yaml.tmpl" as a      :::
#     template to build the observation block in the data assimilation  :::
#     YAML files for available algorithms.                              :::
#                                                                       :::
# The current plan is to develop a web interface to automate the        :::
# generation of input of YAML files for operational data assimilation   :::
# cycles. JEDI provides more sophisticated Phyton-based algorithms for  :::
# the same purpose, like EWOK.                                          :::
#                                                                       :::
#-----------------------------------------------------------------------:::
#                                                                       :::
# Usage:                                                                :::
#                                                                       :::
#   template2yaml.pl APP_FILE SRC_DIR -notest                           :::
#                                                                       :::
# where                                                                 :::
#                                                                       :::
#         APP_FILE       ROMS application YAML parameters file (ASCII)  :::
#                                                                       :::
#         SRC_DIR        Path ROMS-JEDI source code                     :::
#                                                                       :::
#         -notest        Disable regression testing of Unit Tests with  :::
#                          reference files (optional)                   :::
#                                                                       :::
#         -obs list      Use the comma-separate, case-insensitive list  :::
#                          of observations instead of those listed in   :::
#                          APP_FILE. No blank spaces between list       :::
#                          members are allowed. The User can choose     :::
#                          which IODA observation types/files to        :::
#                          include in the data assimilation algorithm   :::
#                          (optional). For instance,                    :::
#                                                                       :::
#                          -obs t,s,sst,sss,adt,uv_codar                :::
#                                                                       :::
# Examples:                                                             :::
#                                                                       :::
#  template2yaml.pl wc13_yaml_parameters.dat ROOT_DIR/roms-jedi         :::
# or                                                                    :::
#  template2yaml.pl wc13_yaml_parameters.dat ROOT_DIR/roms-jedi -notest :::
# or                                                                    :::
#  template2yam.l.pl APP_FILE SRC_DIR -notest -obs T,S,SST,ADT          :::
#                                                                       :::
# For more information, please check the "roms-jedi/tools/workflow"     :::
# sub-directory.                                                        :::
#                                                                       :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

use File::Basename;
use Cwd qw(cwd);
use Time::Piece;
use Time::Seconds;
use strict;
my $notest = 0;
my $obs_set = 0;
my $pwd = cwd;
my @observations;

# $#ARGV is actually the number of arguments minus 1.

if ($#ARGV < 1) {
  print "Usage:\n";
  print "  template2yaml.pl APP_DATA SRC_DIR [-notest] [-obs list]\n";
  exit 1;
}

# Get the first two arguments with 'shift'

my $app_file = shift;
my $src_dir = shift;
my $templates_dir;
my $util_dir;
my %params;
my @ymd_params = ('__ROMS_INI_PRIOR__', '__ROMS_STDINP__', '__ROMS_STDINP_MAX__');
my $key;

print "\n";
if (-d ${src_dir}) {
  $templates_dir = "${src_dir}/test/templates";
  $util_dir = "${src_dir}/test/Utility";
  print "Templates: ${templates_dir}\n";
  print "Utility:   ${util_dir}\n\n";
}
else {
  print "Directory ${src_dir} not found\n";
  exit 1;
}

open FILE, "${app_file}" or die "File ${app_file} must exist!\n";
while ( my $line = <FILE>) {
  chomp ($line);
  # Skip comment and blank lines
  if ($line =~ /^\s*#/ || $line =~ /^\s*$/) { next; }
  my ($key, $val) = split(/\s+/, $line, 2);
  $params{$key} = $val;
}

while (my $arg = shift) {
  if ($arg eq '-notest') {
    $notest = 1;
  }
  elsif ($arg eq '-obs') {
    my $tmp = shift;
    @observations = split(',', $tmp);
    $obs_set = 1;
  }
  else {
    print "Unrecognized option: ${arg}\n";
    print "Usage:\n";
    print "  template2yaml.pl APP_DATA SRC_DIR [-notest] [-obs list]\n";
    exit 1;
  }
}

# If not overridden from the command line, put the comma separated list
# of observations from APP_FILE into the @observations array.

if ($obs_set == 0) {
  @observations = split(',', $params{'__OBSERVATIONS__'});
}

# Get hours integer of forecast length.

my $for_len   = $params{'__FORECAST_LENGTH__'};
if ($for_len =~ /^PT(.*)H/) {
  $for_len =~ s/^PT(.*)H/$1/;
}
elsif ($for_len =~ /^P(.*)D/) {
  $for_len =~ s/^P(.*)D/$1/;
  $for_len = $for_len * 24;
}
else {
  print "FORECAST_LENGTH format is not recognized.\n"
}

# Calculate mid and final date.

my $ini_date = Time::Piece->strptime("$params{'YYYY'}-$params{'MM'}-$params{'DD'}T$params{'hh'}:$params{'mm'}:$params{'ss'}", "%Y-%m-%dT%H:%M:%S");
my $mid_date  = $ini_date + (($for_len / 2) * ONE_HOUR);
my $fin_date  = $ini_date + ($for_len * ONE_HOUR);

# Create date strings.

my $mid_ymd  = $mid_date->strftime("%Y%m%d");
my $ymd      = "$params{'YYYY'}$params{'MM'}$params{'DD'}";

# Insert the appropriate date string for variables that need it.

foreach $key (keys %params) {
  if ($key =~ /^__.*_SINGLE_OBS__$/) {
    $params{$key} =~ s/YYYYMMDD/$mid_ymd/;
  }
  elsif ($key =~ /^__.*_OBS__$/ || grep(/^$key$/, @ymd_params)) {
    $params{$key} =~ s/YYYYMMDD/$ymd/;
  }
  elsif ($key eq '__ROMS_MID_PRIOR__') {
    $params{$key} =~ s/YYYYMMDD/$mid_ymd/;
  }
  elsif ($key eq '__INITIAL_DATE__') {
    $params{$key} = "$params{'YYYY'}-$params{'MM'}-$params{'DD'}T$params{'hh'}:$params{'mm'}:$params{'ss'}Z";
  }
  elsif ($key eq '__INI_DATETIME__') {
    $params{$key} = "$params{'YYYY'}-$params{'MM'}-$params{'DD'}-$params{'hh'}.$params{'mm'}.$params{'ss'}";
  }
  elsif ($key eq '__MIDDLE_DATE__') {
    $params{$key} = $mid_date->strftime("%Y-%m-%dT%H:%M:%SZ");
  }
  elsif ($key eq '__FINAL_DATE__'){
    $params{$key} = $fin_date->strftime("%Y-%m-%dT%H:%M:%SZ");
  }
}

close FILE;

# Remove 'YYYY', 'MM', 'DD', 'hh', 'mm', and 'ss' from params hash to prevent inadvertent
# replacement of occurences of 'ss' in the template files (i.e. sst or ssh)

my @timestamp_vals = ('YYYY', 'MM', 'DD', 'hh', 'mm', 'ss');
delete @params{@timestamp_vals};

# Uncomment to print out all the parameters for debugging purposes.

#print map { "$_ => $params{$_}\n" } keys %params;

# check whether observation file exists

my @obs_keys = grep { $_ =~ /^__.*_OBS__$/ } keys %params;
foreach ( @obs_keys ) {
  my $tfile = $params{${_}};
  $tfile =~ s/^.*\/obs\/(.*)$/obs\/$1/;
  if ( $tfile =~ /^\s*$/ ){ next; }
  if ( not -e $tfile ){
    print "The '${_}' file '$tfile' is missing, so it is ignored.\n";
  }
}

#--------------------------------------------------------------------------
# Read the observations template file and store each variable block in
# a hash (array) keyed on the variable name.
#
#[Setting $/ to > instructs perl to continue reading lines until it
# encounters a > treating the whole variable block as one entry]
#--------------------------------------------------------------------------

$/='>';
my ($obs_fname,$dirs,$suf) = fileparse("${util_dir}/observations.yaml.tmpl", '.tmpl');
open FILE, "${dirs}observations.yaml.tmpl" || die "Can't open file ${dirs} observations.yaml.tmpl\n";
my %obs;
my $ob_name;

# Read the file one entry at a time

while (my $ob = <FILE>) {
  # Remove the > (or whatever $/ is set to) from the end of the entry
  chomp $ob;
  # Avoid 2 entries for last variable
  if ($ob =~ /^\s*$/) {
    last;
  }
  # remove the comments from the start of the file
  $ob =~ s/##.*(<)/$1/s;
  # Set $ob_name to the captured match and remove it from $ob
  $ob_name = $1 if $ob =~ s/<(.*)\n//m;
  $obs{$ob_name} = $ob;
}
close FILE;

#--------------------------------------------------------------------------
# Create the observations block based on the variables requested in the
# .dat file.  The number of spaces to indent is determined on a file by
# file basis below.
#--------------------------------------------------------------------------

my $obs_block = '';
foreach (@observations) {
  # Trim the variable name just in case.
  ${_} =~ s/^\s+|\s+$//g;
  ${_} = uc(${_});
  # Append to the block.
  $obs_block = $obs_block.$obs{${_}};
}

# Read in entire file as one string.

$/=undef;
my ($obs_fname,$dirs,$suf) = fileparse("${util_dir}/obs_singlObs.yaml.tmpl", '.tmpl');
open FILE, "${dirs}obs_singleObs.yaml.tmpl" || die "Can't open file ${dirs}obs_singleObs.yaml.tmpl\n";
my $s_obs = <FILE>;
close FILE;

# Remove comments and first blank line.

$s_obs =~ s/^##.*\n//mg;
$s_obs =~ s/^ *\n//m;

# Create a list containing all the templates to process.

my $dh;
opendir($dh, "${templates_dir}");
my @tmpls = grep { /\.tmpl$/ } readdir($dh);
my $string;

# Create testinput directory if it doesn't already exist.

mkdir("testinput") unless(-d "testinput");

foreach (@tmpls) {
  # Here $suf and ".tmpl" together allow $out_fname to be set to the desired filename
  my ($out_fname,$dirs,$suf) = fileparse("${templates_dir}/${_}", '.tmpl');
  open FILE, "${dirs}${_}" || die "Can't open file ${dirs}${_}";
  $string = <FILE>;
  close FILE;

  if ($string =~ /^( *)__OBSERVATION_DATA__/m || $string =~ /^( *)__SINGLE_OBSERVATION_DATA__/m) {
    my $indent = ' ' x length($1);
    my $path = "Data";
    my @path_parse = split '_', $out_fname;
    my $size = @path_parse;
    # Reemove .yaml from last part of filename to get path
    $path_parse[$size-1] =~ s/(.*).yaml/$1/;
    $params{'__MODEL__'} = $path_parse[0];
    foreach $key (@path_parse) {
      $path = $path."/".$key;
    }
    $params{'__OBS_OUTPUT_PATH__'} = $path;
    if ($string =~ /^ *__OBSERVATION_DATA__/m) {
      my $o_block = indent($indent, $obs_block);
      $string =~ s/^( *)__OBSERVATION_DATA__.*$/$o_block/m;
    }
    else {
      my $so_block = indent($indent, $s_obs);
      $string =~ s/^( *)__SINGLE_OBSERVATION_DATA__.*$/$so_block/m;
    }
  }

  # Run all the string replacments

  foreach $key (keys %params) {
    $string =~ s/$key/$params{$key}/g;
  }

  if ( $notest == 1 ) {
    # search for a liine begining with "test:" and capture to end of file
    my $block_to_comment = qr{ (^test:.*\z) }xms;
    # take the captured block and comment each line
    my $block = '$block = $1;$block =~ s/^/#/smg;$block;';
    # expand (first 'e') and evaluate (second 'e') $block
    $string =~ s/$block_to_comment/$block/smgee;
  }

  # open output yaml file for writing

  open FILE, ">testinput/$out_fname";
  print FILE $string;
  close FILE;
  $string = '';
}

sub indent {
  my ($spaces, $str) = @_;
  # Insert indent spacing after the #
  $str =~ s/^#(.*)/#${spaces}${1}/mg;
  # If doesn't start with # indent normally except blank lines (\n)
  $str =~ s/^([^#\n])/${spaces}${1}/mg;
  return $str;
}
