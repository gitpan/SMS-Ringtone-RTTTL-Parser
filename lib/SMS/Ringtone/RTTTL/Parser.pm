package SMS::Ringtone::RTTTL::Parser;
#### Package information ####
# Description and copyright:
#   See POD (i.e. perldoc SMS::Ringtone::RTTTL::Parser).
####

#### Class information ####
# Protected fields:
#	-DEFAULTS: Reference to hash of defaults containing keys d,o,b.
#	-ERRORS: Reference to array of errors.
#	-NOTES: Reference to array of [duration, note, octave, dots] elements.
#	-P1.VALID: Is part 1 valid?
#	-P2.VALID: Is part 2 valid?
#	-P3.VALID: Is part 3 valid?
#	-PARTS: Reference to array of the 3 parts.
#	-RTTTL: RTTTL string.
#	-WARNINGS: Reference to array of warnings.
# Constructors:
#	new()
# Protected methods:
#	_parse()
#	_parse_name()
#	_parse_defaults()
#	_parse_notes()
# Public methods:
#	get_bpm(): Returns the effective BPM setting.
#	get_errors(): Returns an array of error messages.
#	get_part_defaults(): Returns the defaults part.
#	get_part_name(): Returns name part.
#	get_part_notes(): Returns notes part.
#	get_note_count(): Return the amount of notes.
#	get_notes(): Returns an array of [duration, note, octave, dots] elements.
#	get_rtttl(): Returns the RTTTL string.
#	get_warnings(): Returns an array of warning messages.
#	has_errors()
#	has_warnings()
#	is_name_valid()
#	is_defaults_valid()
#	is_notes_valid()
#	puke(): Dump parse results to STDOUT.
####

use strict;
use Carp;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_valid_bpm is_valid_duration is_valid_octave nearest_bpm nearest_duration nearest_octave);
our $VERSION = '0.03';

1;

sub _get_nearest {
 my $value = shift;
 my $aref = shift;
 my $i = 0;
 while ($i < @{$aref}) {
  if ($aref->[$i] == $value) {
   return $aref->[$i];
  }
  if ($aref->[$i] > $value) {
   if ($i >= 1) {
    my $l = $aref->[$i-1];
    my $h = $aref->[$i];
    return ($value - $l) < ($h - $value) ? $l : $h;
   }
   return $aref->[$i];
  }
  $i++;
 }
 return $aref->[scalar(@{$aref})-1];
}

sub _inarray {
 my $e = shift;
 my $aref = shift;
 foreach (@{$aref}) {
  if ($e eq $_) {
   return 1;
  }
 }
 return 0;
}

our @BPM = (	'25',  '28',  '31',  '35',  '40',  '45',  '50',
		'56',  '63',  '70',  '80',  '90',  '100', '112',
		'125', '140', '160', '180', '200', '225', '250',
		'285', '320', '355', '400', '450', '500', '565',
		'635', '715', '800', '900');

sub is_valid_bpm {
 return &_inarray(pop,\@BPM);
}

sub nearest_bpm {
 return &_get_nearest(pop,\@BPM);
}

our @DURATION = ('1','2','4','8','16','32');

sub is_valid_duration {
 return &_inarray(pop,\@DURATION);
}

sub nearest_duration {
 return &_get_nearest(pop,\@DURATION);
}

our @OCTAVE = ('5','6','7','8');

sub is_valid_octave {
 return &_inarray(pop,\@OCTAVE);
}

sub nearest_octave {
 return &_get_nearest(pop,\@OCTAVE);
}

