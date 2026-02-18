<?php
header('Content-Type: application/json');
echo json_encode([
    "status" => "Hostinger API works",
    "server" => "OK"
]);
?>