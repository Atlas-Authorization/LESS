#!/usr/bin/perl
# usage: timed.pl <bin> <input_file> <out_timings>
# Feeds one input line at a time to `bin open`, times each verdict in-process (wall clock), no alarm.
use strict; use warnings; use IPC::Open2; use Time::HiRes qw(time);
my ($bin, $in, $outf) = @ARGV;
open(my $fh, '<', $in) or die; open(my $o, '>', $outf) or die;
my $pid = open2(my $from, my $to, $bin, 'open');
select((select($to), $| = 1)[0]);
my ($i, $max, $sum, $n) = (0, 0, 0, 0); my $maxi = -1;
while (my $line = <$fh>) {
  $i++; my $t0 = time;
  print $to $line;
  my $r = <$from>; my $dt = time - $t0;
  chomp($r) if defined $r;
  $r //= 'EOF';
  printf $o "%d %.4f %s\n", $i, $dt, $r;
  $sum += $dt; $n++; if ($dt > $max) { $max = $dt; $maxi = $i; }
}
close $to; waitpid($pid, 0);
printf $o "SUMMARY n=%d mean=%.4f max=%.4f max_idx=%d\n", $n, $sum/($n||1), $max, $maxi;
