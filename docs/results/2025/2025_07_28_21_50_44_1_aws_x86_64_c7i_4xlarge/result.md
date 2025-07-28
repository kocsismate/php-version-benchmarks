### AWS x86_64 (c7i.4xlarge)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c7i.4xlarge|
| Architecture  |x86_64
| CPU           |8 cores|
| CPU settings  |disabled hyper-threading|
| RAM           |30 GB|
| Kernel        |6.1.144-170.251.amzn2023.x86_64|
| OS            |Amazon Linux 2023.8.20250721|
| GCC           |11.5.0|
| Time          |2025-07-28 21:50:44 UTC|

### Laravel 11.1.2 demo app - 50 consecutive runs, 100 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP - master](https://github.com/php/php-src/commit/b30ccf9158)|0.29412|0.30431|0.00173|0.29539|0.00%|0.29503|0.00%|42.16 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/5295fc07d5)|0.29649|0.30017|0.00064|0.29745|0.70%|0.29734|0.78%|41.85 MB|

### Symfony 2.6.0 demo app - 50 consecutive runs, 100 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP - master](https://github.com/php/php-src/commit/b30ccf9158)|0.47156|0.51165|0.00544|0.47405|0.00%|0.47325|0.00%|37.91 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/5295fc07d5)|0.47489|0.52880|0.00735|0.47769|0.77%|0.47660|0.71%|37.67 MB|

### Wordpress 6.2 main page - 80 consecutive runs, 20 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP - master](https://github.com/php/php-src/commit/b30ccf9158)|0.43206|0.46810|0.00707|0.44862|0.00%|0.44862|0.00%|43.30 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/5295fc07d5)|0.43684|0.47436|0.00852|0.45577|1.59%|0.45743|1.96%|43.26 MB|

### bench.php - 50 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP - master](https://github.com/php/php-src/commit/b30ccf9158)|0.13707|0.13923|0.00047|0.13771|0.00%|0.13764|0.00%|26.53 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/5295fc07d5)|0.14029|0.14161|0.00031|0.14084|2.27%|0.14082|2.31%|26.24 MB|

### micro_bench.php - 50 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP - master](https://github.com/php/php-src/commit/b30ccf9158)|0.84488|0.85148|0.00147|0.84823|0.00%|0.84844|0.00%|20.82 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/5295fc07d5)|0.81655|0.82131|0.00094|0.81867|-3.48%|0.81858|-3.52%|20.47 MB|
