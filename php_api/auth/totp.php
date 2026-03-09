<?php

function totp_generate_secret($length = 20) {
    $random = random_bytes(max(10, (int) $length));
    return totp_base32_encode($random);
}

function totp_build_otpauth_url($issuer, $accountName, $secret) {
    $safeIssuer = trim((string) $issuer) !== '' ? trim((string) $issuer) : 'NutriFit';
    $safeAccount = trim((string) $accountName) !== '' ? trim((string) $accountName) : 'usuario';

    $label = rawurlencode($safeIssuer . ':' . $safeAccount);
    $issuerParam = rawurlencode($safeIssuer);
    $secretParam = rawurlencode($secret);

    return "otpauth://totp/{$label}?secret={$secretParam}&issuer={$issuerParam}&algorithm=SHA1&digits=6&period=30";
}

function totp_verify_code($secret, $code, $window = 1, &$matchedCounter = null) {
    $normalizedCode = preg_replace('/\D/', '', (string) $code);
    if (strlen($normalizedCode) !== 6) {
        return false;
    }

    $secretBytes = totp_base32_decode($secret);
    if ($secretBytes === false || $secretBytes === '') {
        return false;
    }

    $timeStep = 30;
    $counter = (int) floor(time() / $timeStep);
    $windowInt = max(0, (int) $window);

    for ($i = -$windowInt; $i <= $windowInt; $i++) {
        $testCounter = $counter + $i;
        if ($testCounter < 0) {
            continue;
        }

        $otp = totp_hotp($secretBytes, $testCounter, 6);
        if (hash_equals($otp, $normalizedCode)) {
            $matchedCounter = $testCounter;
            return true;
        }
    }

    return false;
}

function totp_hotp($secretBytes, $counter, $digits = 6) {
    $counterBytes = pack('N*', 0) . pack('N*', $counter);
    $hash = hash_hmac('sha1', $counterBytes, $secretBytes, true);
    $offset = ord(substr($hash, -1)) & 0x0F;
    $binary =
        ((ord($hash[$offset]) & 0x7F) << 24) |
        ((ord($hash[$offset + 1]) & 0xFF) << 16) |
        ((ord($hash[$offset + 2]) & 0xFF) << 8) |
        (ord($hash[$offset + 3]) & 0xFF);

    $mod = 10 ** (int) $digits;
    $otp = (string) ($binary % $mod);
    return str_pad($otp, (int) $digits, '0', STR_PAD_LEFT);
}

function totp_base32_encode($data) {
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $binaryString = '';

    $length = strlen($data);
    for ($i = 0; $i < $length; $i++) {
        $binaryString .= str_pad(decbin(ord($data[$i])), 8, '0', STR_PAD_LEFT);
    }

    $chunks = str_split($binaryString, 5);
    $encoded = '';
    foreach ($chunks as $chunk) {
        if (strlen($chunk) < 5) {
            $chunk = str_pad($chunk, 5, '0', STR_PAD_RIGHT);
        }
        $encoded .= $alphabet[bindec($chunk)];
    }

    return $encoded;
}

function totp_base32_decode($base32) {
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $clean = strtoupper((string) $base32);
    $clean = preg_replace('/[^A-Z2-7]/', '', $clean);

    if ($clean === null || $clean === '') {
        return false;
    }

    $binaryString = '';
    $length = strlen($clean);
    for ($i = 0; $i < $length; $i++) {
        $char = $clean[$i];
        $pos = strpos($alphabet, $char);
        if ($pos === false) {
            return false;
        }
        $binaryString .= str_pad(decbin($pos), 5, '0', STR_PAD_LEFT);
    }

    $bytes = str_split($binaryString, 8);
    $decoded = '';
    foreach ($bytes as $byte) {
        if (strlen($byte) < 8) {
            continue;
        }
        $decoded .= chr(bindec($byte));
    }

    return $decoded;
}
