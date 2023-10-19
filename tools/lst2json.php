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
  echo "  Type: sms|calls|cellbroadcasts|userdict|settings\n\n";
  exit;
}

$type = $argv[1];
$infile = $argv[2];
$smslist = file_get_contents($infile);
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
    # _id=
    # , message_displayed=
    preg_match_all('/_id=/',$smslist,$matches1);
    preg_match_all('/, message_displayed=/',$smslist,$matches2);
    if ( count($matches1[0]) == count($matches2[0]) ) { // Android 11+ replaced date and read by received_time resp. message_displayed
      $fields=["_id","geo_scope","plmn","lac","cid","serial_number","service_category","language","body","received_time","message_displayed","format","priority","etws_warning_type","cmas_message_class","cmas_category","cmas_response_type","cmas_severity","cmas_urgency","cmas_certainty"];
    } else {
      $fields=["_id","geo_scope","plmn","lac","cid","serial_number","service_category","language","body","date","read","format","priority","etws_warning_type","cmas_message_class","cmas_category","cmas_response_type","cmas_severity","cmas_urgency","cmas_certainty"];
    }
    break;
  case "sms"  :
    if (empty($outfile)) $outfile = 'sms.json';
    $fields=["_id","thread_id","address","person","date","date_sent","protocol","read","status","type","reply_path_present","subject","body","service_center","locked","sub_id","error_code","creator","seen"];
    break;
  case "userdict":
    if (empty($outfile)) $outfile = 'userdict.json';
    $fields=["_id","word","frequency","locale","appid","shortcut"];
    break;
  case "settings":
    if (empty($outfile)) $outfile = basename($infile,'.lst').'.json';
    $fields=["_id","name","value"];
    break;
  default     :
    echo "Wrong type '$type'. Valid types are: calls,sms.\n\n";
    exit(1);
}

$regnames="";
foreach ($fields as $field) $regnames .= ", ${field}=(?<${field}>.*?)";
$regnames = substr($regnames,2);

preg_match_all("/^Row: \d+ ${regnames}\$/ims", $smslist, $matches);
$smsarr = [];
for ($i=0; $i<count($matches[0]);++$i) {
  $item = new stdClass();
  foreach ($fields as $field) {
    $item->{$field} = $matches[$field][$i];
    if ( $field == 'date' ) $item->date_formatted = date('Y-m-d H:i:s',$matches[$field][$i]/1000);
    elseif ( $type = 'calls' && $field = 'type' ) switch ($matches[$field][$i]) {
      case 1: $item->type_name = 'incoming'; break;
      case 2: $item->type_name = 'outgoing'; break;
      case 3: $item->type_name = 'missed'; break;
      case 4: $item->type_name = 'voicemail'; break;
      case 5: $item->type_name = 'rejected'; break;
      case 6: $item->type_name = 'blocked'; break;
      case 7: $item->type_name = 'answered_externally'; break; // i.e. by another device using the same number
      default: echo "encountered unknown call type '".$matches[$field][$i]."'\n"; $item->type_name = 'unknown_call_type'; break;
    }
  }
  $smsarr[] = $item;
}

file_put_contents($outfile,json_encode($smsarr, JSON_PRETTY_PRINT));
?>