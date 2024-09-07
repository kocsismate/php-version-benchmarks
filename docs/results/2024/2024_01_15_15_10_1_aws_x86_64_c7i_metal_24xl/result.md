### AWS x86_64 (c7i.metal-24xl)

|  Attribute    |     Value      |
|---------------|----------------|
| Environment   |aws|
| Runner        |host|
| Instance type |c7i.metal-24xl|
| Architecture  |x86_64
| CPU           |48 cores|
| RAM           |188 GB|
| Kernel        |6.1.66-93.164.amzn2023.x86_64|
| OS            |Amazon Linux 2023|
| GCC           |11.4.1|
| Time          |2024-01-15 15:10:00|

### Laravel demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|1.05038|1.05631|0.00162|1.05262|0.00%|1.05263|0.00%|38.83 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|1.04086|1.04612|0.00153|1.04295|-0.92%|1.04248|-0.96%|39.48 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|1.03995|1.04656|0.00173|1.04209|-1.00%|1.04180|-1.03%|38.69 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|1.07512|1.08024|0.00137|1.07752|2.37%|1.07714|2.33%|39.74 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|1.06699|1.08293|0.00484|1.07089|1.74%|1.06873|1.53%|47.91 MB|

### Symfony demo app - 25 consecutive runs, 250 requests (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|0.49150|0.49439|0.00087|0.49305|0.00%|0.49305|0.00%|32.70 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|0.48767|0.49135|0.00086|0.48893|-0.84%|0.48869|-0.88%|32.91 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|0.48687|0.49314|0.00134|0.48866|-0.89%|0.48840|-0.94%|33.01 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.49023|0.55270|0.01190|0.49450|0.29%|0.49213|-0.19%|33.27 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.51638|0.52088|0.00112|0.51877|5.22%|0.51829|5.12%|39.37 MB|

### bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|0.21582|0.21835|0.00062|0.21690|0.00%|0.21687|0.00%|25.22 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|0.21340|0.21677|0.00094|0.21441|-1.15%|0.21400|-1.33%|24.90 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|0.21395|0.21705|0.00081|0.21476|-0.99%|0.21450|-1.09%|24.96 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.21454|0.21824|0.00101|0.21573|-0.54%|0.21533|-0.71%|25.39 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.07481|0.07785|0.00093|0.07646|-64.75%|0.07656|-64.70%|26.23 MB|

### micro_bench.php - 15 consecutive runs (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|
|[PHP 8.1](https://github.com/php/php-src/commit/8f6610ce8871c1065682db84264fd3450a5db342)|1.35184|1.37328|0.00476|1.36499|0.00%|1.36609|0.00%|19.11 MB|
|[PHP 8.2](https://github.com/php/php-src/commit/5e2a586c9ae7e6be77b130de443c0a18a2ff4a00)|1.36918|1.39409|0.00661|1.37685|0.87%|1.37488|0.64%|19.26 MB|
|[PHP 8.3](https://github.com/php/php-src/commit/719c74e91976415b8a9b9e49ba12211153a32f9e)|1.41226|1.43175|0.00531|1.41947|3.99%|1.41973|3.93%|19.35 MB|
|[PHP 8.4](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|1.30611|1.32066|0.00379|1.31396|-3.74%|1.31429|-3.79%|19.76 MB|
|[PHP 8.4 (JIT)](https://github.com/php/php-src/commit/ad9ec2607ae9c31c307ed55cbe9c0d9f3be97905)|0.61768|0.63521|0.00486|0.62709|-54.06%|0.62725|-54.08%|20.74 MB|
