#!/usr/bin/perl -w

#
# This is a dirty script to test out doing per-core measurements of efficiency
# for Sandy Bridge.  The PMCs referenced are only for SB and SB Xeon.
#
# Reference:
#
# http://download-software.intel.com/sites/landingpage/legacy/pdfs/Using_Intel_VTune_Amplifier_XE_on_2nd_Gen_Intel_Core_Family.pdf
#

# % of cycles spent on last level cache access (2nd level misses that hit in LLC):
# ((MEM_LOAD_RETIRED.L3_HIT_PS * 26) + (MEM_LOAD_UOPS_LLC_HIT_RETIRED.XSNP_HIT_PS * 43) +
# (MEM_LOAD_UOPS_LLC_HIT_RETIRED.XSNP_HITM_PS * 60)) / CPU_CLK_UNHALTED.THREAD

# Thresholds:
# % cycles for LLC Hit >= .2


use strict;

my ($p);

open ($p, "pmcstat -s CPU_CLK_UNHALTED.THREAD_P -s MEM_LOAD_UOPS_LLC_HIT_RETIRED.XSNP_HITM -s MEM_LOAD_UOPS_LLC_HIT_RETIRED.XSNP_HIT -s MEM_LOAD_UOPS_RETIRED.LLC_HIT -w 1 2>&1 |") || die "Couldn't run hwpmc: $!\n";

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
		my ($llc_val) = $d{"s/" . $a[1] . "/MEM_LOAD_UOPS_RETIRED.LLC_HIT"};
		my ($snp_val) = $d{"s/" . $a[1] . "/MEM_LOAD_UOPS_LLC_HIT_RETIRED.XSNP_HIT"};
		my ($snpm_val) = $d{"s/" . $a[1] . "/MEM_LOAD_UOPS_LLC_HIT_RETIRED.XSNP_HITM"};

		printf "Core %d: Unhalted=%d, LLC=%d, SNP=%d, SNPM=%d, cycles spent LLC hit=%.2f\n",
		    $a[1],
		    $clk_val,
		    $llc_val,
		    $snp_val,
		    $snpm_val,
		    (($llc_val * 26) + ($snp_val * 43) + ($snpm_val * 60)) / $clk_val;
	}

	printf "===\n";
}
