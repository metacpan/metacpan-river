#!/usr/bin/env perl

# Compute the "River of CPAN" position for every distribution.
# See https://www.neilb.org/2015/04/20/river-of-cpan.html

use v5.12;
use warnings;

# Remove this once https://github.com/metacpan/MetaCPAN-Client/pull/134 has
# been released.
use lib 'MetaCPAN-Client/lib';

use Cpanel::JSON::XS ();
use MetaCPAN::Client  ();
use Ref::Util         qw( is_plain_arrayref is_plain_hashref );

my $mcpan = MetaCPAN::Client->new;

say STDERR "Phase 1: scrolling latest releases ...";

my $latest = $mcpan->all(
    'releases',
    {
        es_filter     => { term => { status => 'latest' } },
        fields        => [qw( distribution provides dependency )],
        scroller_size => 500,
    }
);

my %dist_deps;       # dist => [ module_name, ... ]
my %module_to_dist;  # module_name => distribution
my @all_dists;       # all distribution names seen

my $count = 0;
while ( my $release = $latest->next ) {
    my $dist = $release->distribution;
    next unless defined $dist;

    push @all_dists, $dist;

    # Build module-to-dist mapping from provides
    my $provides = $release->provides;
    if ( is_plain_arrayref($provides) ) {
        for my $module (@$provides) {
            $module_to_dist{$module} = $dist if defined $module;
        }
    }

    # Collect dependencies
    my $deps = $release->dependency;
    if ( is_plain_arrayref($deps) ) {
        my @filtered;
        for my $dep_entry (@$deps) {
            next unless is_plain_hashref($dep_entry);
            my $module       = $dep_entry->{module}       // next;
            my $phase        = $dep_entry->{phase}        // '';
            my $relationship = $dep_entry->{relationship} // '';

            next if $module eq 'perl';

            # We are not including develop deps because it looks like Neil's
            # version probably doesn't. We are currently pretty close to Neil's
            # numbers with these phases.
            next unless $phase =~ /\A(?:runtime|configure|build|test)\z/;

            # We are ignoring "recommends" and "suggests".
            next unless $relationship eq 'requires';

            push @filtered, $module;
        }
        $dist_deps{$dist} = \@filtered if @filtered;
    }

    $count++;
    say STDERR "  releases scanned: $count" if $count % 5000 == 0;
}

say STDERR "  releases scanned: $count (done)";
say STDERR "  modules mapped: " . scalar( keys %module_to_dist );

die "ERROR: Only $count releases found (expected >40000). "
    . "MetaCPAN API may be having issues.\n"
    if $count < 40000;

say STDERR "Phase 2: building dependency graph ...";

my %reverse_deps;  # dist => { dependent_dist => 1, ... }

for my $dist ( keys %dist_deps ) {
    for my $module ( @{ $dist_deps{$dist} } ) {
        my $dep_dist = $module_to_dist{$module};
        next unless defined $dep_dist;
        next if $dep_dist eq $dist;  # skip self-deps
        $reverse_deps{$dep_dist}{$dist} = 1;
    }
}

my %immediate;
for my $dist ( keys %reverse_deps ) {
    $immediate{$dist} = scalar keys %{ $reverse_deps{$dist} };
}

say STDERR "  dists with reverse deps: " . scalar( keys %reverse_deps );

say STDERR "Phase 3: computing transitive reverse deps ...";

my %total;
my $processed  = 0;
my $to_process = scalar keys %reverse_deps;

for my $root ( keys %reverse_deps ) {
    my %visited;
    my @queue = keys %{ $reverse_deps{$root} };
    @visited{@queue} = ();

    my $queue_pos = 0;
    while ( $queue_pos < @queue ) {
        my $node = $queue[$queue_pos++];
        my $dependents = $reverse_deps{$node} or next;
        for my $dependent ( keys %$dependents ) {
            next if exists $visited{$dependent};
            $visited{$dependent} = undef;
            push @queue, $dependent;
        }
    }

    $total{$root} = scalar keys %visited;

    $processed++;
    say STDERR "  processed: $processed / $to_process"
        if $processed % 5000 == 0;
}

say STDERR "  processed: $processed / $to_process (done)";

say STDERR "Phase 4: assigning buckets and writing output ...";

my %results;

for my $dist (@all_dists) {
    my $immediate_count = $immediate{$dist} // 0;
    my $total_count     = $total{$dist}     // 0;

    my $bucket
        = $total_count == 0     ? 0
        : $total_count < 10     ? 1
        : $total_count < 100    ? 2
        : $total_count < 1000   ? 3
        : $total_count < 10000  ? 4
        :                         5;

    $results{$dist} = {
        immediate => $immediate_count,
        total     => $total_count,
        bucket    => $bucket,
    };
}

my $num_dists = scalar @all_dists;
say STDERR "  $num_dists distributions bucketed";

my $json = Cpanel::JSON::XS->new->canonical->indent->space_after;
print $json->encode( \%results );

say STDERR "Done. $num_dists distributions written to STDOUT.";
