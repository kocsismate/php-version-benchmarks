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

| Option                             | Description                                                                                  | Supported values                                                                       |
|------------------------------------|----------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| INFRA_ID                           | The ID of the infrastructure configuration to be used in the benchmark code                  | String                                                                                 |
| INFRA_NAME                         | The name of the infrastructure configuration which is displayed in the benchmark results     | String                                                                                 |
| INFRA_INSTANCE_TYPE                | The AWS EC2 instance type                                                                    | A valid AWS EC2 instance type (e.g. t2.micro)                                          |
| INFRA_ARCHITECTURE                 | Any supported CPU architecture code                                                          | One of the following: "x86_64", "amd64", "arm64"                                       |
| INFRA_DEDICATED_INSTANCE           | Whether the [dedicated instance](https://aws.amazon.com/ec2/pricing/dedicated-instances/) feature is enabled                                     | Boolean, either "0" or "1"                                                             |
| INFRA_DISABLE_DEEPER_C_STATES      | Whether [deeper CPU C-states](https://docs.aws.amazon.com/linux/al2/ug/processor_state_control.html) are disabled                                              | Boolean, either "0" or "1"                                                             |
| INFRA_DISABLE_TURBO_BOOST          | Whether turbo boost is disabled                                                              | Boolean, either "0" or "1"                                                             |
| INFRA_DISABLE_HYPER_THREADING      | Whether hyper threading is disabled                                                          | Boolean, either "0" or "1"                                                             |
| INFRA_LOCK_CPU_FREQUENCY           | Whether CPU frequency is locked to the base frequency                                        | Boolean, either "0" or "1"                                                             |
| INFRA_CPU_NUMA_NODE                | Which CPU NUMA node to use for running the benchmark                                         | Empty string for single NUMA systems, integer for multi-NUMA systems                   |
| INFRA_MAX_ALLOWED_CPU_TEMP         | Maximum allowed CPU temperature in °C before running a test                                  | Integer value (e.g. "50"). When set to "0", no temperature is enforced.                |
| INFRA_WORKSPACE                    | A unique identifier to use when the same AWS account is reused across different benchmarking environments. | String                                                                   |
| INFRA_RUNNER                       | Deprecated option. Only host runner is supported                                             | One of the following: "host"                                                           |
| INFRA_COLLECT_EXTENDED_PERF_STATS  | Whether to collect extended perf stat events (`LLC-loads`, `LLC-load-misses`, `LLC-stores`, `LLC-store-misses`, `iTLB-load-misses`, `dTLB-load-misses`) | Boolean, either "0" or "1"  |
| INFRA_DEBUG_ENVIRONMENT            | Whether to collect the environment state for debugging purposes                              | Boolean, either "0" or "1"                                                             |

#### PHP

| Option          | Description                                                                 | Supported values                                                 |
|-----------------|-----------------------------------------------------------------------------|------------------------------------------------------------------|
| PHP_ID          | The ID of the PHP version to be used in the benchmark code                  | String                                                           |
| PHP_NAME        | The name of the PHP version which is displayed in the benchmark results     | String                                                           |
| PHP_BASE_ID     | Refers to a `PHP_ID`                                                        | An existing `PHP_ID` value                                       |
| PHP_REPO        | The name of the git repository where the PHP version is available           | An existing git URL containing the PHP source code               |
| PHP_BRANCH      | The branch within the `PHP_REPO` to be benchmarked                          | An existing branch name                                          |
| PHP_COMMIT      | The commit within the `PHP_BRANCH` to be benchmarked                        | An existing long commit SHA, or empty string to use the `HEAD`   |
| PHP_JIT         | Whether to enable tracing JIT                                               | Boolean, either "0" or "1"                                       |

#### Test

| Option          | Description                                                        | Supported values       |
|-----------------|--------------------------------------------------------------------|------------------------|
| TEST_ID         | The ID of the test to be used in the benchmark code                | String                 |
| TEST_NAME       | The name of the test which is displayed in the benchmark results   | String                 |
| TEST_ITERATIONS | The number of times the tests are repeated                         | Integer                |
| TEST_WARMUP     | The number of warmup requests to perform within a test iteration   | Integer                |
| TEST_REQUESTS   | The number of measured requests to perform within a test iteration | Integer                |
| TEST_TYPE       | The type of the benhcmark                                          | One of "real", "micro" |
| TEST_FILE       | The PHP file to execute during the benchmark                       | An existing PHP file   |
| TEST_URL_PATH   | The URL to use for running `real` benchmarks                       | An accessible URL      |
| TEST_ENV        | The `APP_ENV` environment variable to pass to `real` tests         | String                 |

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

## System-level Stability Measures

Getting consistent benchmark results requires careful system-level tuning. The following measures have been applied to
minimize noise and ensure reproducibility:

- Disabling Hyper-Threading, Turbo Boost, and deep C-states prevents the CPU from dynamically changing its
behavior during measurement. Setting the benchmarking CPU to its exact baseline frequency was particularly
impactful for result stability.
- IRQ affinity pinning ensures hardware interrupts are handled only by OS-reserved cores, keeping the benchmarking core
free from interrupt-related jitter. The CPU selection algorithm further prefers the core with the fewest IRQ affinities
within the target NUMA node.
- Maximum CPU scheduling and I/O priority is assigned to the benchmark workload to prevent it from being preempted by
other processes.
- cgroup-based CPU isolation replaced taskset to enable NUMA node-aware process placement, which is necessary
on multi-NUMA instances.
- NVMe instance store is used instead of the default network-backed EBS disk, as network disk latency and variance was
one of the most significant sources of measurement noise.
- Kernel parameters `isolcpus`, `nohz_full`, and `rcu_nocbs` are set to fully isolate the benchmarking cores from the OS
scheduler and kernel housekeeping tasks.
- L3 cache isolation is also supported by the benchmark framework, but it is currently not supported on AWS.
- MySQL stability tuning was applied for WordPress benchmarks, which require a running database, to reduce
query latency variance.
- CPU temperature gating prevents a benchmark run from starting if the CPU temperature exceeds a defined threshold,
eliminating thermal throttling as a source of variance.

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
