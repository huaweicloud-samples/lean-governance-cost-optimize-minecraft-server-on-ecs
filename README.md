# lean-governance-cost-optimize-minecraft-server-on-ecs

[![Status](https://img.shields.io/badge/Status-Incubating-blue)]()
[![Huawei Cloud](https://img.shields.io/badge/Huawei%20Cloud-Samples-red)]()
[![Scenario](https://img.shields.io/badge/Scenario-lean%20governance-success)](https://3ms.huawei.com/docs/docinfo/1300901382590492672?bookstackId=866760814559879168&gid=3591759&l=zh-cn&documentkind=&attachmentIdx=5)

This practice deploys a Minecraft Java Edition server on a Huawei Cloud Elastic Cloud Server (ECS). On first boot the instance automatically installs the Java runtime, verifies the server jar, and registers systemd units. During operation a monitor service tracks connections on the game port; after the last player disconnects and the idle timer expires, the world is saved and the instance shuts down gracefully. Power the instance back on from the console whenever you want to play again. It targets game-server operators, DevOps engineers, and individual server owners as a reference architecture for game servers that start and stop with player activity.

## Overview

This repository is created from the huaweicloud-samples automated repository request workflow.

## Getting Started

Add setup, deployment, and verification steps here.

## Contributing

Please use pull requests and follow the repository review rules.

## License

This project is licensed under the MIT-0 license.

## Maintainers

CODEOWNERS: @Ferguson2211

## Feedback

Please use GitHub Issues: https://github.com/huaweicloud-samples/lean-governance-cost-optimize-minecraft-server-on-ecs/issues
