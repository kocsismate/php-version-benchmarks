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
$ composer require kocsismate/php-version-benchmarks:dev-master
```

## Usage

### Configuration

All the configuration of the benchmark is done via `.ini` files in the `config` directory. By default, a few templates
are bundled with the benchmark (having `.ini.dist` extension in their names). Feel free to rename them by removing the
`.dist` suffix in order to take advantage of them.

### Usage with Docker

As a prerequisite, you need the following:

- a UNIX system (Linux, Mac)
- git
- a recent version of Docker

Run the following command to execute the benchmark suite locally:

```bash
./benchmark.sh run local
```

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
