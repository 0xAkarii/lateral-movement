<?php
// Health check endpoint - dipakai sama service health checker
header('Content-Type: application/json');
echo json_encode([
    'status' => 'ok',
    'service' => 'web-frontend',
    'version' => '1.2.0',
    'timestamp' => date('c')
]);
