#!/usr/bin/perl -s
#
# Disassemble a CRAP-X binary on standard input to standard output.
# Simple-minded, doesn't distinguish opcodes from data very well.
# Follows canonical Casio format (decimal arguments except for CONST).
#
# Copyright (C)2024 Cameron Kaiser
# All rights reserved.
# BSD license.
# http://oldvcr.blogspot.com/
#

format OPCODE =
@*:@<<<<:@:@*
$clabel, $op,$gr,$ad
.

format OPCODEX =
@*:@<<<<:@:@*:@
$clabel, $op,$gr,$ad,$xr
.

format CONST =
@*:CONST:@<<<
$clabel, sprintf("%04X", $ad)
.

# mnemonics
@ops = qw(HJ JNZ JC JSR SFT READ WRITE CONST LAI CONST ADD SUB LD ST AND EOR);
# is the argument an address?
# HJ technically takes one, but in practice this is also how byte consts are
# encoded, so it doesn't seem too useful to convert it to a label.
@agr = qw(0  1   1  1   0   0    0     0     0   0     1   1   1  1  1   1  );

$w = $/; $/ = \6;
($la, $sa, $len) = unpack("nnn", <>); $/ = $w;
read(ARGV, $buf, $len + $len); # words, not bytes

die("no bytecode?\n") if (!length($buf));

# read symbol table and create formatting
$longest = 3;
while(<ARGV>) {
	print STDOUT "$_" if ($sym);
	chomp;
	@w = split(/\s+/, $_, 2);
	$labels{hex($w[0])} = $w[1];
	$longest = length($w[1]) if (length($w[1]) > $longest);
}
$spongest = " " x $longest;

exit 0 if ($sym);
warn("warning: no symbols\n") if (!scalar keys %labels);

# reconstruct and relocate in memory
@mem = unpack("n*", $buf);
if ($la) { $laa = $la; unshift(@mem, 0) while ($laa--); }

# holding array for marking memory
%marks = ();

$lasthj = 0;
$lasthjb = 0;
print STDOUT "$spongest:START:$la\n";
for($i=$la;$i<scalar(@mem);$i++) {
	$clabel = substr($labels{$i} . $spongest, 0, $longest);

	if ($marks[$i] eq 'j') {
		# jump target, turn into ADCON or CONST
		if (defined($labels{$mem[$i]})) {
			print STDOUT "$clabel:ADCON:$labels{$mem[$i]}\n";
		} else {
			$~ = 'CONST';
			$ad = $mem[$i];
			write;
		}
		next;
	}

	$opc = $mem[$i] >> 12;
	$op = $ops[$opc];
	if ($op eq 'CONST') {
		$~ = 'CONST';
		$ad = $mem[$i];
		write;
		next;
	}
	$gr = ($mem[$i] >> 10) & 3;
	$xr = ($mem[$i] >> 8) & 3;
	$ad = $mem[$i] & 255;

	# special handling for HJ, which can be used for byte strings
	if ($lasthj && $op eq 'HJ') {
		$~ = 'CONST';
		$ad = $mem[$i];
		write;
		next;
	}

	# try to turn address into a label, if this takes an address
	if ($agr[$opc]) {
		$nad = ($i & 65280) | $ad;

		# mark JSR targets, these should not be rendered as opcodes
		$marks[$nad] = 'j' if ($op eq 'JSR');

		$ad = $labels{$nad} if (defined $labels{$nad});
	}
	if ($xr) {
		$~ = 'OPCODEX';
		write;
	} else {
		$~ = 'OPCODE';
		write;
	}
	$lasthj = ($op eq 'HJ') ? 1 : 0;

	# future expansion
	if ($mem[$i] == 0) { $lasthjb++; } else { $lasthj = 0; }
}
$sa = $labels{$sa} if (defined $labels{$sa});
print STDOUT "$spongest:END  :$sa\n";

