#!/usr/bin/env php
<?php
/*
# Adebar
# (Android DEvice Backup And Restore)
# Creating scripts to backup and restore your apps, settings, and more
# © 2014-2023 by Andreas Itzchak Rehberg
# Licensed using GPLv2 (see the file LICENSE which should have shipped with this)
#
# Convert sms.lst obtained via Adebar to JSON
*/

# Parse arguments
if ( !isset($argv[1]) ) {
  echo "Syntax: ".$argv[0]." <infile> [<outfile>]\n";
  exit;
}

$infile = $argv[1];
if ( isset($argv[2]) && !empty($argv[2]) ) $outfile = $argv[2];
else $outfile = 'sms.json';

$fields=["_id","address","date","body","thread_id","person","protocol","read","status","type","reply_path_present","subject","service_center","locked","date_sent","error_code"];
$regnames="";

foreach ($fields as $field) $regnames .= ", ${field}=(?<${field}>.+?)";
$regnames = substr($regnames,2);

$smslist = file_get_contents($infile);
preg_match_all("/^Row: \d+ ${regnames}\$/ims", $smslist, $matches);
$smsarr = [];
for ($i=0; $i<count($matches[0]);++$i) {
  $item = new stdClass();
  foreach ($fields as $field) $item->{$field} = $matches[$field][$i];
  $smsarr[] = $item;
}

file_put_contents($outfile,json_encode($smsarr, JSON_PRETTY_PRINT));
?>