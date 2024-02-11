# CAP-X Sample Programs

These are real sample programs that work on real historical CAP-X/COMP-X
systems and were
tested (labouriously, hand-keyed) on a real Tandy PC-5/Casio FX-780P. They
will work on a Tandy PC-6/Casio FX-790P as well and probably the Sharp PC-1440
and PC-1416G. They quite possibly include the first games ever written for
CAP-X/COMP-X. All are written by Cameron Kaiser, who is ashamed.

To run them in CRAP-X, assemble them into binaries:

```
perl asmbl.pl [infile] > [outfile]
```

and then run them in the monitor:

```
perl mon.pl [outfile]
```

These example programs are hereby abandoned to the public domain, should
the public domain get so drunk it takes pity on them without considering its
other poor life choices. They may be freely used for any purpose dumb enough
to believe they will help.

### add.cap

This accepts two signed numbers from the console and prints their total.
That's about as much of a hello world as you'll get in O.G. COMP-X.

### add17.cap

An unsigned adder that takes two 16-bit hex numbers, adds them as unsigned
quantities, and emits the low 16 bits followed by the high 17th bit of the
result (i.e., the carry). This is as convoluted as it is because it has to
avoid any risk of overflow/underflow causing it to halt.

### gcd.cap

Modified from the Tandy PC-5 manual. Accepts two positive integers from the
console and finds their greatest common divisor (if they have one: if they
don't, then the answer is 1), which it prints. This may take a bit on a
real machine.

### xorshift.cap

An implementation of the [Xorshift RNG](https://en.wikipedia.org/wiki/Xorshift) for 16-bit registers. Displays random
numbers in an infinite loop.

The subroutines start at location 256 (the second page). Call `XOC` to
initialize the PRNG, and then `XOS` to return a pseudorandom number between 1
and 32767 inclusive in GR3. Both routines clobber GR0 and GR3, but leave GR1
and GR2 intact. You can put these routines into your own programs, like ...

### rockpaper.cap

A Rock Paper Scissors game using Xorshift. When prompted for your move,
1 = Paper 2 = Scissors 3 = Rock. As usual, rock smashes scissors, scissors
cut paper, and paper covers rock. When you enter your move, the CPU shows
its move, and then its score followed by your score (ties score zero). If
either of you gets 32,768 points, you win a free overflow exception.

### blackmatch.cap

A misere game version of Nim in which you must avoid taking the last object.
The game starts with 21 objects; you may take 1, 2 or 3 per turn. You go first,
then the computer shows you its move and how many are left, and so on. If you
successfully force the CPU to take the last one, it shows `5AFE`. If it forces
you to, you are `DEAD`. This version is difficult but designed to give you
opportunities to win. If you're feeling masochistic, remove line 33 and expect
to always lose. A modified port of [the First Book of KIM version](https://archive.org/details/The_First_Book_of_KIM/page/n45/mode/2up) by Ron
Kushnier and editors.


