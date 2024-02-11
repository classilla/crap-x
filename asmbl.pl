#!/usr/bin/perl -s
#
# Assembles CAP-X code on standard input into a CRAP-X binary
# on standard output. Accepts reasonable extensions to the spec.
#
# Copyright (C) 2024 Cameron Kaiser.
# All rights reserved.
# BSD license.
# http://oldvcr.blogspot.com/
#

# Options
# Force compatibility with PC-5? (limited to two pages, off by default)
$pc5 ||= 0;
# Force compatibility with PC-6? (limited to eight pages, off by default)
$pc6 ||= 0;
die("$0: specify only one of -pc5 or -pc6\n") if ($pc5 && $pc6);
# (Both options also require explicit value for CONST)
# Labels limited to three characters? (off by default, implied by -pc[56])
$tlabel ||= ($pc5 | $pc6);
# Allow comments with ; or # ? (on by default, off if -pc[56])
$comms ||= (($pc5 || $pc6) ? 0 : 1);
# Allow hexadecimal address field with $ ? (on by default, off if -pc[56])
# Hex addresses are always accepted for CONST.
$hexa ||= (($pc5 || $pc6) ? 0 : 1);
# Show listing to stderr as assembly occurs. (off by default)
$v ||= 0;
$verbose ||= $v;

sub usage { die("usage: $0 [-options -options] [infile] > outfile\n"); }
foreach(@ARGV) { &usage if (! -f $_); }

@mem = (); 
%labels = ();
%unresolved = ();
%unresconst = ();
%unresadcon = ();
$needsnustart = 1;
$lowadr = 65536;
$hiadr = -1;
$curadr = -1;
$startadr = -1;
$didend = 0;
$line = 0;
$maxaddr = 256 * (($pc5) ? 2 : ($pc6) ? 8 : 256);

# ops
%ops = (
	'ADD' => 10,
	'SUB' => 11,
	'SFT' => 4,
	'AND' => 14,
	'EOR' => 15,
	'LD'  => 12,
	'ST'  => 13,
	'LAI' => 8,
	'JNZ' => 1,
	'JC'  => 2,
	'JSR' => 3,
	'HJ'  => 0,

	'READ'  => 5,
	'WRITE' => 6,
);

# assembler error helpers
sub ugh { die("ERROR: ". shift . ", line $line: " . shift . "\n$_\n\n"); }
sub bleh { warn("WARNING: " . shift . ", line $line: ". shift . "\n$_\n\n"); }

sub syntax { &ugh("syntax", shift); }
sub iq { &ugh("illegal quantity", shift); }
sub link { &ugh("unresolvable symbol", '"' . shift . '"'); }
sub piq { &bleh("possible illegal quantity", shift); }
sub pub { &bleh("undefined behaviour", shift); }
sub ice {
	warn("an internal assembler error has occurred, please report it\n");
	&ugh("INTERNAL ASSERTION", shift);
}