####
# Constructor new()
# Parameters:
#	1. RTTTL string
#	2. Optional reference to hash of options.
####
sub new {
 my $package = shift;
 my $rtttl = shift;
 my $options = shift;
 my $self  = {};
 bless $self;

 # Check parameters
 unless(defined($rtttl)) {
  croak("RTTTL parameter missing or undefined!\n");
 }

 # Set private fields
 $self->{'-DEFAULTS'} = {'d' => 4, 'o' => 6, 'b' => 63};
 $self->{'-ERRORS'} = [];
 $self->{'-NOTES'} = [];
 $self->{'-P1.VALID'} = 0;
 $self->{'-P2.VALID'} = 0;
 $self->{'-P3.VALID'} = 0;
 $self->{'-PARTS'} = [];
 $self->{'-RTTTL'} = $rtttl;
 $self->{'-WARNINGS'} = [];

 # Parse RTTTL
 $self->_parse();

 # Return self reference
 return $self;
}

####
# Method	: _parse
# Description	: Parses RTTTL string
# Parameters	: none.
# Returns	: Boolean result.
#####
sub _parse {
 my $self = shift;
 my $rtttl = $self->{'-RTTTL'};

 # Split parts
 my @parts = split(':',$rtttl);
 unless(@parts == 3) {
  push(@{$self->{'-ERRORS'}},'Invalid number of parts. Should be 3 parts: <name> <sep> [<defaults>] <sep> <note-command>+');
  return 0;
 }
 @{$self->{'-PARTS'}} = @parts;

 # Parse name
 $self->{'-P1.VALID'} = $self->_parse_name($parts[0]);

 # Parse defaults
 $self->{'-P2.VALID'} = $self->_parse_defaults($parts[1]);

 # Parse notes
 $self->{'-P3.VALID'} = $self->_parse_notes($parts[2]);
 return 1;
}

####
# Method	: _parse_name
# Description	: Parses name part of RTTTL string
# Parameters	: 1. Name part.
# Returns	: Boolean result.
#####
sub _parse_name {
 my $self = shift;
 my $name = shift;
 if (length($name) <= 10) {
  $self->{'-P1.VALID'} = 1;
  return 1;
 }
 elsif (length($name) <= 20) {
  push(@{$self->{'-WARNINGS'}},"Length of name part exceeds 10 characters:  $name");
 }
 else {
  push(@{$self->{'-ERRORS'}},"Length of name part exceeds 20 characters: $name");
 }
 return 0;
}

####
# Method	: _parse_defaults
# Description	: Parses defaults part of RTTTL string
# Parameters	: 1. Defaults part.
# Returns	: Boolean result.
#####
sub _parse_defaults {
 my $self = shift;
 my $part = shift;
 my $errors = $self->{'-ERRORS'};
 my $warnings = $self->{'-WARNINGS'};
 my $result = 1;
 my $d;
 my $o;
 my $b;
 if (length($part)) {
  if ($part =~ s/\s//g) {
   push(@{$warnings},'White space found and removed from defaults part.');
  }
  my @defs = split(',',$part);
  my $def;
  foreach $def (@defs) {
   unless ($def =~ /^([dob])=(\d+)$/o) {
    push(@{$warnings},"Invalid entry in defaults part: $def");
    $result = 0;
    next;
   }
   if ($1 eq 'd') {
    if (defined($d)) {
     push(@{$warnings},"Duration entry in defaults specified more than once: $part");
     $result = 0;
    }
    my $i = $2;
    unless(&is_valid_duration($i)) {
     my $nearest = &nearest_octave($i);
     push(@{$errors},"Invalid duration setting $i in defaults replaced with $nearest: $part");
     $i = $nearest;
     $result = 0;
    }
    $d = $i;
   }
   elsif ($1 eq 'o') {
    if (defined($o)) {
     push(@{$warnings},"Octave (scale) entry in defaults specified more than once: $part");
     $result = 0;
    }
    my $i = $2;
    unless(&is_valid_octave($i)) {
     my $nearest = &nearest_octave($i);
     push(@{$errors},"Invalid octave (scale) setting $i in defaults replaced with $nearest: $part");
     $i = $nearest;
     $result = 0;
    }
    $o = $i;
   }
   else {
    if (defined($b)) {
     push(@{$warnings},"BPM entry in defaults specified more than once: $part");
     $result = 0;
    }
    my $i = $2;
    unless(&is_valid_bpm($i)) {
     my $nearest = &nearest_bpm($i);
     push(@{$warnings},"Invalid BPM setting $i in defaults replaced with $nearest: $part");
     $i = $nearest;
     $result = 0;
    }
    $b = $i;
   }
  }
 }
 if (defined($d)) {
  $self->{'-DEFAULTS'}->{'d'} = $d;
 }
 if (defined($o)) {
  $self->{'-DEFAULTS'}->{'o'} = $o;
 }
 if (defined($b)) {
  $self->{'-DEFAULTS'}->{'b'} = $b;
 }
 return $result;
}

