### AWS ARM64 (c6g.4xlarge)

|  Attribute  |     Value   |
|-------------|-------------|
|Environment|aws|
|Runner|host|
|Instance type|c6g.4xlarge|
|Architecture|aarch64
|CPU|16 cores|
|RAM|30 GB|
|Kernel|4.14.252-195.483.amzn2.aarch64|
|OS|Amazon Linux 2|
|Time|2021-11-11 09:20:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/1919c4b44ddd9f056bd53c79c4b99c9e4ce97884)|1.33639|1.46424|0.03508|1.36586|0.00%|1.35102|0.00%|33.00 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/a551b083073ea08f8fc53b0e1a6380b6de26cc6b)|1.25693|1.39606|0.03539|1.28991|-5.56%|1.27588|-5.56%|32.39 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.05594|1.06841|0.00409|1.06094|-22.32%|1.05898|-21.62%|35.48 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.04156|1.08010|0.00697|1.04972|-23.15%|1.04883|-22.37%|43.29 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.05253|1.14954|0.02023|1.06853|-21.77%|1.06247|-21.36%|35.37 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/1919c4b44ddd9f056bd53c79c4b99c9e4ce97884)|1.65015|1.83175|0.04406|1.68866|0.00%|1.66990|0.00%|33.76 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/a551b083073ea08f8fc53b0e1a6380b6de26cc6b)|1.59925|1.84683|0.05459|1.66024|-1.68%|1.65860|-0.68%|33.34 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.26713|1.38992|0.02972|1.29129|-23.53%|1.27731|-23.50%|33.84 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.23740|1.44721|0.05420|1.27641|-24.41%|1.25853|-24.63%|42.94 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.26346|1.31422|0.01618|1.27825|-24.30%|1.27007|-23.95%|33.92 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/1919c4b44ddd9f056bd53c79c4b99c9e4ce97884)|0.34132|0.34402|0.00067|0.34197|0.00%|0.34182|0.00%|23.52 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/a551b083073ea08f8fc53b0e1a6380b6de26cc6b)|0.33340|0.34220|0.00245|0.33838|-1.05%|0.33817|-1.07%|23.43 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|0.34259|0.35276|0.00247|0.34749|1.61%|0.34850|1.95%|23.52 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|0.10965|0.11136|0.00044|0.10993|-67.85%|0.10978|-67.88%|25.23 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|0.34613|0.35117|0.00180|0.34757|1.64%|0.34623|1.29%|23.53 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/1919c4b44ddd9f056bd53c79c4b99c9e4ce97884)|2.22235|2.23131|0.00219|2.22585|0.00%|2.22555|0.00%|17.77 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/a551b083073ea08f8fc53b0e1a6380b6de26cc6b)|2.10429|2.11293|0.00220|2.10857|-5.27%|2.10894|-5.24%|17.54 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|2.05999|2.06404|0.00108|2.06174|-7.37%|2.06170|-7.36%|17.65 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|1.19769|1.20290|0.00139|1.20044|-46.07%|1.20008|-46.08%|19.14 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/89f28fafcacee5a65022b0ce36c98c14d04238dc)|2.05282|2.06184|0.00240|2.05715|-7.58%|2.05761|-7.56%|17.79 MB|
