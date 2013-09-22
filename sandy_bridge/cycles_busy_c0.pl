#!/usr/bin/perl -w

#
# This script calculates the percentage the CPU is spending busy in C0.
#

use strict;

my ($p);

open ($p, "pmcstat -s CPU_CLK_UNHALTED_REF -s TSC -w 1 2>&1 |") || die "Couldn't run hwpmc: $!\n";

# Header and payload arrays
my (@h, @p);

while (<$p>) {
	chomp;
	my (%d);
	if (m/^# /) {
		# Header: handle appropriately
		s/^#\s*+//;
#		printf "Header: '%s'\n", $_;
		@h = split(/ +/, $_);
		next;
	}

	# It's data, continue
	$_ =~ s/^\s*//;
#	printf "Payload: '%s'\n", $_;
	@p = split(/\s+/, $_);

	# Map the data to the previously arranged payload
	# XXX it'd be nice to use a mapping function, alas..
	for (my $i = 0; $i < scalar @p; $i++) {
#		printf "%s:%s ", $h[$i], $p[$i];

		# Create a hash table entry for this data key
		$d{$h[$i]} = $p[$i];
	}
#	printf "\n";

	# Ok, now we have the data in a useful format.
	#
	# Let's loop over the CPU_CLK_UNHALTED.THREAD_P keys, match it up against
	# the UOPS_RETIRED.RETIRE_SLOTS for the given core, and spit out a value.
	#
	# THe format of the key is:
	#
	# s/00/UOPS_RETIRED.RETIRE_SLOTS
	#
	# Where '00' is the core ID.
	#
	for (my $i = 0; $i < scalar @h; $i++) {
		my @a = split(/\//, $h[$i]);
		next if ($a[2] !~ m/CPU_CLK_UNHALTED_REF/);

		my ($clk_val) = $d{$h[$i]};
		my ($tsc_val) = $d{"s/" . $a[1] . "/TSC"};

		printf "Core %d: ref clock=%d, TSC=%d, busy unhalted in C0=%.2f %%\n",
		    $a[1],
		    $clk_val,
		    $tsc_val,
		    ($clk_val / $tsc_val) * 100.0;
	}

	printf "===\n";
}
