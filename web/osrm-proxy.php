<?php
/**
 * Proxy OSRM pour contourner les restrictions CORS en environnement web
 * Ce fichier est déployé sur book.misy.app
 *
 * Usage: /osrm-proxy.php?path=/route/v1/driving/...&params=overview=full
 */

// Headers CORS pour autoriser les requêtes depuis n'importe quelle origine
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-OSRM-Timestamp, X-OSRM-Signature');
header('Content-Type: application/json');

// Gérer les requêtes preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier que c'est une requête GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

// Récupérer les paramètres
$path = isset($_GET['path']) ? $_GET['path'] : null;
$params = isset($_GET['params']) ? $_GET['params'] : '';

if (!$path) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing path parameter']);
    exit();
}

// Construire l'URL OSRM2
$osrmUrl = 'https://osrm2.misy.app' . $path;
if ($params) {
    $osrmUrl .= '?' . $params;
}

// Récupérer les headers HMAC si présents
$hmacTimestamp = isset($_SERVER['HTTP_X_OSRM_TIMESTAMP']) ? $_SERVER['HTTP_X_OSRM_TIMESTAMP'] : null;
$hmacSignature = isset($_SERVER['HTTP_X_OSRM_SIGNATURE']) ? $_SERVER['HTTP_X_OSRM_SIGNATURE'] : null;

// Initialiser cURL
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $osrmUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);

// Ajouter les headers HMAC si présents
$headers = ['User-Agent: MisyApp/osrm-proxy'];
if ($hmacTimestamp && $hmacSignature) {
    $headers[] = 'X-OSRM-Timestamp: ' . $hmacTimestamp;
    $headers[] = 'X-OSRM-Signature: ' . $hmacSignature;
}
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

// Exécuter la requête
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

// Gérer les erreurs
if ($error) {
    http_response_code(502);
    echo json_encode(['error' => 'OSRM request failed', 'details' => $error]);
    exit();
}

// Retourner la réponse OSRM
http_response_code($httpCode);
echo $response;
