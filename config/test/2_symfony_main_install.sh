#!/usr/bin/env bash
set -e

symfony_version="2.8.0" # https://github.com/symfony/demo/releases
symfony_dir="$PROJECT_ROOT/app/symfony"
symfony_tmp_dir="$PROJECT_ROOT/tmp/app/symfony"

if [[ -d "$symfony_dir" ]]; then
    echo "Symfony is already installed"
    exit
fi

mkdir -p "$symfony_dir"
mkdir -p "$symfony_tmp_dir"

sudo docker run --rm \
    --volume $PROJECT_ROOT:/code \
    --user $(id -u):$(id -g) \
    setup bash -c "\
        set -e
        export APP_ENV=prod
        export APP_DEBUG=false
        export APP_SECRET=random
        [[ -n '$GITHUB_TOKEN' ]] && composer config --global github-oauth.github.com '$GITHUB_TOKEN'; \
        composer create-project symfony/symfony-demo symfony $symfony_version --no-interaction --working-dir=/code/app && \
        composer update symfony/config:7.3.6 symfony/dependency-injection:7.3.9 symfony/event-dispatcher:7.3.3 doctrine/persistence:3.4.3 doctrine/orm:3.6.0 doctrine/doctrine-bundle:2.18.2 --working-dir=/code/app/symfony && \
        composer config platform-check false --working-dir=/code/app/symfony && \
        composer dump-autoload --classmap-authoritative --working-dir=/code/app/symfony"

sed -i "/trigger_deprecation('symfony\/var-exporter', '7.3', 'Using ProxyHelper::generateLazyGhost() is deprecated, use native lazy objects instead.');/d" "$symfony_dir/vendor/symfony/var-exporter/ProxyHelper.php"
sed -i "/trigger_deprecation('symfony\/var-exporter', '7.3', 'The \"%s\" trait is deprecated, use native lazy objects instead.', LazyProxyTrait::class);/d" "$symfony_dir/vendor/symfony/var-exporter/LazyProxyTrait.php"
sed -i "/trigger_deprecation('symfony\/var-exporter', '7.3', 'The \"%s\" trait is deprecated, use native lazy objects instead.', LazyGhostTrait::class);/d" "$symfony_dir/vendor/symfony/var-exporter/LazyGhostTrait.php"

sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$symfony_dir/vendor/doctrine/orm/src/Configuration.php"
sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$symfony_dir/vendor/doctrine/orm/src/Proxy/Autoloader.php"
sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$symfony_dir/vendor/doctrine/orm/src/Proxy/DefaultProxyClassNameResolver.php"
sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$symfony_dir/vendor/doctrine/orm/src/Proxy/ProxyFactory.php"

sudo chmod -R 777 "$symfony_dir/var"
