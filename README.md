# PHP Version Benchmark

[![Software License][ico-license]](LICENSE)

## Table of Contents

* [Introduction](#introduction)
* [Results](#results)
* [Install](#install)
* [Usage](#usage)
* [Contributing](#contributing)
* [Support](#support)
* [Credits](#credits)
* [License](#license)

## Introduction

This is a fully automated benchmark suite for comparing the performance of any PHP releases or branches.
The framework is heavily inspired by Intel's work from quite a few years ago: [https://01.org/node/3774](https://web.archive.org/web/20210614053522/https://01.org/node/3774).

## Results

You can find the [benchmark results here](https://github.com/kocsismate/php-version-benchmarks/tree/main/docs/results).

## Install

You can simply download or clone this repository. You can also install it via [Composer](https://getcomposer.org) by
running the command below:

```bash
$ composer require kocsismate/php-version-benchmarks:dev-main
```

## Usage

### Configuration

All the configuration of the benchmark is done via `.ini` files in the `config` directory. By default, a few templates
are bundled with the benchmark (having `.ini.dist` extension in their names). Feel free to rename them by removing the
`.dist` suffix in order to take advantage of them.

#### Infrastructure

| Option                             | Description                                                                                                                                                                            |
|------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| INFRA_ID                           | The ID of the infrastructure configuration to be used in the code.                                                                                                                     |
| INFRA_NAME                         | The name of the infrastructure configuration which is displayed in the benchmark results.                                                                                              |
| INFRA_INSTANCE_TYPE                | The AWS EC2 instance type.                                                                                                                                                             |
| INFRA_ARCHITECTURE                 | Any supported CPU architecture code ("x86_64", "amd64", "arm64").                                                                                                                      |
| INFRA_DEDICATED_INSTANCE           | Whether the [dedicated instance](https://aws.amazon.com/ec2/pricing/dedicated-instances/) feature is enabled ("0" or "1")                                                              |
| INFRA_DISABLE_DEEPER_C_STATES      | Whether [deeper CPU C-states](https://docs.aws.amazon.com/linux/al2/ug/processor_state_control.html) are disabled  ("0" or "1").                                                       |
| INFRA_DISABLE_TURBO_BOOST          | Whether turbo boost is disabled ("0" or "1").                                                                                                                                          |
| INFRA_DISABLE_HYPER_THREADING      | Whether hyper threading is disabled ("0" or "1").                                                                                                                                      |
| INFRA_LOCK_CPU_FREQUENCY           | Whether CPU frequency is locked to the base frequency ("0" or "1").                                                                                                                    |
| INFRA_MAX_ALLOWED_CPU_TEMP         | Maximum allowed CPU temperature in °C before running a test.                                                                                                                           |
| INFRA_PHP_ALIGNMENT_VARIATIONS     | A list of alignment variations separated by space (e.g. "8 16 32"). Zero means no variation. Each PHP version is compiled against each alignment variation.                            |
| INFRA_PHP_LINKING_ORDER_VARIATIONS | Linking order variation count. Zero means linking order uses the default settings.                                                                                                     |
| INFRA_WORKSPACE                    | A unique identifier to use when the same AWS account is reused across different benchmarking environments.                                                                             |
| INFRA_RUNNER                       | Deprecated option. Only host runner is supported.                                                                                                                                      |
| INFRA_COLLECT_EXTENDED_PERF_STATS  | Whether to collect extended perf stat events (`LLC-loads`, `LLC-load-misses`, `LLC-stores`, `LLC-store-misses`, `iTLB-load-misses`, `dTLB-load-misses`). Supported values: "0" or "1". |
| INFRA_DEBUG_ENVIRONMENT            | Whether to collect the environment state for debugging purposes. Supported values: "0" or "1".                                                                                         |

### Usage on AWS EC2

As a prerequisite, you need the following:

- a UNIX system (Linux, Mac)
- git
- [Terraform](https://www.terraform.io)

Then you have to create the necessary AWS-related config file by copying the `aws.tfvars.dist` to `aws.tfvars` in the
`build/infrastructure/config/aws.tfvars.dist` directory:

```bash
cp build/infrastructure/config/aws.tfvars.dist build/infrastructure/config/aws.tfvars
```

Then, you need to override some values in it:

- `access_key`: the access key of your AWS account
- `secret_key`: the secret access key of your AWS account
- `region`: it is "eu-central-1" by default, but you should choose the closest one to your area
- `state_bucket`: The S3 bucket name where the state file is stored

Now, you are ready to go:

```bash
./benchmark.sh run aws
```

## Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md) for details.

## Support

Please see [SUPPORT](SUPPORT.md) for details.

## Credits

- [Máté Kocsis][link-author]
- [All Contributors][link-contributors]

## License

The MIT License (MIT). Please see the [License File](LICENSE) for more information.

[ico-license]: https://img.shields.io/badge/license-MIT-brightgreen.svg

[link-author]: https://github.com/kocsismate
[link-contributors]: ../../contributors
