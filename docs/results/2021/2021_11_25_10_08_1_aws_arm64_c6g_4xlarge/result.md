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
|Time|2021-11-25 10:08:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/60fe575ce3d5ad0647d3c12698d0d3fcb0cb8f7b)|1.33131|1.42081|0.01762|1.34195|0.00%|1.33758|0.00%|32.89 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/e713890d369499ab896e926b099fca244980cf0e)|1.26665|1.27868|0.00330|1.27094|-5.29%|1.26997|-5.05%|32.45 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.04292|1.04941|0.00173|1.04546|-22.09%|1.04512|-21.87%|35.32 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.03823|1.07050|0.00604|1.04179|-22.37%|1.04102|-22.17%|43.14 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.04316|1.05606|0.00256|1.04756|-21.94%|1.04752|-21.69%|35.37 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/d0a3cc146db9bf7c18d8860dcd5442da8354406c)|1.04228|1.05082|0.00209|1.04551|-22.09%|1.04561|-21.83%|35.14 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/60fe575ce3d5ad0647d3c12698d0d3fcb0cb8f7b)|1.63921|1.66050|0.00490|1.64521|0.00%|1.64431|0.00%|33.23 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/e713890d369499ab896e926b099fca244980cf0e)|1.60439|1.67136|0.01610|1.61613|-1.77%|1.60960|-2.11%|33.50 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.25670|1.26578|0.00235|1.26077|-23.37%|1.26076|-23.33%|33.59 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.23050|1.24088|0.00279|1.23576|-24.89%|1.23568|-24.85%|42.70 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.25514|1.26973|0.00303|1.26082|-23.36%|1.26065|-23.33%|34.09 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/d0a3cc146db9bf7c18d8860dcd5442da8354406c)|1.24347|1.25410|0.00269|1.24699|-24.20%|1.24660|-24.19%|33.81 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/60fe575ce3d5ad0647d3c12698d0d3fcb0cb8f7b)|0.34303|0.34526|0.00059|0.34365|0.00%|0.34339|0.00%|23.54 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/e713890d369499ab896e926b099fca244980cf0e)|0.33407|0.33982|0.00172|0.33652|-2.08%|0.33607|-2.13%|23.26 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|0.34348|0.34512|0.00048|0.34410|0.13%|0.34395|0.16%|23.78 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|0.10815|0.10984|0.00046|0.10873|-68.36%|0.10869|-68.35%|25.54 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|0.34355|0.34933|0.00152|0.34634|0.78%|0.34632|0.85%|23.55 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/d0a3cc146db9bf7c18d8860dcd5442da8354406c)|0.33185|0.33493|0.00104|0.33381|-2.86%|0.33435|-2.63%|23.30 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 7.4](https://github.com/php/php-src/commit/60fe575ce3d5ad0647d3c12698d0d3fcb0cb8f7b)|2.21906|2.22713|0.00204|2.22504|0.00%|2.22562|0.00%|17.61 MB|
|[PHP 8.0](https://github.com/php/php-src/commit/e713890d369499ab896e926b099fca244980cf0e)|2.09911|2.11112|0.00333|2.10565|-5.37%|2.10499|-5.42%|17.37 MB|
|[PHP 8.1](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|2.04848|2.05488|0.00189|2.05128|-7.81%|2.05103|-7.84%|17.95 MB|
|[PHP 8.1 (JIT)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|1.19378|1.20010|0.00167|1.19601|-46.25%|1.19549|-46.29%|19.22 MB|
|[PHP 8.1 (preloading)](https://github.com/php/php-src/commit/80d63e9d17fd244624b2b6ecb29b6462a92bc0f0)|2.03869|2.05123|0.00327|2.04478|-8.10%|2.04487|-8.12%|17.88 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/d0a3cc146db9bf7c18d8860dcd5442da8354406c)|2.05081|2.05579|0.00178|2.05376|-7.70%|2.05462|-7.68%|17.51 MB|
