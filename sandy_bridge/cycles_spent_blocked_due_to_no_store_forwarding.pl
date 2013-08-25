#!/usr/bin/perl -w

#
# This is a dirty script to test out doing per-core measurements of efficiency
# for Sandy Bridge.  The PMCs referenced are only for SB and SB Xeon.
#
# Reference:
#
# http://download-software.intel.com/sites/landingpage/legacy/pdfs/Using_Intel_VTune_Amplifier_XE_on_2nd_Gen_Intel_Core_Family.pdf
#

# Formula:
# Blocked Store Forwarding Cost = (LD_BLOCKS_STORE_FORWARD * 13) / CPU_CLK_UNHALTED.THREAD
# Threshold: Investigate if Cost >= .05

use strict;

my ($p);

open ($p, "pmcstat -s CPU_CLK_UNHALTED.THREAD_P -s LD_BLOCKS.STORE_FORWARD -w 1 2>&1 |") || die "Couldn't run hwpmc: $!\n";

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

	#
	# Ok, now we have the data in a useful format.
	#
	for (my $i = 0; $i < scalar @h; $i++) {
		my @a = split(/\//, $h[$i]);
		next if ($a[2] !~ m/CPU_CLK_UNHALTED.THREAD_P/);

		my ($clk_val) = $d{$h[$i]};
		my ($ret_val) = $d{"s/" . $a[1] . "/LD_BLOCKS.STORE_FORWARD"};

		printf "Core %d: STORE_FORWARD=%d, Unhalted=%d, blocked store cost =%.2f\n",
		    $a[1],
		    $ret_val,
		    $clk_val,
		    ($ret_val * 13) / $clk_val;
	}

	printf "===\n";
}
