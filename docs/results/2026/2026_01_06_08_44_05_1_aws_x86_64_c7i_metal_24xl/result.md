### AWS x86_64 (c7i.24xl)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c7i.metal-24xl (dedicated)|
| Architecture  |x86_64
| CPU           |48 cores|
| CPU settings  |disabled deeper C-states, disabled turbo boost, disabled hyper-threading|
| RAM           |188 GB|
| Kernel        |6.1.158-178.288.amzn2023.x86_64|
| OS            |Amazon Linux 2023.9.20251117|
| GCC           |14.2.1|
| Time          |2026-01-06 08:44:05 UTC|

### Laravel 12.11.0 demo app - 100 consecutive runs, 50 warmups, 100 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % |   Skew  | P-value |     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|---------|---------|---------------|
|[PHP 8.2](https://github.com/php/php-src/commit/8c303713f1)|0.47919|0.48206|0.00052|0.11%|0.48029|0.00%|0.48021|0.00%|0.526|0.999|46.33 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/604aec3956)|0.47983|0.48930|0.00126|0.26%|0.48113|0.17%|0.48078|0.12%|3.369|0.000|46.50 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/1c9f117d74)|0.48414|0.48824|0.00063|0.13%|0.48528|1.04%|0.48521|1.04%|1.966|0.000|48.17 MB|
|[PHP 8.5](https://github.com/php/php-src/commit/9b089edcbd)|0.47572|0.47864|0.00062|0.13%|0.47692|-0.70%|0.47680|-0.71%|0.551|0.000|48.44 MB|
|[PHP 8.5 (JIT)](https://github.com/php/php-src/commit/9b089edcbd)|0.45702|0.45995|0.00046|0.10%|0.45796|-4.65%|0.45794|-4.64%|0.865|0.000|58.11 MB|

### Symfony 2.8.0 demo app - 100 consecutive runs, 50 warmups, 100 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % |   Skew  | P-value |     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|---------|---------|---------------|
|[PHP 8.2](https://github.com/php/php-src/commit/8c303713f1)|0.80635|1.10334|0.09777|10.62%|0.92069|0.00%|0.88613|0.00%|0.643|0.999|45.74 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/604aec3956)|0.80386|1.07955|0.07582|8.60%|0.88141|-4.27%|0.86927|-1.90%|0.934|0.012|46.02 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/1c9f117d74)|0.79713|0.93219|0.04118|4.94%|0.83281|-9.54%|0.81861|-7.62%|0.937|0.000|47.55 MB|
|[PHP 8.5](https://github.com/php/php-src/commit/9b089edcbd)|0.79596|1.09369|0.12164|13.85%|0.87816|-4.62%|0.81164|-8.41%|1.116|0.000|47.30 MB|
|[PHP 8.5 (JIT)](https://github.com/php/php-src/commit/9b089edcbd)|0.76893|1.03383|0.10273|12.03%|0.85424|-7.22%|0.81072|-8.51%|0.817|0.000|54.83 MB|

### Wordpress 6.9 main page - 100 consecutive runs, 20 warmups, 20 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % |   Skew  | P-value |     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|---------|---------|---------------|
|[PHP 8.2](https://github.com/php/php-src/commit/8c303713f1)|0.70314|0.71316|0.00273|0.39%|0.70624|0.00%|0.70466|0.00%|0.593|0.999|53.49 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/604aec3956)|0.70176|0.72538|0.00336|0.48%|0.70494|-0.18%|0.70352|-0.16%|2.491|0.000|53.76 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/1c9f117d74)|0.69572|0.70389|0.00254|0.36%|0.69919|-1.00%|0.69774|-0.98%|0.496|0.000|54.49 MB|
|[PHP 8.5](https://github.com/php/php-src/commit/9b089edcbd)|0.69386|0.71822|0.00366|0.53%|0.69712|-1.29%|0.69547|-1.30%|2.857|0.000|54.85 MB|
|[PHP 8.5 (JIT)](https://github.com/php/php-src/commit/9b089edcbd)|0.61920|0.62627|0.00227|0.36%|0.62190|-11.94%|0.62067|-11.92%|0.577|0.000|78.22 MB|

### bench.php - 100 consecutive runs, 10 warmups, 2 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % |   Skew  | P-value |     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|---------|---------|---------------|
|[PHP 8.2](https://github.com/php/php-src/commit/8c303713f1)|0.43805|0.48805|0.00841|1.89%|0.44398|0.00%|0.44179|0.00%|3.451|0.999|29.68 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/604aec3956)|0.42640|0.49685|0.01163|2.68%|0.43342|-2.38%|0.42990|-2.69%|3.157|0.000|29.71 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/1c9f117d74)|0.42762|0.54684|0.02559|5.85%|0.43715|-1.54%|0.43069|-2.51%|3.768|0.000|30.84 MB|
|[PHP 8.5](https://github.com/php/php-src/commit/9b089edcbd)|0.43610|0.55364|0.02440|5.48%|0.44533|0.30%|0.43908|-0.61%|3.774|0.000|31.08 MB|
|[PHP 8.5 (JIT)](https://github.com/php/php-src/commit/9b089edcbd)|0.14717|0.15213|0.00101|0.68%|0.14923|-66.39%|0.14925|-66.22%|0.313|0.000|31.91 MB|
