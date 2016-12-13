<?php
// 
// sent_mail.php
// 
// v0.0.1 - 2016-11-29 - Nelbren <nelbren@gmail.com>
//

function debug($to, $subject, $message) {
  echo "TO: $to\n";
  echo "SUBJECT: $subject\n";
  echo "MESSAGE:\n";
  echo "$message\n";
  //exit(2);
}

$to = (isset($argv[1])) ? $argv[1] : '';
$from = (isset($argv[2])) ? $argv[2] : '';
$subject = (isset($argv[3])) ? $argv[3] : '';
$file = (isset($argv[4])) ? $argv[4] : '';

if ($to == '' or $from =='' or $subject == '' or $file == '') {
  echo "Use: sent_mail.php email from subject file\n";
  exit(1);
}

$debug=0;

$headers = "From: ".$from."\r\n";
$headers .= "Reply-To: ".$from."\r\n";
$headers .= "MIME-Version: 1.0\r\n";
$headers .= "Content-Type: text/html; charset=ISO-8859-1\r\n";

$message = file_get_contents($file);

if ($debug) debug($to, $subject, $message);

mail($to, $subject, $message, $headers);
?>