# various argument helpers
sub valu {
	# pass argument, radix
	my $o = shift;
	my $r = shift;
	my $noresolve = shift;

	my $rr;
	my $a = $o;

	# is this a label?
	if ($o =~ /^[A-Z]/ && !$noresolve) {
		if (!defined($labels{$o})) {
			&ice("double unresolved expression")
				if (defined($unresolved[$curadr]));
			$unresolved{$curadr} = $o;
			return undef;
		}
		return $labels{$o};
	}

	# doesn't appear to be, treat as a hex or decimal value
	$r ||= ((($hexa) && ($a =~ s/^$//)) ? 16 : 10);
	if ($r == 16) {
		&syntax("illegal characters in hex value \"$o\"")
			if ($a =~ /[^0-9A-F]/);
		$rr = hex($a);
	} elsif ($r == 10) {
		&syntax("illegal characters in decimal value \"$o\"")
			if ($a =~ /[^0-9]/);
		$rr = 0+$a;
	} else {
		&ice("unexpected value radix $r");
	}
	return $rr;
}

sub adrr {
	my $rr = &valu(@_);
	return $rr if ($rr == undef);
	&iq("address $rr exceeds memory model range $maxaddr")
		if ($rr >= $maxaddr);
	return $rr;
}
sub adr { return &adrr(@_); }

format STDERR =
@>>>@@<<< @<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$line, (defined($unresolved{$curadr})) ? '*' : ' ', sprintf("%04X", $curadr), length($short) ? sprintf("%04X", $short) : '', $_
.

# bytecode emitters (raw and by instruction)
sub emit {
	$short = 0+shift; # has to be global for write to work

	&syntax("no current address (forgot START?)") if ($curadr == -1);
	if ($needsnustart) {
		&iq("crossed memory page to $curadr (forgot START?)")
			unless ($curadr & 255);
	}
	&iq("assembling to previously written location $curadr")
		if (defined($mem[&adrr($curadr)]));
	$mem[$curadr] = $short;
	write STDERR if ($verbose);
	$curadr++;
	$hiadr = $curadr if ($curadr > $hiadr);
	$needsnustart = 1 unless ($curadr & 255);
	&iq("address $curadr hits maximum address $maxaddr")
		if ($curadr >= $maxaddr);
}
sub ins {
	my $op = shift;
	my $gr = shift;
	my $xr = shift;
	my $ad = shift;

	&ice("unexpected opcode $op") if ($op < 0 || $op > 15);
	$ad &= 255;
	return &emit(
		($op << 12) |
		($gr << 10) |
		($xr <<  8) |
	$ad);
}

# pass 1: read source
print STDERR
"(pass 1: syntax and codegen)\n".
"line addr word source\n" if ($verbose);
while(<>) {
	chomp; chomp; $line++;

	# dump comments, whitespace and blank lines
	s/^\s+//;
	s/\s+$//;
	s/\s*[#;].*$// if ($comms);
	next if (!length);

	# initial parse pass
	($label, $opcode, $gr, $ad, $xr, $crap) = split(/\s*:\s*/, $_, 6);
	$opcode = uc($opcode);
	($label, $opcode, $gr) = split(/\s*:\s*/, $_, 3)
		if ($gr =~ /^"/ && $opcode eq 'CONST');
	# don't upcase everything yet: gr could be a string
	$opcode = uc($opcode);
	$label = uc($label);
	$ad = uc($ad);
	&syntax("too many fields") if (length($crap));
	&syntax("too few fields") if (!length($gr));
	&syntax("label \"$label\" too long")
		if ($tlabel && (length($label) > 3));
	&syntax("label \"$label\" must start with alphabetic character")
		if ($label =~ /^[^A-Z]/);
	&syntax("label \"$label\" must not have whitespace")
		if ($label =~ /\s/);
	&syntax("label \"$label\" must only have letters and numbers")
		if (($pc5 || $pc6) && ($label =~ /[^A-Z0-9]/));
	&syntax("opcode field must be present") if (!length($opcode));

	# handle START early so that the current address is correct
	$short = '';
	if ($opcode eq 'START') {
		my $adr = &adr(uc($gr), 0, 1);
		&syntax("START must have an explicit address")
			if (!defined($adr));
		$curadr = $adr;
		write STDERR if ($verbose);
		&iq("assembling to previously written location $curadr")
			if (defined($mem[$curadr]));
		$lowadr = $curadr if ($curadr < $lowadr);
		$needsnustart = 0;
		# fall through to handle label
	}

	# handle label
	if (length($label)) {
		&syntax("label \"$label\" already exists")
			if (defined($labels{$label}));
		$labels{$label} = $curadr;
	}

	# handle pseudo-ops
	if ($opcode eq 'START') {
		next; # already done
	} elsif ($opcode eq 'CONST') {
		unless ($pc5 || $pc6) {
			if ($gr =~ /^"([^"]+)"$/) {
				# insert a string
				foreach $w (unpack("C*", $1)) {
					&emit($w);
				}
				next;
			}
		}
		# argument is implied hexadecimal
		my $v = &valu(uc($gr), 16, !($pc5 || $pc6));
		# labels cause Operand errors on real systems
		&syntax("CONST must have an explicit value")
			if (!defined($v));
		$unresconst{$curadr} = 1 if (!defined($v));
		&emit($v);
		next;
	} elsif ($opcode eq 'RESV') {
		my $v = &valu(uc($gr), 0, 1);
		&syntax("RESV must have an explicit quantity")
			if (!defined($v));
		&iq("RESV parameter must be non-zero")
			if (!$v);
		&emit(0x0000) while ($v--);
		next;
	} elsif ($opcode eq 'END') {
		$didend = 1;
		$startadr = &adr(uc($gr));
		&syntax("END must have an explicit address")
			if (!defined($startadr));
		write STDERR if ($verbose);
		next;
	} elsif ($opcode eq 'ADCON') {
		my $v = &adr(uc($gr));
		$unresadcon{$curadr} = 1 if (!defined($v));
		&emit($v);
		next;
	}

	# handle opcodes
	&syntax("unknown opcode \"$opcode\"") if (!defined($ops{$opcode}));
	&syntax("gr field must be present and be numeric 0-3, not \"$gr\"")
		if (length($gr) != 1 || $gr =~ /[^0-3]/);
	$gr += 0;
	&syntax("xr field must be numeric 0-3, not \"$xr\"")
		if (length($xr) > 1 || $xr =~ /[^0-3]/);
	$xr += 0;

	# address is used as an immediate for I/O, SFT and LAI
	if ($opcode eq 'SFT') {
		my $v = &valu($ad);
		&piq("shift $v > 15") if ($v > 15);
		&syntax("SFT XR must be 0 or 1, not $xr") if ($xr > 1);
		&ins(4, $gr, $xr, $v);
		next;
	} elsif ($opcode eq 'LAI') {
		my $v = &valu($ad);
		&piq("LAI MSB of $v != 0, dropped") if ($v > 255);
		&ins(8, $gr, $xr, $v);
		next;
	} elsif ($opcode eq 'READ' || $opcode eq 'WRITE') {
		my $v = &valu($ad);
		&syntax("$opcode must have an explicit radix")
			if (!defined($v));
		&iq("XR field for $opcode must always be zero, not $xr")
			if ($xr > 0);
		&iq("$opcode radix must be 10 or 16, not $v")
			if ($v != 10 && $v != 16 && ($pc5 || $pc6));
		&piq("interesting $opcode radix $v")
			if ($v != 10 && $v != 16 && $v != 0 && $v != 1);
		&ins($ops{$opcode}, $gr, 0, $v);
		next;
	}

	# HJ has "issues"
	if ($opcode eq 'HJ') {
		&piq("GR field is ignored with HJ (you specified $gr)")
			if ($gr != 0);
		&pub("XR field behaviour is undefined with HJ (you specified $xr)")
			if ($xr != 0);
	}

	# address is address for everything else
	$ad = &adr($ad);
	&ins($ops{$opcode}, $gr, $xr, $ad);
}

&usage if ($curadr == -1);
&syntax("no terminating END statement") unless ($didend);
&iq("no valid starting address found") if ($startadr == -1);

# pass 2: resolve forward references

print STDERR "(pass 2: forward references)\n" if ($verbose);
&iq("null binary, no bytecode generated") if ($lowadr == $hiadr);
foreach(sort { $a <=> $b } keys %unresolved) {
	my $radr = $labels{$unresolved{$_}};
	&link($unresolved{$_}) if (!defined($radr));

	# if this is a CONST, it gets the entire value of the label
	if ($unresconst{$_}) {
		&ice("word was not clear adr $_") if ($mem[$_] != 0);
		$mem[$_] = $radr;
	# if this is an ADCON, it gets the entire value of the label
	} elsif ($unresadcon{$_}) {
		&ice("word was not clear adr $_") if ($mem[$_] != 0);
		$mem[$_] = $radr;
	# if this is anything else, it gets the LSB of the label
	} else {
		&ice("low byte was not clear adr $_") if ($mem[$_] & 255);
		$mem[$_] = ($mem[$_] & 65280) | ($radr & 255);
	}
	printf STDERR "     %04X %04X\n", $_, $mem[$_] if ($verbose);
}

# emit as big endian shorts, starting with load address and start address

printf STDERR
"load address  = \$%04x\nstart address = \$%04x\nend address   = \$%04x\n",
$lowadr, $startadr, $hiadr if ($verbose);

select(STDOUT); $|++;
print STDOUT pack("n*", $lowadr, $startadr, ($hiadr - $lowadr));
for($i=$lowadr;$i<$hiadr;$i++) { print STDOUT pack("n", $mem[$i]); }

foreach(sort { $labels{$a} <=> $labels{$b} } keys %labels) {
	my $out = sprintf("%04X %s\n", $labels{$_}, $_);
	print STDERR "     $out" if ($verbose);
	printf STDOUT $out;
}

