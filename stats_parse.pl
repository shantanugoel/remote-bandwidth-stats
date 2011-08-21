#!/usr/local/bin/perl -w

#Copyright (C) 2011  Shantanu Goel

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Author: Shantanu Goel (http://tech.shantanugoel.com/)

#Usage: "stats_parse.pl <input> <output>
#<input> - path to top level dir where logs are stored by remote-bandwidth-stats.php
#<output> - path to dir where html and images for stats should be stored. If this is not specified, they will be stored in the same dir as <input>

use strict;
use File::Find;
use GD::Graph::bars;
use File::Path;

my $file_stats = "stats.txt";
my $file_details = "details.txt";
my $file_totals = "totals.txt";
my $file_graph = "totals.png";
my $file_graph_details = "details.png";
my $file_html = "index.html";
my $path = shift @ARGV;
#base path where html output will be generated
#if this is not defined then current dir will be used
my $html_path = shift @ARGV;
my $detail_stats_idx = 2; #0->seconds, 1->minutes, 2->hourly

$ENV{TZ} = 'Asia/Calcutta';
my $now = localtime;

sub parse_stats()
{
  open INP, "<$file_stats" or die "Cannot open $file_stats: $!";
  open OUT, ">$file_totals" or die "Cannot open $file_totals: $!";
  open DET, ">$file_details" or die "Cannot open $file_details: $!";

  my ($time, $ip, $rx, $tx, $cnt, $spurious) = (0, 0, 0, 0, 0, 0);
  my ($time_p, $ip_p, $rx_p, $tx_p, $cnt_p, $spurious_p) = (0, 0, 0, 0, 0, 0);
  my $total_tx = 0;
  my $total_rx = 0;
  my $total_uptime = 0; #in seconds
  my $line_cnt = 0;
  my $rx_base = 0;
  my $tx_base = 0;
  my $sp_rx = 0;
  my $sp_tx = 0;
  my $uptime = 0;
  my $sp_uptime = 0;
  my $hour = 0;
  my $d_rx = 0;
  my $d_tx = 0;
  my @timetemp = ();

  while(<INP>)
  {
    ($time, $ip, $rx, $tx, $cnt, $spurious) = split / /;
    #print "$time, $ip, $tx, $rx, $cnt, $spurious\n";
    
    if(($line_cnt == 0) && ($cnt != 1))
    {
      $rx_base = $rx;
      $tx_base = $tx;
    }
    
    if(-1 == index($time, ":"))
    {
      @timetemp = localtime($time);
      while ($hour < $timetemp[2])
      {
        print DET "$hour $d_rx $d_tx\n";
        $d_rx = 0;
        $d_tx = 0;
        $hour++;
      }
      if($hour > $timetemp[2])
      {
        print "WARNING: Hour mismatch\n";
      }
    }

    if($cnt <= $cnt_p)
    {
      #if the router rebooted
      $total_tx = $total_tx + $tx_p;
      $total_rx = $total_rx + $rx_p;
      if(0 != $spurious)
      {
        $sp_rx = $sp_rx + $rx;
        $sp_tx = $sp_tx + $tx;
      }
      $d_rx = $d_rx + $rx;
      $d_tx = $d_tx + $tx;
    }
    else
    {
      if((-1 == index($time, ":")) and (-1 == index($time_p, ":")) and (0 != $time_p))
      {
        $uptime = $uptime + $time - $time_p;
      }
      if(0 != $spurious)
      {
        $sp_rx = $sp_rx + $rx - $rx_p;
        $sp_tx = $sp_tx + $tx - $tx_p;
        if((-1 == index($time, ":")) and (-1 == index($time_p, ":")) and (0 != $time_p))
        {
          $sp_uptime = $sp_uptime + $time - $time_p;
        }
      }
      #if there was a wrap around due to 4GB limit
      if($tx < $tx_p)
      {
        $total_tx = $total_tx + $tx_p;
        if(0 != $spurious)
        {
          $sp_tx = $sp_tx + $tx_p;
        }
        $d_tx = $d_tx + $tx;
      }
      else
      {
        $d_tx = $d_tx + $tx - $tx_p;
      }
      if($rx < $rx_p)
      {
        $total_rx = $total_rx + $rx_p;
        if(0 != $spurious)
        {
          $sp_rx = $sp_rx + $rx_p;
        }
        $d_rx = $d_rx + $rx;
      }
      else
      {
        $d_rx = $d_rx + $rx - $rx_p;
      }
    }
    ($time_p, $ip_p, $rx_p, $tx_p, $cnt_p, $spurious_p) = ($time, $ip, $rx, $tx, $cnt, $spurious);

    $line_cnt++;

  }
  while ($hour < 24)
  {
    print DET "$hour $d_rx $d_tx\n";
    $d_rx = 0;
    $d_tx = 0;
    $hour++;
  }
  $total_rx = ($total_rx + $rx - $rx_base);
  $total_tx = ($total_tx + $tx - $tx_base);
  print OUT "$total_rx $total_tx $time $sp_rx $sp_tx $ip $uptime $sp_uptime";
  close INP;
  close OUT;
  close DET;
}

sub parse_totals()
{
  my @list = glob("$_/*/$file_totals");
  {
    #suppress sort warnings for non numeric values
    local $SIG{__WARN__}=sub{};
    sub val()
    {
      my $lidx = index($a, "/");
      my $ridx = rindex($a, "/");
      my $resa = substr($a, $lidx+1, $ridx-$lidx-1);
      $lidx = index($b, "/");
      $ridx = rindex($b, "/");
      my $resb = substr($b, $lidx+1, $ridx-$lidx-1);
      return $resa <=> $resb;
    }
    @list = sort { &val } @list;
  }
  #print "=>Found @list\n";
  open OUT, ">$_/$file_totals" or die "Cannot open $file_totals: $!";
  my $total_tx = 0;
  my $total_rx = 0;
  my $final_time = 0;
  my $total_sp_rx = 0;
  my $total_sp_tx = 0;
  my $last_ip = 0;
  my $total_uptime = 0;
  my $total_sp_uptime = 0;
  foreach (@list)
  {
    open INP, "<$_" or die "Cannot open $_: $!";
    my ($rx, $tx, $time, $sp_rx, $sp_tx, $ip, $uptime, $sp_uptime) = split / /, <INP>;
    close INP;
    $total_rx = $total_rx + $rx;
    $total_tx = $total_tx + $tx;
    $total_sp_rx = $total_sp_rx + $sp_rx;
    $total_sp_tx = $total_sp_tx + $sp_tx;
    $last_ip = $ip;
    $total_uptime = $total_uptime + $uptime;
    $total_sp_uptime = $total_sp_uptime + $sp_uptime;
    if( (-1 != index($time, ":")) or ($time > $final_time) ) #needs unix time
    {
      $final_time = $time;
    }
  }
  print OUT "$total_rx $total_tx $final_time $total_sp_rx $total_sp_tx $last_ip $total_uptime $total_sp_uptime";
  close OUT;
}

sub create_html()
{
  my $filename = $_;
  my $newpath = "";
  if ($filename eq $file_totals)
  {
    my $detailed_graph = 0;
    my $rx = 0;
    my $tx = 0;
    my $time = 0;
    my $sp_rx = 0;
    my $sp_tx = 0;
    my $ip = 0;
    my $uptime = 0;
    my $sp_uptime = 0;
    #print "Creating $File::Find::dir/$file_html\n";
    my @rxdata = ();
    my @txdata = ();
    my @datedata = ();
    if(defined($html_path))
    {
      my $idx = length($path);
      $newpath = $html_path.substr($File::Find::dir, $idx);
      mkpath($newpath);
      open OUT, ">$newpath/$file_html" or die "Cannot open $file_html: $!";
    }
    else
    {
      open OUT, ">$file_html" or die "Cannot open $file_html: $!";
    }
    print OUT "Generated on $now <br /><br />";
    print OUT "<img src=\"$file_graph\" />";
    my @list = glob("*/$file_totals");
    {
      #suppress sort warnings for non numeric values
      local $SIG{__WARN__}=sub{};
      @list = sort { $a <=> $b } @list;
    }
    my @data = ();
    if(@list)
    {
      print OUT "<br /><strong><a href=\"../index.html\">Up</a></strong><br /><br />";
      print OUT "<strong>Subdirs</strong><br />";
      foreach (@list)
      {
        my $file = $_;
        my $idx = index($file, "/");
        my $link = substr($file, 0, $idx);
        open TOTAL, "<$file" or die "Cannot open $link/$file_totals: $!";
        my $total = <TOTAL>;
        close TOTAL;
        print OUT "<a href=\"$link/$file_html\">$link</a>&nbsp;&nbsp;&nbsp;&nbsp;";
        chomp $total;
        my (@bwdata) = split(/ /, $total);
        push @datedata, $link;
        push @rxdata, $bwdata[0]/(1024*1024);
        push @txdata, $bwdata[1]/(1024*1024);
        $rx = sprintf("%.3f", $rx + $bwdata[0]/(1024*1024*1024)); #GB
        $tx = sprintf("%.3f", $tx + $bwdata[1]/(1024*1024*1024)); #GB
        $time = $bwdata[2];
        $sp_rx = sprintf("%.3f", $sp_rx + $bwdata[3]/(1024*1024*1024));
        $sp_tx = sprintf("%.3f", $sp_tx + $bwdata[4]/(1024*1024*1024));
        $ip = $bwdata[5];
        $uptime = $uptime + $bwdata[6];
        $sp_uptime = $sp_uptime + $bwdata[7];
      }
    }
    else
    {
      print OUT "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<img src=\"$file_graph_details\" /><br />";
      print OUT "<br /><strong><a href=\"../index.html\">Up</a></strong><br /><br />";
      open TOTAL, "<$file_totals" or die "Cannot open $file_totals: $!";
      my $total = <TOTAL>;
      close TOTAL;
      chomp $total;
      my (@bwdata) = split(/ /, $total);
      push @datedata, "This day";
      push @rxdata, $bwdata[0]/(1024*1024);
      push @txdata, $bwdata[1]/(1024*1024);
      $rx = sprintf("%.3f", $bwdata[0]/(1024*1024*1024)); #GB
      $tx = sprintf("%.3f", $bwdata[1]/(1024*1024*1024)); #GB
      $time = $bwdata[2];
      $sp_rx = sprintf("%.3f", $bwdata[3]/(1024*1024*1024));
      $sp_tx = sprintf("%.3f", $bwdata[4]/(1024*1024*1024));
      $ip = $bwdata[5];
      $uptime = $uptime + $bwdata[6];
      $sp_uptime = $sp_uptime + $bwdata[7];

      $detailed_graph = 1;
    }
    if(-1 == index($time, ":"))
    {
      $time = localtime($time);
    }
    print OUT "<br /><br /><strong>Extra Stats:</strong><br />";
    print OUT "Total Download: $rx GB Total Upload: $tx GB<br />";
    print OUT "Spurious Download: $sp_rx GB Spurious Upload: $sp_tx GB<br />";
    print OUT "Remote host last known IP: $ip<br />";
    print OUT "Remote host uptime: ".int($uptime/(24*60*60))," days ",(($uptime/(60*60))%24)," hours ",($uptime/60)%60," minutes ",$uptime%60," seconds <br />";
    print OUT "Remote host spurious uptime: ",int($sp_uptime/(24*60*60))," days ",($sp_uptime/(60*60))%24," hours ",($sp_uptime/60)%60," minutes ",$sp_uptime%60," seconds <br />";
    print OUT "Remote host last updated at: $time<br />";
    close OUT;
    @data = ([ @datedata ], [ @rxdata ], [@txdata]);
    my $graph = new GD::Graph::bars;
    my $dir = `pwd`;
    chomp $dir;
    my $idx = rindex($dir, "/");
    $dir = substr($dir, $idx+1);
    $graph->set(
      x_label => 'Date',
      y_label => 'BW Usage (MBs)',
      title => "BW Usage for $dir",
      bar_spacing => 5,
      shadow_depth => 2,
      long_ticks => 1
    ) or die $graph->error;
    $graph->set_legend('Download', 'Upload');
    $graph->plot(\@data) or die $graph->error;
    if(defined($html_path))
    {
      open GRAPH, ">$newpath/$file_graph" or die "Cannot open $file_graph: $!";
    }
    else
    {
      open GRAPH, ">$file_graph" or die "Cannot open $file_graph: $!";
    }
    binmode GRAPH;
    print GRAPH $graph->gd->png();
    close GRAPH;
    if(1 == $detailed_graph)
    {
      open DET, "<$file_details" or die "Cannot open $file_details: $!";
      @data = ();
      @rxdata = ();
      @txdata = ();
      @datedata = ();
      while(<DET>)
      {
        chomp;
        my @tempdata = split / /;
        push @datedata, $tempdata[0];
        push @rxdata, ($tempdata[1]/(1024*1024));
        push @txdata, ($tempdata[2]/(1024*1024));
      }
      close DET;
      @data = ([ @datedata ], [ @rxdata ], [@txdata]);
      $graph = GD::Graph::bars->new(800, 400);
      $graph->set(
        x_label => 'Hour',
        y_label => 'BW Usage (MBs)',
        title => "Detailed BW Usage for $dir",
        bar_spacing => 5,
        shadow_depth => 2,
        long_ticks => 1
      ) or die $graph->error;
      $graph->set_legend('Download', 'Upload');
      $graph->plot(\@data) or die $graph->error;
      if(defined($html_path))
      {
        open GRAPH, ">$newpath/$file_graph_details" or die "Cannot open $file_graph_details: $!";
      }
      else
      {
        open GRAPH, ">$file_graph_details" or die "Cannot open $file_graph_details: $!";
      }
      binmode GRAPH;
      print GRAPH $graph->gd->png();
      close GRAPH;
    }
  }
}

sub process_file()
{
  my $filename = $_;
  if ($filename eq $file_stats)
  {
    #parse it
    #print "Parsing $File::Find::name\n";
    &parse_stats();
  }
  elsif (-d $filename)
  {
    if(!(-e "$filename/$file_stats"))
    {
      #find totals.txt files 1 level below
      #print "Totaling $File::Find::name\n";
      &parse_totals($filename);
    }
  }
}

sub clean()
{
  my $filename = $_;
  if($filename eq $file_totals)
  {
    unlink $filename;
  }
}

#finddepth(\&clean, $path);
finddepth(\&process_file, $path);
finddepth(\&create_html, $path);
