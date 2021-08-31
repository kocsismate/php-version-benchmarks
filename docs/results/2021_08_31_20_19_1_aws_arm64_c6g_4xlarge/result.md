### AWS ARM64 (c6g.4xlarge)

|  Attribute  |     Value   |
|-------------|-------------|
|Environment|aws|
|Runner|host|
|Instance type|c6g.4xlarge|
|Architecture|aarch64
|CPU|16 cores|
|RAM|30 GB|
|Kernel|4.14.238-182.422.amzn2.aarch64|
|OS|Amazon Linux 2|
|Time|2021-08-31 20:19:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/8c292a2f9d20151d7269f8b95d5ddde226c8efb8)|1.37701|1.45257|0.01896|1.40631|0.00%|1.40063|0.00%|32.47 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/db055fdb89069bba18c7552e46d698580b8fcea5)|1.30845|1.37365|0.01902|1.33532|-5.32%|1.32735|-5.52%|32.94 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.06460|1.11534|0.01784|1.08230|-29.94%|1.07295|-30.54%|35.29 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.05992|1.11450|0.01757|1.07403|-30.94%|1.06663|-31.31%|43.48 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.06307|1.10694|0.01552|1.07643|-30.65%|1.06910|-31.01%|35.13 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/8c292a2f9d20151d7269f8b95d5ddde226c8efb8)|1.70105|1.78262|0.02603|1.74944|0.00%|1.75835|0.00%|32.75 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/db055fdb89069bba18c7552e46d698580b8fcea5)|1.62905|1.74415|0.02812|1.67267|-4.59%|1.65874|-6.01%|32.78 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.27752|1.33788|0.02066|1.29666|-34.92%|1.28606|-36.72%|32.87 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.25395|1.31855|0.02306|1.27987|-36.69%|1.26722|-38.76%|41.95 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.27473|1.33627|0.01937|1.29065|-35.55%|1.28263|-37.09%|33.31 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/8c292a2f9d20151d7269f8b95d5ddde226c8efb8)|0.34236|0.35150|0.00239|0.34682|0.00%|0.34621|0.00%|22.81 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/db055fdb89069bba18c7552e46d698580b8fcea5)|0.33479|0.34215|0.00214|0.33797|-2.62%|0.33759|-2.55%|22.72 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|0.35030|0.35361|0.00087|0.35164|1.37%|0.35139|1.47%|23.05 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|0.11169|0.11353|0.00048|0.11198|-209.72%|0.11181|-209.64%|24.65 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|0.34586|0.34973|0.00096|0.34798|0.33%|0.34804|0.53%|22.94 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/8c292a2f9d20151d7269f8b95d5ddde226c8efb8)|2.22534|2.23211|0.00160|2.22953|0.00%|2.22982|0.00%|16.67 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/db055fdb89069bba18c7552e46d698580b8fcea5)|2.10279|2.11186|0.00218|2.10753|-5.79%|2.10742|-5.81%|16.69 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|2.05706|2.06892|0.00295|2.06267|-8.09%|2.06290|-8.09%|16.80 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|1.21532|1.22219|0.00160|1.21938|-82.84%|1.21971|-82.82%|18.39 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/b0dd55b11c73e5f089c78221b1605884ed29c338)|2.04623|2.06020|0.00430|2.05483|-8.50%|2.05495|-8.51%|16.96 MB|
