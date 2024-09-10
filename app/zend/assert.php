<?php

declare(strict_types=1);

error_reporting(E_ALL);
ini_set("display_errors", true);

function assertEquals(string $expected, string $actual): void
{
    $expectedArray = explode("\n", $expected);
    $expectedArrayCount = count($expectedArray);
    $actualArray = explode("\n", $actual);
    $actualArrayCount = count($actualArray);
    if ($expectedArrayCount !== $actualArrayCount) {
        echo "Expected and actual output does not have the same number of lines ($expectedArrayCount vs $actualArrayCount).\n";
        echo "Output: \n$actual\n";
        exit(1);
    }

    foreach ($expectedArray as $line => $expectedLine) {
        $actualLine = trim($actualArray[$line]);
        $quotedExpectedLine = preg_quote(trim($expectedLine), "#");
        $quotedExpectedLine = str_replace(
            [
                "%s", // string pattern
                "%d", // integer pattern
                "%f", // float pattern
                "%v", // version pattern
            ],
            [
                '.+',
                '\d+',
                '\d+\.\d+',
                '\d+\.\d+.\d+(?:-dev)*',
            ],
            $quotedExpectedLine
        );

        $result = preg_match("#^$quotedExpectedLine\$#", $actualLine);
        if ($result === false) {
            echo "Error in regular expression at line " . ($line + 1) . ": " . preg_last_error_msg() . "\n";
            echo "Pattern: $quotedExpectedLine\n";
            exit(1);
        }

        if ($result === 0) {
            echo "Invalid output at line " . ($line + 1) . ": $actualLine\n";
            echo "Pattern: $quotedExpectedLine\n";
            exit(1);
        }
    }

    echo "Output is valid\n";
    exit(0);
}

$expectationFilename = $argv[1] ?? null;
$actualFilename = $argv[2] ?? null;
if ($expectationFilename === null || $actualFilename === null) {
    echo "Missing arguments\n";
    exit(1);
}

$expected = file_get_contents($expectationFilename);
if ($expected === false) {
    echo "Empty file or unsuccessful read: $expectationFilename";
    exit(1);
}

$actual = file_get_contents($actualFilename);
if ($actual === false) {
    echo "Empty file or unsuccessful read: $actualFilename";
    exit(1);
}

assertEquals($expected, $actual);
