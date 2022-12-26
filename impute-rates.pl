#!/usr/bin/env perl

use v5.30;
use autodie;
use JSON::PP;

my %mha_assigns;
my %used_zip_codes;

my $INPUT_NAME  = $ARGV[0] or die usage();
my $OUTPUT_NAME = $ARGV[1] or die usage();
my $TOPOJSON_ZCTA_LAYER = "us_zcta500.geo"; # change if you change layer name in TopoJSON input

# Load BAH ZIP-code-to-MHA-assignment data
{
    open my $mha, '<', "sorted_zipmha23.txt";
    my @mhas = <$mha>;
    foreach my $mha_asgn (@mhas) {
        chomp($mha_asgn);
        my ($zip, $mha_id) = split(' ', $mha_asgn);
        $mha_assigns{$mha_id} //= 1;
        $used_zip_codes{$zip} = $mha_id;
    }
}

say scalar keys %mha_assigns, " MHAs, ", scalar keys %used_zip_codes, " ZIP codes in BAH database";

my $geoDB;

# Load the TopoJSON data with U.S. Census ZCTA geographic features. We will
# embed ZCTAs that match a BAH MHA area with the corresponding MHA ID.
{
    open my $topojson_file, '<', $INPUT_NAME;
    local $/; # slurp
    my $topojson_text = <$topojson_file>; # big!
    $geoDB = decode_json $topojson_text;
}

# The list of ZCTA geometries
my $obj_db = $geoDB->{objects}->{$TOPOJSON_ZCTA_LAYER}->{geometries};
my $upd_count = 0; # count imputations we make for comparison

say scalar @$obj_db, " objects in GEO DB";

for my $geometry (@$obj_db) {
    my $geoZCTA = $geometry->{properties}->{GEOID10}; # This is the 5-digit ZIP code as text
    my $mha = $used_zip_codes{$geoZCTA} // '';
    if ($mha) {
        $geometry->{properties}->{"DOD_BAH_MHA"} = $mha;
        $upd_count++;
        delete $used_zip_codes{$geoZCTA}; # any used ZIP codes not listed at end have no ZCTA match
    } else {
        say "GEO DB object $geoZCTA has no MHA match";
    }
}

say "Made $upd_count updates to the output GEO DB";
say scalar keys %used_zip_codes, " ZIP codes not used in any ZCTA entry";
my @non_fake_zips = grep { $used_zip_codes{$_} !~ /^ZZ/ } keys %used_zip_codes;
say "\t of these, ", scalar @non_fake_zips, " were not artificial MHAs";

# Write out the imputed data
{
    open my $topojson_file, '>', $OUTPUT_NAME;
    my $topojson_text = encode_json $geoDB;
    print $topojson_file $topojson_text;
}

say "\nUpdate written to $OUTPUT_NAME";

exit 0;

sub usage
{
    say <<~EOF;
        Encodes BAH data (sorted_zipmha23.txt must be available on disk)
        into the given input TopoJSON data containing U.S. Census Bureau ZCTAs.

        Output file is same as input, except that ZCTA geometry features
        with a ZIP code matching a DoD BAH MHA will have an additional property
        'DOD_BAH_MHA' containing the MHA ID for use in later topological merging

        $0 [input-file] [output-file]
        EOF

    return "Unable to proceed";
}
