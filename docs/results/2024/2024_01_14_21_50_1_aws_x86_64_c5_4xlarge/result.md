### AWS x86_64 (c5.4xlarge)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c6i.4xlarge|
| Architecture  |x86_64
| CPU           |8 cores|
| RAM           |30 GB|
| Kernel        |6.1.66-93.164.amzn2023.x86_64|
| OS            |Amazon Linux 2023|
| GCC           |11.4.1|
| Time          |2024-01-14 21:50:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|0.76862|0.77396|0.00123|0.77080|0.00%|0.77077|0.00%|38.82 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|0.76390|0.76819|0.00109|0.76626|-0.59%|0.76607|-0.61%|39.55 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|0.78817|0.79669|0.00162|0.79136|2.67%|0.79134|2.67%|38.80 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.81345|0.82190|0.00213|0.81701|5.99%|0.81687|5.98%|39.80 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.79329|0.80888|0.00312|0.79709|3.41%|0.79637|3.32%|47.89 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|0.34625|0.35229|0.00115|0.34752|0.00%|0.34744|0.00%|32.73 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|0.34155|0.44763|0.02063|0.34656|-0.28%|0.34238|-1.46%|32.98 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|0.34498|0.34669|0.00045|0.34575|-0.51%|0.34560|-0.53%|33.12 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.35105|0.35426|0.00080|0.35259|1.46%|0.35251|1.46%|33.17 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.36500|0.36816|0.00076|0.36625|5.39%|0.36613|5.38%|39.39 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|0.18679|0.18779|0.00028|0.18724|0.00%|0.18728|0.00%|25.18 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|0.18342|0.18398|0.00018|0.18369|-1.90%|0.18373|-1.90%|25.01 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|0.18795|0.18874|0.00020|0.18839|0.61%|0.18844|0.62%|24.96 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.18557|0.18624|0.00019|0.18594|-0.69%|0.18592|-0.73%|25.32 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.06413|0.06653|0.00060|0.06469|-65.45%|0.06448|-65.57%|26.24 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|1.14874|1.15244|0.00097|1.15083|0.00%|1.15077|0.00%|19.19 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|1.15436|1.15947|0.00116|1.15639|0.48%|1.15633|0.48%|19.18 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|1.18950|1.19473|0.00143|1.19241|3.61%|1.19252|3.63%|19.23 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|1.14662|1.14964|0.00069|1.14812|-0.24%|1.14822|-0.22%|19.71 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.57973|0.58867|0.00308|0.58458|-49.20%|0.58436|-49.22%|20.65 MB|
