# OTServ

Base reproduzível para um Open Tibia Server com [The Forgotten Server 1.6](https://github.com/RonaldoAntonucci/forgottenserver) e [OTClient 4.1](https://github.com/RonaldoAntonucci/otclient), ambos mantidos como forks independentes.

O desenvolvimento no macOS usa somente Docker: nenhuma dependência de compilação ou runtime do projeto é instalada no host. A VPS Ubuntu executa MariaDB e TFS como serviços nativos, sem Docker.

## Repositórios e revisões

| Componente | Repositório | Revisão fixada |
| --- | --- | --- |
| Orquestração | `RonaldoAntonucci/otserv` | branch `main` |
| Servidor | `RonaldoAntonucci/forgottenserver` | TFS `v1.6` — `098641981400f8ff89959f427f0e8718d9dd22e2` |
| Cliente | `RonaldoAntonucci/otclient` | OTClient `4.1` — `99d43bd6559841ee684e35082da3ea9a360d0e16` |

## Clone completo

```sh
git clone --recurse-submodules https://github.com/RonaldoAntonucci/otserv.git
cd otserv
git submodule status
```

Se o clone já existir:

```sh
git submodule sync --recursive
git submodule update --init --recursive
```

## Gates

```sh
make test-static  # 70 contratos, executados em Docker
make test-dev     # 24 integrações, executadas em Docker
make verify       # gate local completo: 94 verificações
sudo make test-vps  # somente na VPS nativa: 14 verificações
```

## Guias

- [Desenvolvimento Docker no macOS](docs/development.md)
- [Instalação e operação nativa da VPS](docs/vps.md)
- [Evidência sanitizada da VPS](docs/vps-validation.md)

O bootstrap usa o datapack oficial incluído no TFS para validar infraestrutura. Compilar/distribuir o OTClient e escolher um datapack definitivo são as próximas features, não parte desta baseline.

Requisitos, decisões e rastreabilidade estão em [`.specs/features/bootstrap-open-tibia-server`](.specs/features/bootstrap-open-tibia-server).
