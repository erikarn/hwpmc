#!/usr/bin/perl -w

#
# This is a dirty script to test out doing per-core measurements of efficiency
# for Sandy Bridge.  The PMCs referenced are only for SB and SB Xeon.
#
# Reference:
#
# http://download-software.intel.com/sites/landingpage/legacy/pdfs/Using_Intel_VTune_Amplifier_XE_on_2nd_Gen_Intel_Core_Family.pdf
#

# Split Store Ratio = MEM_UOP_RETIRED.SPLIT_STORES_PS / MEM_UOP_RETIRED.ANY_STORES_PS
# Threshold: split store ratio > 0.01

use strict;

my ($p);

open ($p, "pmcstat -s MEM_UOP_RETIRED.SPLIT_STORES -s MEM_UOP_RETIRED.ALL_STORES -w 1 2>&1 |") || die "Couldn't run hwpmc: $!\n";

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
		next if ($a[2] !~ m/MEM_UOP_RETIRED.SPLIT_STORES/);

		my ($split_val) = $d{$h[$i]};
		my ($store_val) = $d{"s/" . $a[1] . "/MEM_UOP_RETIRED.ALL_STORES"};

		printf "Core %d: Split Stores=%d, All Stores=%d, Split Store Ratio = %.2f\n",
		    $a[1],
		    $split_val,
		    $store_val,
		    ($split_val / $store_val);
	}

	printf "===\n";
}
