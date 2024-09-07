### AWS x86_64 (c7i.24xl)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c7i.metal-24xl|
| Architecture  |x86_64
| CPU           |48 cores|
| RAM           |188 GB|
| Kernel        |6.1.92-99.174.amzn2023.x86_64|
| OS            |Amazon Linux 2023.4.20240611|
| GCC           |11.4.1|
| Time          |2024-06-23 09:39:00|

### Laravel demo app - 25 consecutive runs, 100 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/a87ccc7ca2644e327c210e68b4d98df98ad33523)|0.42279|0.42435|0.00043|0.42339|0.00%|0.42336|0.00%|39.35 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/686afc10bfe2fad59c8b552f60d34441e7e67d18)|0.41723|0.41841|0.00033|0.41782|-1.32%|0.41776|-1.32%|39.69 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/04418ede7a9fab4358b5d2677621fc7fc22a0aab)|0.41123|0.41959|0.00144|0.41797|-1.28%|0.41816|-1.23%|39.11 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/338be9dd9c9be823ac3837ab28b11667ba9e33eb)|0.43044|0.43259|0.00044|0.43132|1.87%|0.43120|1.85%|40.52 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/678a481f62db7776156bc69eaa87aaf2ec9e6673)|0.43027|0.43218|0.00046|0.43108|1.82%|0.43107|1.82%|40.52 MB|

### Symfony demo app - 25 consecutive runs, 100 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/a87ccc7ca2644e327c210e68b4d98df98ad33523)|0.19917|0.20050|0.00028|0.19982|0.00%|0.19980|0.00%|32.91 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/686afc10bfe2fad59c8b552f60d34441e7e67d18)|0.19535|0.21810|0.00434|0.19687|-1.48%|0.19597|-1.92%|33.30 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/04418ede7a9fab4358b5d2677621fc7fc22a0aab)|0.19643|0.25722|0.01180|0.19945|-0.18%|0.19704|-1.39%|33.32 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/338be9dd9c9be823ac3837ab28b11667ba9e33eb)|0.19829|0.25703|0.01139|0.20127|0.73%|0.19889|-0.46%|34.01 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/678a481f62db7776156bc69eaa87aaf2ec9e6673)|0.19815|0.19996|0.00038|0.19873|-0.54%|0.19874|-0.53%|34.26 MB|

### Wordpress - 25 consecutive runs, 20 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/a87ccc7ca2644e327c210e68b4d98df98ad33523)|0.59596|0.60694|0.00206|0.59729|0.00%|0.59697|0.00%|42.10 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/686afc10bfe2fad59c8b552f60d34441e7e67d18)|0.59193|0.59465|0.00060|0.59310|-0.70%|0.59299|-0.67%|42.40 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/04418ede7a9fab4358b5d2677621fc7fc22a0aab)|0.59325|0.59624|0.00070|0.59432|-0.50%|0.59424|-0.46%|42.32 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/338be9dd9c9be823ac3837ab28b11667ba9e33eb)|0.57679|0.57983|0.00067|0.57794|-3.24%|0.57800|-3.18%|42.60 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/678a481f62db7776156bc69eaa87aaf2ec9e6673)|0.57682|0.57870|0.00047|0.57774|-3.27%|0.57767|-3.23%|42.60 MB|

### bench.php - 5 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/a87ccc7ca2644e327c210e68b4d98df98ad33523)|0.22076|0.22379|0.00114|0.22267|0.00%|0.22308|0.00%|25.39 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/686afc10bfe2fad59c8b552f60d34441e7e67d18)|0.21432|0.21849|0.00151|0.21552|-3.21%|0.21486|-3.68%|25.26 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/04418ede7a9fab4358b5d2677621fc7fc22a0aab)|0.21524|0.21610|0.00030|0.21559|-3.18%|0.21543|-3.43%|25.33 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/338be9dd9c9be823ac3837ab28b11667ba9e33eb)|0.23193|0.23282|0.00033|0.23253|4.43%|0.23266|4.30%|26.01 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/678a481f62db7776156bc69eaa87aaf2ec9e6673)|0.21484|0.21612|0.00051|0.21554|-3.20%|0.21558|-3.36%|26.01 MB|

### micro_bench.php - 5 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/a87ccc7ca2644e327c210e68b4d98df98ad33523)|1.35427|1.36799|0.00502|1.35877|0.00%|1.35627|0.00%|19.54 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/686afc10bfe2fad59c8b552f60d34441e7e67d18)|1.37761|1.38736|0.00323|1.38232|1.73%|1.38228|1.92%|19.53 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/04418ede7a9fab4358b5d2677621fc7fc22a0aab)|1.31011|1.33389|0.00923|1.31797|-3.00%|1.31280|-3.21%|19.59 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/338be9dd9c9be823ac3837ab28b11667ba9e33eb)|1.36869|1.37560|0.00270|1.37171|0.95%|1.37056|1.05%|20.26 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/678a481f62db7776156bc69eaa87aaf2ec9e6673)|1.36729|1.38077|0.00539|1.37439|1.15%|1.37557|1.42%|20.26 MB|
