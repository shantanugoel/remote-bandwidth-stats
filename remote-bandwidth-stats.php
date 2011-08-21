<?php

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

#format
#r = rx bytes
#t = tx bytes
#c = count

#Sample usage with wget from remote host that is being logged
#See remote-bandwidth-stats.sh
#wget --spider http://<url-to-this-php-file>/?rx=<received-bytes>&tx=<transmitted-bytes>&c=<iteration-count>&n=<remote-host-name>

#Modules
$enable_strict_check = 0; #Strict check = not logged (warning logged). Lose check = logged (but with warning)
$enable_ip_host_check = 1;

#Set default timezone. disable/change this according to your server settings
date_default_timezone_set('Asia/Calcutta');

#Global variables
$name = $_GET['n'];
$date = getdate();
$set_allowed_hostname = "";//hostname to be used
$set_allowed_ip = ""; //Only 1 of ip or hostname check should be used.
$set_stats_dir = "~/router-stats/$name/stats/$date[year]/$date[mon]/$date[mday]";
$set_stats_file = $set_stats_dir."/stats.txt";
#stat format time, ip address, rx bytes, tx bytes, count, spurious flag
$set_log_file = "~/router-stats/$name/logs.txt";
$set_log_level = 4; //0 error, 1 warning, 2 debug, 3 info, 4 all
$debug = 0;

#Others
$allow_update = 1;
$spurious_flag = 0;

#Code
if(!file_exists($set_stats_dir))
{
  mkdir($set_stats_dir,0777,TRUE) or die ("Can't create directory for stats");
}
$statfile = fopen($set_stats_file, 'a') or die ("Can't open stats file");
$logfile = fopen($set_log_file, 'a') or die ("Can't open log file");;

function logger($level, $msg)
{
  global $set_log_level, $debug, $logfile;
  if($level <= $set_log_level)
  {
    $time = getdate();
    $string = $time[mday].":".$time[mon].":".$time[year].":".$time[hours].":".$time[minutes].":".$time[seconds]."-->".$msg."\n";
    fwrite($logfile, $string);
    if($debug)
    {
      echo $string.'<br />';
    }
  }
}

$router_ip = $_SERVER['REMOTE_ADDR'];

if($enable_ip_host_check)
{
  $estimated_router_ip = "";
  if(!empty($set_allowed_hostname))
  {
    $estimated_router_ip = gethostbyname($set_allowed_hostname);
  }
  else if(!empty($set_allowed_ip))
  {
    $estimated_router_ip = $set_allowed_ip;
  }
  else
  {
    logger(0, "IP Check enabled but allowed hostname and IP empty");
  }
  if(!empty($estimated_router_ip))
  {
    if (0 != strcmp($estimated_router_ip, $router_ip))
    {
      $spurious_flag = 1;
      logger(1, "Spurious update from $router_ip. Current estimation is $estimated_router_ip");
      if($enable_strict_check)
      {
        $allow_update = 0;
      }
    }
  }
  else
  {
    logger(1, "Invalid estimated ip");
  }
}

if($allow_update)
{
  $rx = $_GET['r'];
  $tx = $_GET['t'];
  $count = $_GET['c'];

  logger(2, "Updated from $router_ip");
  if(empty($rx) or empty($tx) or empty($count))
  {
    logger(0, "Invalid data. $rx:$tx:$count:$name");
  }
  else
  {
    $time = getdate();
    #$string = time()." ".$time[hours].":".$time[minutes].":".$time[seconds];
    $string = time()." ".$router_ip." ".$rx." ".$tx." ".$count." ".$spurious_flag;
    fwrite($statfile, $string."\n");
  }
}

?>
