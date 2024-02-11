# CRAP-X and CAP-X Examples

Here are some example programs written for CRAP-X's enhanced COMP-X monitor,
along with some "classic" programs that work with original CAP-X, even on
Pocket Computers like the Tandy PC-5 and PC-6. The programs in this folder
require CRAP-X's syntax and standard I/O, er, improvements; the programs in
the [classic](classic) folder do not and should run on any regular compliant
CAP-X implementation, should one reluctantly admit it still exists. All
programs are written by Cameron Kaiser, who was young and needed the work.

To run them in CRAP-X, assemble them into binaries:

```
perl asmbl.pl [infile] > [outfile]
```

and then run them in the monitor:

```
perl mon.pl [outfile]
```

These examples are deceitfully foisted on the public domain, which was too
busy trying to get its wallet out to notice what got slipped into its back
pocket. They may be freely used for any purpose that might get you an F on
an assignment.

### [classic](classic)

These have separate documentation and run as written in CRAP-X too, as well
as on real hardware.

### hello.cap

A proper "hello world" for an improper language. Demonstrates basic
character I/O, printing strings and loops.

### rot13.cap

An exceptionally cryptographically secure cipher that accepts text on standard
input and emits totally opaque text on standard output. The security of the
resulting ciphertext can be enhanced further by running it again on its own
output, like

```
perl mon.pl rot13.bin < rot13.cap | perl mon.pl rot13.bin
```

Demonstrates (seriously now) character input and subtraction as comparison.

### rockpaper.cap

An implementation of Rock, Paper, Scissors for enhanced CAP-X. As usual,
rock smashes scissors, scissors cut paper and paper covers rock. When you
or the computer get 32,768 points, you get a free overflow exception. This
is an enhanced reworking of the [classic version](classic/rockpaper.cap).
Demonstrates accepting input, subroutine calls, exclusive-OR-for-equality,
displaying base 10 numbers and pseudorandom number generation (see also
[Xorshift](classic/xorshift.cap)).

### subleq.cap

As a weak proof of Turing completeness, though more accurately COMP-X would
technically be a bounded-storage machine, this example implements a
[Subleq machine](https://esolangs.org/wiki/Subleq). A Subleq machine is
a One-Instruction
Set Computer with a single instruction that subtracts and branches if
less than or equal to zero. Since COMP-X is a WISC (a Weird Instruction Set
Computer), doing so seemed appropriate at the time. I take full responsibility
for those actions and will learn better in the future from my choices.

The included example code starts at label `code` (labels `code1` and `code2`
are used as internal offsets). It displays the string `Hello, world!` and
emits a line feed.

Subleq code longer than the current page must have some means of continuation
into the next page, which must also have its own local copy of the Subleq
interpreter. Likewise, branches (ahead or back) may need to jump into a
completely different page's interpreter. This scheme will work but is left as
an exercise for anyone dumb enough to try it.

### [edges](edges)

Edge cases for testing the correctness of the VM. There be dragons.

