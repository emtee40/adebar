#!/usr/bin/env php
<?php
/*
# Adebar
# (Android DEvice Backup And Restore)
# Creating scripts to backup and restore your apps, settings, and more
# © 2014-2023 by Andreas Itzchak Rehberg
# Licensed using GPLv2 (see the file LICENSE which should have shipped with this)
#
# Convert calllog.lst, sms.lst obtained via Adebar to JSON
*/

# Parse arguments
if ( !isset($argv[2]) ) {
  echo "\nSyntax: ".$argv[0]." <type> <infile> [<outfile>]\n\n";
  echo "  Type: sms|calls|cellbroadcasts|userdict\n\n";
  exit;
}

$type = $argv[1];
$infile = $argv[2];
if ( isset($argv[3]) && !empty($argv[3]) ) $outfile = $argv[3];
else $outfile = '';

switch ($type) {
  case "calls":
    if (empty($outfile)) $outfile = 'calllog.json';
    $fields=["_id","type","number","formatted_number","numbertype","via_number","numberlabel","normalized_number","matched_number","countryiso","geocoded_location","date","last_modified","name","phone_account_address","lookup_uri","voicemail_uri","is_read","photo_id","photo_uri","post_dial_digits","call_screening_app_name","call_screening_component_name","transcription","transcription_state","block_reason","subscription_id","subscription_component_name","add_for_all_users","features","new","presentation","data_usage"];
    break;
  case "cbc"  :
  case "cellbroadcasts":
    if (empty($outfile)) $outfile = 'cellbroadcasts.json';
    $fields=["_id","geo_scope","plmn","lac","cid","serial_number","service_category","language","body","date","read","format","priority","etws_warning_type","cmas_message_class","cmas_category","cmas_response_type","cmas_severity","cmas_urgency","cmas_certainty"];
    break;
  case "sms"  :
    if (empty($outfile)) $outfile = 'sms.json';
    $fields=["_id","thread_id","address","person","date","date_sent","protocol","read","status","type","reply_path_present","subject","body","service_center","locked","sub_id","error_code","creator","seen","priority"];
    break;
  case "userdict":
    if (empty($outfile)) $outfile = 'userdict.json';
    $fields=["_id","word","frequency","locale","appid","shortcut"];
    break;
  default     :
    echo "Wrong type '$type'. Valid types are: calls,sms.\n\n";
    exit(1);
}

$regnames="";
foreach ($fields as $field) $regnames .= ", ${field}=(?<${field}>.*?)";
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