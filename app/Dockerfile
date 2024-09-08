FROM php:8.2-cli

COPY --from=composer:2.7.9 /usr/bin/composer /usr/bin/composer

RUN apt-get update && apt-get install -y unzip

RUN mkdir -p /.composer && \
    chmod -R 777 /.composer