####
# Method	: _parse_notes
# Description	: Parses notes part of RTTTL string
# Parameters	: 1. Notes part.
# Returns	: Boolean result.
#####
sub _parse_notes {
 my $self = shift;
 my @notespart = split(',',shift);
 my $errors = $self->{'-ERRORS'};
 unless(@notespart) {
  push(@{$errors},'No notes present in notes part.');
  return 0;
 }
 my $result = 1;
 my $warnings = $self->{'-WARNINGS'};
 my $def_d = $self->{'-DEFAULTS'}->{'d'};
 my $def_o = $self->{'-DEFAULTS'}->{'o'};
 my $notes = $self->{'-NOTES'};
 my $i = 0;
 foreach my $e (@notespart) {
  $i++;
  unless($e =~ /^(\d{0,2})?([P;BEH]|[CDFGA]#?)(\.){0,2}([4-8])?(\.){0,2}$/oi) {
   push(@{$errors},"Invalid syntax in note $i: $e.");
   $result = 0;
   next;
  }
  my $duration = length($1) ? $1 : $def_d;
  my $note     = uc($2);
  if ($note eq 'H') {
   $note = 'B';
  }
  elsif ($note eq ';') {
   $note = 'P';
  }
  my $octave   = length($4) ? $4 : $def_o;
  my $dots = length($3) + length($5);
  if ($dots > 2) {
   push(@{$errors},"More than 2 dots present in note $i: $e.");
   $dots = 2;
  }
  else {
   push(@{$notes},[$duration,$note,$octave,$dots]);
  }
 }
 return $result;
}

####
# Method	: get_bpm()
# Description	: Returns BPM setting of RTTTL string.
# Parameters	: none
# Returns	: Decimal result
#####
sub get_bpm {
 my $self = shift;
 return $self->{'-DEFAULTS'}->{'b'};
}

####
# Method	: get_part_defaults()
# Description	: Returns defaults part of RTTTL string.
# Parameters	: none
# Returns	: String result
#####
sub get_part_defaults {
 my $self = shift;
 return $self->{'-PARTS'}->[1];
}

####
# Method	: get_part_name()
# Description	: Returns name part of RTTTL string.
# Parameters	: none
# Returns	: String result
#####
sub get_part_name {
 my $self = shift;
 return $self->{'-PARTS'}->[0];
}

####
# Method	: get_part_notes()
# Description	: Returns notes part of RTTTL string.
# Parameters	: none
# Returns	: String result
#####
sub get_part_notes {
 my $self = shift;
 return $self->{'-PARTS'}->[2];
}

####
# Method	: get_errors()
# Description	: Returns (a reference to) an array of parse errors.
# Parameters	: none
# Returns	: Array or array reference.
#####
sub get_errors {
 my $self = shift;
 if (wantarray) {
  return @{$self->{'-ERRORS'}};
 }
 else {
  return $self->{'-ERRORS'};
 }
}

####
# Method	: get_note_count()
# Description	: Returns note count of RTTTL string.
# Parameters	: none
# Returns	: Decimal result
#####
sub get_note_count {
 my $self = shift;
 return scalar(@{$self->{'-NOTES'}});
}

####
# Method	: get_notes()
# Description	: Returns an array of [duration, note, octave, dots] elements.
# Parameters	: none
# Returns	: Array or array reference.
#####
sub get_notes {
 my $self = shift;
 if (wantarray) {
  return @{$self->{'-NOTES'}};
 }
 else {
  return $self->{'-NOTES'};
 }
}

####
# Method	: get_rtttl()
# Description	: Returns the RTTTL string.
# Parameters	: none
# Returns	: RTTTL string.
#####
sub get_rtttl {
 my $self = shift;
 my $parts = $self->{'-PARTS'};
 my $defs;
 if ($self->is_defaults_valid()) {
  $defs = $parts->[1];
 }
 else {
  my $x = $self->{'-DEFAULTS'};
  $defs = 'd=' . $defs->{'d'} . ',o=' . $defs->{'o'} . ',b=' . $defs->{'b'};
 }
 return substr($parts->[0],0,20) . ":$defs:" . $parts->[2];
}

####
# Method	: get_warnings()
# Description	: Returns (a reference to) an array of parse warnings.
# Parameters	: none
# Returns	: Array or array reference.
#####
sub get_warnings {
 my $self = shift;
 if (wantarray) {
  return @{$self->{'-WARNINGS'}};
 }
 else {
  return $self->{'-WARNINGS'};
 }
}

####
# Method	: has_errors()
# Description	: Indicates if any parse errors occured.
# Parameters	: none
# Returns	: The amount of errors.
#####
sub has_errors {
 my $self = shift;
 return scalar(@{$self->{'-ERRORS'}});
}

####
# Method	: has_warnings()
# Description	: Indicates if any parse warnings occured.
# Parameters	: none
# Returns	: The amount of warnings.
#####
sub has_warnings {
 my $self = shift;
 return scalar(@{$self->{'-WARNINGS'}});
}

####
# Method	: is_name_valid()
# Description	: Tells if name part of RTTTL string is valid.
# Parameters	: none
# Returns	: Boolean result
#####
sub is_name_valid {
 my $self = shift;
 return $self->{'-P1.VALID'};
}

####
# Method	: is_defaults_valid()
# Description	: Tells if defaults part of RTTTL string is valid.
# Parameters	: none
# Returns	: Boolean result
#####
sub is_defaults_valid {
 my $self = shift;
 return $self->{'-P2.VALID'};
}

####
# Method	: is_notes_valid()
# Description	: Tells if notes part of RTTTL string is valid.
# Parameters	: none
# Returns	: Boolean result
#####
sub is_notes_valid {
 my $self = shift;
 return $self->{'-P3.VALID'};
}

####
# Method	: puke()
# Description	: Dumps parse results to STDOUT.
# Parameters	: none
# Returns	: void
#####
sub puke {
 my $self = shift;
 print 'Name part: ' . $self->get_part_name() . "\n";
 print 'Defaults part: ' . $self->get_part_defaults() . "\n";
 print 'Notes part: ' . $self->get_part_notes() . "\n";
 my $defs = $self->{'-DEFAULTS'};
 print 'Effective defaults: d=' . $defs->{'d'} . ',o=' . $defs->{'o'} .  ',b=' . $defs->{'b'} . "\n";
 print "Effective notes (duration,note,octave,dots):\n";
 foreach my $note ($self->get_notes()) {
  print "\t[ " . sprintf('%2s',$note->[0]) . ' , ' . sprintf('%2s',$note->[1]) .  ' , ' . $note->[2] . ' , ' . $note->[3] . " ]\n";
 }
 print "WARNINGS:\n";
 foreach ($self->get_warnings()) {
  print "\t$_\n";
 }
 print "ERRORS:\n";
 foreach ($self->get_errors()) {
  print "\t$_\n";
 }
}

__END__

=head1 NAME

SMS::Ringtone::RTTTL::Parser - parse and validate RTTTL strings.

=head1 SYNOPSIS

 use SMS::Ringtone::RTTTL::Parser;

 my $rtttl = 'Flntstn:d=4,o=5,b=200:g#,c#,8p,c#6,8a#,g#,c#,' .
             '8p,g#,8f#,8f,8f,8f#,8g#,c#,d#,2f,2p,g#,c#,8p,' .
             'c#6,8a#,g#,c#,8p,g#,8f#,8f,8f,8f#,8g#,c#,d#,2c#';

 my $r = new SMS::Ringtone::RTTTL::Parser($rtttl);

 # Check for errors
 if ($r->has_errors()) {
  print "The following RTTTL errors were found:\n";
  foreach (@{$r->get_errors()}) {
   print "$_\n";
  }
  exit;
 }

 # Dump parse results to STDOUT
 $r->puke();


=head1 DESCRIPTION

SMS::Ringtone::RTTTL::Parser is a RTTTL string parser and validator.
See http://members.tripod.lycos.nl/jupp/linux/soft/rtttl_player/EBNF.txt for
RTTTL syntax in BNF.


=head1 CLASS METHODS

=over 4

=item new ($rtttl_string)

Returns a new SMS::Ringtone::RTTTL::Parser object. The only parameter passed must be a
a RTTTL string. The RTTTL string is parsed and validated by this constructor.

=back


=head1 OBJECT METHODS

=over 4

=item get_bpm()

Returns the effective BPM setting.

=item get_part_defaults()

Returns defaults part of RTTTL string.

=item get_part_name()

Returns name part of RTTTL string.

=item get_part_notes()

Returns notes part of RTTTL string.

=item get_errors()

Returns (a reference to) an array of parse errors. See C<has_errors>.

=item get_note_count()

Returns number of notes in RTTTL string.

=item get_notes()

Returns (a reference to) an array of array references, each containing the 4
elements: duration, note, octave, dots.

 duration is the effective note duration.
 note is the note letter and optional sharp symbol (examples: F# C B P G#).
 octave is the effective octave.
 dots is the number of dots.

=item get_rtttl()

Returns the RTTTL string.

=item get_warnings()

Returns (a reference to) an array of parse warnings. See C<has_warnings>.

=item has_errors()

Returns 0 if no parsing errors occured, else the number of errors.
See C<get_errors>.

=item has_warnings()

Returns 0 if no parsing warnings occured, else the number of warnings.
Warnings occur whenever a RTTTL string does not strictly follow the RTTTL
syntax specifications, but nevertheless is likely to be parseable by a SMS
gateway or mobile phone. Warnings often occur due to incorrect BPM settings
or name lengths that exceed 10 characters. See C<get_warnings>.

=item is_name_valid()

Indicates if name part of RTTTL string is valid.

=item is_defaults_valid()

Indicates if defaults part of RTTTL string is valid.

=item is_notes_valid()

Indicates if notes part of RTTTL string is valid.

=item puke()

Dumps parse results to STDOUT. Useful for debugging.

=back

=head1 FUNCTIONS

These are subroutines that aren't methods and don't affect anything (i.e.,
don't have ``side effects'') -- they just take input and/or give output.

=over 4

=item is_valid_bpm($bpm)

Returns a boolean indicating if the $bpm parameter is a valid RTTTL BPM value.

=item is_valid_duration($dur)

Returns a boolean indicating if the $dur parameter is a valid RTTTL duration value.

=item is_valid_octave($octave)

Returns a boolean indicating if the $octave parameter is a valid RTTTL octave value.

=item nearest_bpm($bpm)

Returns the nearest valid RTTTL BPM setting to the parameter $bpm.

=item nearest_duration($dur)

Returns the nearest valid RTTTL duration setting to the parameter $dur.

=item nearest_octave($octave)

Returns the nearest valid RTTTL octave setting to the parameter $octave.

=back

=head1 HISTORY

=over 4

=item Version 0.01  2001-11-03

Initial version.

=item Version 0.02  2001-11-05

Fixed minor bugs in error messages.

=item Version 0.03  2001-11-06

C<get_rtttl()> now returns RTTTL with valid defaults part if original RTTTL
defaults part contains invalid values. Name part is also limited to length
of 20 characters.

=back

=head1 AUTHOR

Craig Manley	c.manley@skybound.nl

=head1 COPYRIGHT

Copyright (C) 2001 Craig Manley <c.manley@skybound.nl>.  All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. There is NO warranty;
not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut