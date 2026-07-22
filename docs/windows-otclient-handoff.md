# Retomada do OTClient no Windows

Este guia prepara a continuação da feature do OTClient em uma máquina Windows. A feature está pausada: o primeiro trabalho nessa máquina será revisar e aprovar a especificação para o build nativo antes de alterar código ou gerar o cliente.

## Limites já decididos

- O cliente final será Windows x64.
- O build será nativo no Windows, usando o fluxo MSVC/vcpkg mantido pelo fork.
- Nenhuma dependência do projeto será instalada diretamente no macOS.
- O artefato pronto será levado ao macOS e permanecerá instalado no bottle `Steam` do CrossOver para uso posterior.
- A criação da conta/personagem e a primeira conexão com a VPS continuam no escopo, mas ainda não devem ser executadas.

## 1. Clonar o projeto completo

Abra o PowerShell no diretório em que deseja manter o projeto:

```powershell
git clone --recurse-submodules https://github.com/RonaldoAntonucci/otserv.git
Set-Location otserv
git submodule status
```

As revisões esperadas dos submódulos neste handoff são:

- `server`: `098641981400f8ff89959f427f0e8718d9dd22e2`
- `client`: `99d43bd6559841ee684e35082da3ea9a360d0e16`

Se o repositório já estiver clonado:

```powershell
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
```

## 2. Pré-requisitos que serão validados

O próprio fork documenta atualmente:

- Windows 11 como sistema suportado para compilação;
- Git for Windows;
- Visual Studio 2026 com o workload **Desktop development with C++**, componentes MSVC x64/x86, CMake para Windows, SDK do Windows 11 e language pack em inglês;
- CMake 3.24 ou superior e Ninja, fornecidos pelo ambiente do Visual Studio;
- vcpkg fora do Visual Studio, fixado no baseline `f3e10653cc27d62a37a3763cd84b38bca07c6075` do `client/vcpkg.json`;
- variável `VCPKG_ROOT` apontando para essa instalação do vcpkg.

Não instale antecipadamente um toolchain diferente. Na retomada, primeiro confirmaremos a versão do Windows e confrontaremos os pré-requisitos com `client/docs/building/windows-(cmake).md`, `client/CMakePresets.json` e a CI do fork.

## 3. Caminho técnico de referência

O fork já possui o preset CMake `windows-release`, com Ninja, MSVC `v145`, target `x64-windows-static-release` e dependências em modo manifest. A CI usa o equivalente a:

```powershell
Set-Location client
cmake --preset windows-release -DTOGGLE_BIN_FOLDER=ON -DOPTIONS_ENABLE_IPO=OFF -DOTCLIENT_BUILD_TESTS=OFF
cmake --build --preset windows-release
```

Esse comando é referência para a revisão da especificação, não uma autorização para iniciar a build antes dela ser atualizada. A saída esperada pelo fluxo atual da CI fica em `client/build/windows-release/bin/`.

## 4. Retomar com o Codex

Abra o diretório raiz `otserv` no Codex e solicite:

> Leia `.specs/STATE.md` e continue a feature pausada do OTClient na fase Specify. Estamos na máquina Windows; revise a especificação para usar o build nativo MSVC/vcpkg, sem instalar dependências no macOS.

A ordem de retomada é:

1. auditar a máquina Windows sem modificar o ambiente;
2. revisar e reaprovar `spec.md` para o build nativo;
3. produzir o Design e as tarefas atômicas;
4. instalar os pré-requisitos aprovados e compilar;
5. empacotar e transferir o artefato ao macOS;
6. instalar persistentemente no CrossOver e validar a conexão com a VPS.
