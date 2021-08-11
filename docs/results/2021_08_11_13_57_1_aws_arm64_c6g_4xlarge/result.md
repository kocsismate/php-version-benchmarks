### AWS ARM64 (c6g.4xlarge)

|  Attribute  |     Value   |
|-------------|-------------|
|Environment|aws|
|Provisioner|host|
|Instance type|c6g.4xlarge|
|Architecture|aarch64
|CPU||
CPU cores|16|
|CPU attributes||
|RAM|30 GB|
|
|Kernel|4.14.238-182.422.amzn2.aarch64|
|OS|Amazon Linux 2|
|Time|2021-08-11 13:57|
### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/6724d5d4c2c502b098e708bd85b43f2a52848093)|1.38915|1.43153|0.01176|1.40654|0.00%|1.40437|0.00%|
|[PHP 8.0](https://github.com/php/php-src/commit/ee11a6065c4a9280e1d6188fbb2a3d5aa532d84d)|1.30990|1.35202|0.01017|1.32320|-6.30%|1.32102|-6.31%|
|[PHP 8.1](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.07688|1.08877|0.00337|1.08144|-30.06%|1.08131|-29.88%|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.07198|1.09460|0.00670|1.08021|-30.21%|1.07707|-30.39%|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.07343|1.08997|0.00429|1.07929|-30.32%|1.07887|-30.17%|
### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/6724d5d4c2c502b098e708bd85b43f2a52848093)|1.68021|1.74907|0.01819|1.70125|0.00%|1.69624|0.00%|
|[PHP 8.0](https://github.com/php/php-src/commit/ee11a6065c4a9280e1d6188fbb2a3d5aa532d84d)|1.62928|1.67166|0.01244|1.64915|-3.16%|1.64629|-3.03%|
|[PHP 8.1](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.28511|1.30353|0.00472|1.29120|-31.76%|1.28974|-31.52%|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.26520|1.32804|0.01620|1.27984|-32.93%|1.27348|-33.20%|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.28098|1.30886|0.00691|1.28951|-31.93%|1.28583|-31.92%|
### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/6724d5d4c2c502b098e708bd85b43f2a52848093)|0.34630|0.35161|0.00149|0.34901|0.00%|0.34942|0.00%|
|[PHP 8.0](https://github.com/php/php-src/commit/ee11a6065c4a9280e1d6188fbb2a3d5aa532d84d)|0.33318|0.33851|0.00147|0.33591|-3.90%|0.33571|-4.08%|
|[PHP 8.1](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|0.34267|0.34663|0.00100|0.34475|-1.24%|0.34463|-1.39%|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|0.11173|0.11388|0.00051|0.11225|-210.91%|0.11208|-211.76%|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|0.34573|0.34833|0.00071|0.34737|-0.47%|0.34754|-0.54%|
### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/6724d5d4c2c502b098e708bd85b43f2a52848093)|2.23914|2.24477|0.00153|2.24192|0.00%|2.24223|0.00%|
|[PHP 8.0](https://github.com/php/php-src/commit/ee11a6065c4a9280e1d6188fbb2a3d5aa532d84d)|2.10277|2.10913|0.00193|2.10541|-6.48%|2.10515|-6.51%|
|[PHP 8.1](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|2.05309|2.06010|0.00174|2.05593|-9.05%|2.05551|-9.08%|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|1.21728|1.22238|0.00154|1.21964|-83.82%|1.21927|-83.90%|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/c90c9c7545427d9d35cbac45c4ec896f54619744)|2.04771|2.05387|0.00191|2.05015|-9.35%|2.04980|-9.39%|
