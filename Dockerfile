FROM composer as composer

COPY . /var/www/

RUN cd /var/www \
      && composer config -g repo.packagist composer https://packagist.laravel-china.org \
      && composer install \
           --ignore-platform-reqs \
           --no-interaction \
           --prefer-dist

FROM php:7.2-fpm-alpine as project

USER root

RUN apk --no-cache add shadow && \
         usermod -u 1000 www-data && \
         groupmod -g 1000 www-data

COPY --from=composer /var/www /var/www

RUN docker-php-ext-install pdo_mysql

RUN chown -R www-data:www-data /var/www

CMD php /var/www/artisan migrate --force