<?php

declare(strict_types=1);

enum MetricName
{
    case MEAN;
    case MEAN_ABSOLUTE_DIFFERENCE;
    case ABSOLUTE_MEAN;
}

$expectedHeaders = [
    "Test name", "Test warmup", "Test iterations", "Test requests", "PHP",
    "PHP Commit hash", "PHP Commit URL", "Min", "Max", "Std dev",
    "Rel std dev %", "Mean", "Mean diff %", "Median", "Median diff %",
    "Skew", "P-value", "Instruction count", "Memory usage"
];

$numericColumns = [
    "Min", "Max", "Std dev", "Rel std dev %", "Mean", "Mean diff %",
    "Median", "Median diff %", "Skew", "P-value", "Instruction count", "Memory usage"
];

$outHeaders = [
    "Rel std dev % mean", "Mean MAD", "Mean diff % MAD", "Median diff % MAD", "Median diff % MAD", "Skew abs mean",
];

$outColumns = [
    "Rel std dev %" => MetricName::MEAN,
    "Mean" => MetricName::MEAN_ABSOLUTE_DIFFERENCE,
    "Mean diff %" => MetricName::MEAN_ABSOLUTE_DIFFERENCE,
    "Median" => MetricName::MEAN_ABSOLUTE_DIFFERENCE,
    "Median diff %" => MetricName::MEAN_ABSOLUTE_DIFFERENCE,
    "Skew" => MetricName::ABSOLUTE_MEAN,
];

$outputFile = $argv[1];
$inputFiles = array_slice($argv, 2);
if (empty($inputFiles)) {
    fwrite(STDERR, "Usage: php output_file.md input_file1.tsv input_file2.csv ...\n");
    exit(1);
}

$tests = [];

foreach ($inputFiles as $file) {
    if (!file_exists($file)) {
        fwrite(STDERR, "File not found: $file\n");
        continue;
    }

    if (($handle = fopen($file, "r")) === false) {
        fwrite(STDERR, "Could not open file: $file\n");
        continue;
    }

    $headers = fgetcsv($handle, separator: "\t", escape: '\\');
    if ($headers === false || $headers !== $expectedHeaders) {
        fwrite(STDERR, "Invalid headers in $file\n");
        fclose($handle);
        continue;
    }

    while (($row = fgetcsv($handle, separator: "\t", escape: '\\')) !== false) {
        $rowData = array_combine($headers, $row);
        if ($rowData === false) {
            continue;
        }

        $test = $rowData["Test name"];
        $php = $rowData["PHP"];

        if (!isset($tests[$test])) {
            $tests[$test] = [];
        }

        $tests[$test][$php][] = $rowData;
    }

    fclose($handle);
}

// Write markdown
$fh = fopen($outputFile, "w");

foreach ($tests as $testName => $phpGroups) {
    fwrite($fh, "## " . $testName . "\n\n");

    // Header row
    $cols = array_merge(["PHP"], $outHeaders);
    fwrite($fh, "| " . implode(" | ", $cols) . " |\n");
    fwrite($fh, "| " . str_repeat(" --- |", count($cols)) . "\n");

    $columnResults = [];

    foreach ($phpGroups as $phpName => $rows) {
        // calculate metric result within this PHP group
        $results = [];
        foreach ($outColumns as $column => $metricName) {
            $values = array_map(fn (string $x) => (float) $x, array_column($rows, $column));
            $result = calculate_metric($metricName, $values);
            $results[$column] = $result;

            $columnResults[$column][] = $result;
        }

        // Row
        $row = [$phpName];
        foreach ($outColumns as $column => $metricName) {
            $row[] = sprintf("%.5f", $results[$column]);
        }
        fwrite($fh, "| " . implode(" | ", $row) . " |\n");
    }

    // Overall summary row
    $summaryRow = ["**Summary**"];
    foreach ($outColumns as $column => $metricName) {
        $results = calculate_metric($metricName, $columnResults[$column]);
        $summaryRow[] = sprintf("**%.5f**", $results);
    }
    fwrite($fh, "| " . implode(" | ", $summaryRow) . " |\n\n");
}

fclose($fh);
echo "Wrote $outputFile\n";

function calculate_metric(MetricName $metricName, array $values): float
{
    return match ($metricName) {
        MetricName::MEAN => mean($values),
        MetricName::MEAN_ABSOLUTE_DIFFERENCE => mean_absolute_difference($values),
        MetricName::ABSOLUTE_MEAN => abs_mean($values),
    };
}

function abs_mean(array $values): float
{
    $n = count($values);
    if ($n === 0) {
        throw new Exception("Empty dataset");
    }

    $sum = 0.0;
    foreach ($values as $v) {
        $sum += abs($v);
    }

    return $sum / $n;
}

function mean(array $values): float
{
    $n = count($values);
    if ($n === 0) {
        throw new Exception("Empty dataset");
    }

    return array_sum($values) / $n;
}

function mean_absolute_difference(array $values): float
{
    $n = count($values);
    if ($n === 0) {
        throw new Exception("Empty dataset");
    }

    if ($n === 1) {
        return $values[0];
    }

    $sum = 0.0;

    // Go through all unique pairs (i < j)
    foreach ($values as $i => $iValue) {
        for ($j = $i + 1; $j < $n; $j++) {
            $sum += abs($iValue - $values[$j]);
        }
    }

    // Formula: (2 / (N * (N-1))) * sum of absolute differences
    return (2 / ($n * ($n - 1))) * $sum;
}
