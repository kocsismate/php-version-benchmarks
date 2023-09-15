### AWS x86_64 (c5.4xlarge)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c6i.4xlarge|
| Architecture  |x86_64
| CPU           |8 cores|
| RAM           |30 GB|
| Kernel        |6.1.49-70.116.amzn2023.x86_64|
| OS            |Amazon Linux 2023|
| GCC           |11.4.1|
| Time          |2023-09-15 23:18:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.77682|0.78074|0.00109|0.77855|0.00%|0.77843|0.00%|47.12 MB|
|[PHP 8.4 (JIT-IR)](https://github.com/dstogov/php-src/commit/9a736d54a5e6c0f8becffa77adde9015fc84fcc3)|0.77143|0.77671|0.00149|0.77440|-0.53%|0.77479|-0.47%|47.29 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.78554|0.78927|0.00091|0.78750|1.15%|0.78750|1.17%|39.22 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.36970|0.37298|0.00070|0.37122|0.00%|0.37122|0.00%|38.03 MB|
|[PHP 8.4 (JIT-IR)](https://github.com/dstogov/php-src/commit/9a736d54a5e6c0f8becffa77adde9015fc84fcc3)|0.36941|0.37112|0.00051|0.37021|-0.27%|0.37022|-0.27%|39.02 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.35561|0.35769|0.00052|0.35679|-3.89%|0.35682|-3.88%|33.10 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.06728|0.06989|0.00065|0.06774|0.00%|0.06751|0.00%|25.82 MB|
|[PHP 8.4 (JIT-IR)](https://github.com/dstogov/php-src/commit/9a736d54a5e6c0f8becffa77adde9015fc84fcc3)|0.06355|0.06528|0.00044|0.06381|-5.79%|0.06368|-5.66%|25.86 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.18493|0.18542|0.00013|0.18520|173.41%|0.18518|174.32%|25.01 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|0.62933|0.63412|0.00119|0.63104|0.00%|0.63123|0.00%|20.11 MB|
|[PHP 8.4 (JIT-IR)](https://github.com/dstogov/php-src/commit/9a736d54a5e6c0f8becffa77adde9015fc84fcc3)|0.56741|0.57395|0.00214|0.57076|-9.55%|0.57113|-9.52%|20.07 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/7c4db150cb490b476c0b6a6bf9319306856b96ec)|1.17913|1.18263|0.00114|1.18086|87.13%|1.18086|87.07%|19.23 MB|
