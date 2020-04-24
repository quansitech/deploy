FROM composer as composer

COPY . /var/www/项目名

RUN cd /var/www/项目名 \
      && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer \
      && composer install \
           --ignore-platform-reqs \
           --no-interaction \
           --prefer-dist \
           --no-dev

FROM php:7.2-fpm-alpine as project

USER root

RUN apk --no-cache add shadow && \
         usermod -u 1000 www-data && \
         groupmod -g 1000 www-data

COPY --from=composer /var/www/项目名 /var/www/项目名

RUN docker-php-ext-install pdo_mysql

RUN chown -R www-data:www-data /var/www/项目名
