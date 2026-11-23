<?php

/*
 * base64_encode() / base64_decode() benchmark.
 *
 * The workloads try to cover how base64 is used in practice: short tokens
 * and nonces, JWT segments (base64url), JSON/API payloads, e-mail
 * attachments (MIME, with line breaks), data URIs and large blobs, as well
 * as a mix of sizes. All inputs are generated at runtime so that the calls
 * cannot be evaluated at compile time.
 */

if (function_exists("date_default_timezone_set")) {
    date_default_timezone_set("UTC");
}

mt_srand(42);

function random_bytes_det(int $length): string
{
    $s = "";
    for ($i = 0; $i < $length; $i += 4) {
        $s .= pack("V", mt_rand());
    }
    return substr($s, 0, $length);
}

$block = random_bytes_det(65536);

function bytes(int $length): string
{
    global $block;
    if ($length <= strlen($block)) {
        return substr($block, mt_rand(0, strlen($block) - $length), $length);
    }
    return substr(str_repeat($block, intdiv($length, strlen($block)) + 1), 0, $length);
}

/* Encoding */

function encode_loop(string $input, int $n): int
{
    $len = 0;
    for ($i = 0; $i < $n; $i++) {
        $len += strlen(base64_encode($input));
    }
    return $len;
}

function encode_many(array $inputs, int $rounds): int
{
    $len = 0;
    for ($r = 0; $r < $rounds; $r++) {
        foreach ($inputs as $input) {
            $len += strlen(base64_encode($input));
        }
    }
    return $len;
}

/* Decoding */

function decode_loop(string $input, int $n, bool $strict = false): int
{
    $len = 0;
    for ($i = 0; $i < $n; $i++) {
        $len += strlen(base64_decode($input, $strict));
    }
    return $len;
}

function decode_many(array $inputs, int $rounds, bool $strict = false): int
{
    $len = 0;
    for ($r = 0; $r < $rounds; $r++) {
        foreach ($inputs as $input) {
            $len += strlen(base64_decode($input, $strict));
        }
    }
    return $len;
}

/* Typical base64url idioms (JWT, URL-safe tokens) */

function base64url_encode(string $data): string
{
    return rtrim(strtr(base64_encode($data), "+/", "-_"), "=");
}

function base64url_decode(string $data): string
{
    return base64_decode(strtr($data, "-_", "+/"), true);
}

function jwt_decode_loop(array $tokens, int $rounds): int
{
    $len = 0;
    for ($r = 0; $r < $rounds; $r++) {
        foreach ($tokens as $token) {
            [$header, $payload, $signature] = explode(".", $token);
            $len += strlen(base64url_decode($header));
            $len += strlen(base64url_decode($payload));
            $len += strlen(base64url_decode($signature));
        }
    }
    return $len;
}

/* Data URIs, e.g., inlined images */

function data_uri_loop(array $images, int $rounds): int
{
    $len = 0;
    for ($r = 0; $r < $rounds; $r++) {
        foreach ($images as $image) {
            $uri = "data:image/png;base64," . base64_encode($image);
            $comma = strpos($uri, ",");
            $len += strlen(base64_decode(substr($uri, $comma + 1), true));
        }
    }
    return $len;
}

/* Inputs */

$token16 = bytes(16);
$token16_b64 = base64_encode($token16);
$token32 = bytes(32);
$token32_b64 = base64_encode($token32);
$json1k = bytes(1024);
$json1k_b64 = base64_encode($json1k);
$attachment64k = bytes(65536);
$attachment64k_b64 = base64_encode($attachment64k);
$attachment64k_mime = chunk_split($attachment64k_b64, 76, "\r\n");
$blob1m = bytes(1048576);
$blob1m_b64 = base64_encode($blob1m);

/* Sizes spread log-uniformly between 1 byte and 8 KiB */
$mixed = [];
for ($i = 0; $i < 1000; $i++) {
    $mixed[] = bytes((int) round(exp(mt_rand() / mt_getrandmax() * log(8192))));
}
$mixed_b64 = array_map("base64_encode", $mixed);

$jwts = [];
for ($i = 0; $i < 100; $i++) {
    $jwts[] = base64url_encode('{"alg":"HS256","typ":"JWT"}') . "."
        . base64url_encode(bytes(mt_rand(100, 600))) . "."
        . base64url_encode(bytes(32));
}

$images = [];
for ($i = 0; $i < 20; $i++) {
    $images[] = bytes(mt_rand(1024, 16384));
}

/* Sanity checks */

$ok = base64_decode($attachment64k_mime) === $attachment64k
    && base64_decode($blob1m_b64, true) === $blob1m
    && array_map(fn($s) => base64_decode($s, true), $mixed_b64) === $mixed
    && base64_decode($attachment64k_mime, true) === $attachment64k
    && base64_decode($token32_b64 . "!", true) === false
    && jwt_decode_loop($jwts, 1) > 0;

/* Timing */

function gethrtime()
{
    $hrtime = hrtime();
    return (($hrtime[0] * 1000000000 + $hrtime[1]) / 1000000000);
}

function start_test()
{
    ob_start();
    return gethrtime();
}

function end_test($start, $name)
{
    global $total;
    $end = gethrtime();
    ob_end_clean();
    $total += $end - $start;
    $num = number_format($end - $start, 6);
    $pad = str_repeat(" ", 36 - strlen($name) - strlen($num));

    echo $name . $pad . $num . "\n";
    ob_start();
    return gethrtime();
}

function total()
{
    global $total;
    $pad = str_repeat("-", 36);
    echo $pad . "\n";
    $num = number_format($total, 6);
    $pad = str_repeat(" ", 36 - strlen("Total") - strlen($num));
    echo "Total" . $pad . $num . "\n";
}

$t0 = $t = start_test();
encode_loop($token16, 2000000);
$t = end_test($t, "encode 16 B");
decode_loop($token16_b64, 1000000);
$t = end_test($t, "decode 16 B");
encode_loop($token32, 2000000);
$t = end_test($t, "encode 32 B");
decode_loop($token32_b64, 1000000);
$t = end_test($t, "decode 32 B");
decode_loop($token32_b64, 1000000, true);
$t = end_test($t, "decode 32 B (strict)");
encode_loop($json1k, 1000000);
$t = end_test($t, "encode 1 KiB");
decode_loop($json1k_b64, 1000000);
$t = end_test($t, "decode 1 KiB");
decode_loop($json1k_b64, 1000000, true);
$t = end_test($t, "decode 1 KiB (strict)");
encode_loop($attachment64k, 25000);
$t = end_test($t, "encode 64 KiB");
decode_loop($attachment64k_b64, 25000);
$t = end_test($t, "decode 64 KiB");
decode_loop($attachment64k_mime, 500);
$t = end_test($t, "decode 64 KiB (MIME, CRLF)");
encode_loop($blob1m, 1000);
$t = end_test($t, "encode 1 MiB");
decode_loop($blob1m_b64, 1000, true);
$t = end_test($t, "decode 1 MiB (strict)");
encode_many($mixed, 500);
$t = end_test($t, "encode mixed 1 B-8 KiB");
decode_many($mixed_b64, 500);
$t = end_test($t, "decode mixed 1 B-8 KiB");
jwt_decode_loop($jwts, 1000);
$t = end_test($t, "JWT decode (base64url)");
data_uri_loop($images, 4000);
$t = end_test($t, "data URI round trip");
total();
echo "Sanity check: " . ($ok ? "ok" : "FAILED") . "\n";
