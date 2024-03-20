### AWS x86_64 (c7i.24xl)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c7i.metal-24xl|
| Architecture  |x86_64
| CPU           |48 cores|
| RAM           |188 GB|
| Kernel        |6.1.79-99.164.amzn2023.x86_64|
| OS            |Amazon Linux 2023.3.20240312|
| GCC           |11.4.1|
| Time          |2024-03-20 23:00:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/4922b9eb7d3e9d78412d8ab8b0bcacb5658dd289)|1.05431|1.05885|0.00127|1.05643|0.00%|1.05627|0.00%|38.96 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/741570c30fffc77b67954ff8938d410cc0ff8329)|1.04583|1.05161|0.00136|1.04786|-0.81%|1.04746|-0.83%|39.43 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/05989e9e2cfbc11a6bde3063a6be9ede22ee983e)|1.04152|1.05515|0.00253|1.04345|-1.23%|1.04300|-1.26%|38.71 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|1.06595|1.07187|0.00136|1.06818|1.11%|1.06817|1.13%|40.23 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|1.06453|1.06957|0.00111|1.06645|0.95%|1.06614|0.93%|40.23 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/4922b9eb7d3e9d78412d8ab8b0bcacb5658dd289)|0.49329|0.49880|0.00113|0.49465|0.00%|0.49446|0.00%|32.71 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/741570c30fffc77b67954ff8938d410cc0ff8329)|0.48852|0.49310|0.00092|0.49022|-0.89%|0.49011|-0.88%|32.92 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/05989e9e2cfbc11a6bde3063a6be9ede22ee983e)|0.49070|0.49409|0.00083|0.49229|-0.48%|0.49221|-0.45%|33.02 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|0.48938|0.51083|0.00405|0.49130|-0.68%|0.49043|-0.81%|33.99 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|0.48858|0.49270|0.00091|0.49010|-0.92%|0.49002|-0.90%|33.99 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/4922b9eb7d3e9d78412d8ab8b0bcacb5658dd289)|0.21699|0.22055|0.00102|0.21833|0.00%|0.21791|0.00%|25.28 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/741570c30fffc77b67954ff8938d410cc0ff8329)|0.21312|0.21790|0.00122|0.21466|-1.68%|0.21448|-1.58%|25.00 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/05989e9e2cfbc11a6bde3063a6be9ede22ee983e)|0.21417|0.21804|0.00091|0.21578|-1.17%|0.21576|-0.99%|24.97 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|0.21580|0.21869|0.00072|0.21681|-0.69%|0.21673|-0.54%|25.80 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|0.21596|0.21874|0.00071|0.21685|-0.68%|0.21663|-0.59%|25.80 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/4922b9eb7d3e9d78412d8ab8b0bcacb5658dd289)|1.35200|1.38138|0.00890|1.36335|0.00%|1.36258|0.00%|19.21 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/741570c30fffc77b67954ff8938d410cc0ff8329)|1.36216|1.38840|0.00628|1.37140|0.59%|1.37031|0.57%|19.27 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/05989e9e2cfbc11a6bde3063a6be9ede22ee983e)|1.30670|1.33295|0.00802|1.32027|-3.16%|1.32155|-3.01%|19.24 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|1.34916|1.37571|0.00650|1.36250|-0.06%|1.36216|-0.03%|20.06 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/e1630381b75c960cdc2ba83836be39fed88e211d)|1.34396|1.37058|0.00726|1.35965|-0.27%|1.36165|-0.07%|20.06 MB|
