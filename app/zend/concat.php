<?php

function gethrtime(): float
{
    $hrtime = hrtime();
    return (($hrtime[0]*1000000000 + $hrtime[1]) / 1000000000);
}

function random_str(): string
{
    return bin2hex(random_bytes(4));
}

function test(int $n): void
{
    $a = random_str();
    $b = random_str();
    $c = random_str();

    ob_start();
    $t1 = gethrtime();

    $str = "";
    while ($n-- > 0) {
        $str .= $a . "-" . $b . "$c\n";
    }

    echo $str;

    $t2 = gethrtime();
    ob_end_clean();

    echo "Total              " . number_format($t2 - $t1, 3) . "\n";
}

test(5000000);
