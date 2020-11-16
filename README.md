# RabbitMQ Web STOMP plugin

This plugin provides support for STOMP-over-WebSockets to RabbitMQ.

## This was migrated to https://github.com/rabbitmq/rabbitmq-server

This repository has been moved to the main unified RabbitMQ "monorepo", including all open issues. You can find the source under [/deps/rabbitmq_web_stomp](https://github.com/rabbitmq/rabbitmq-server/tree/master/deps/rabbitmq_web_stomp).
All issues have been transferred.

## Installation

This plugin ships with modern versions of RabbitMQ.
Like all plugins, it [must be enabled](https://www.rabbitmq.com/plugins.html) before it can be used:

``` bash
# this might require sudo
rabbitmq-plugins enable rabbitmq_web_stomp
```

## Documentation

Please refer to the [RabbitMQ Web STOMP guide](https://www.rabbitmq.com/web-stomp.html).

## Building from Source

See [Plugin Development guide](https://www.rabbitmq.com/plugin-development.html).

TL;DR: running

    make dist

will build the plugin and put build artifacts under the `./plugins` directory.


## Copyright and License

(c) 2007-2020 VMware, Inc. or its affiliates.

Released under the MPL, the same license as RabbitMQ.
