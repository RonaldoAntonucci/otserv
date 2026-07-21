# Bootstrap Open Tibia Server Context

**Gathered:** 2026-07-21
**Spec:** `.specs/features/bootstrap-open-tibia-server/spec.md`
**Status:** Ready for design

---

## Feature Boundary

Esta feature cria a base GitHub, compila e executa TFS 1.6 por Docker no macOS e nativamente no Ubuntu da VPS, inicializa MariaDB em cada modelo e valida o datapack oficial. A compilação/distribuição do OTClient e a adoção de um datapack completo ficam para features seguintes.

---

## Implementation Decisions

### Compatibilidade

- TFS `v1.6`, protocolo 13.10.
- O fork do OTClient deve manter uma revisão com compatibilidade declarada para essa baseline.

### Ambientes

- Desenvolvimento em macOS sempre por Docker.
- Produção na VPS Hostinger `1826871`, Ubuntu 24.04 LTS, 1 vCPU, 4 GB de RAM e 50 GB de disco.
- Na VPS, TFS e MariaDB devem rodar nativamente, com TFS gerenciado pelo `systemd`.
- O build e runtime devem ser adequados a `linux/amd64` e ao limite de 1 vCPU.

### Dados

- MariaDB em container com volume persistente no desenvolvimento e instalação nativa na VPS.
- Ambos os ambientes usam o schema oficial do TFS e inicialização idempotente.
- Primeiro boot usa o datapack oficial incluído no TFS.
- Avaliação de datapack completo ocorrerá somente após o smoke test da baseline.

### Repositórios

- Conta GitHub autenticada: `RonaldoAntonucci`.
- Estrutura confirmada: `otserv` como repositório de orquestração, acompanhado dos forks verdadeiros `forgottenserver` e `otclient`.
- Os três repositórios serão públicos.

### Agent's Discretion

- Nomes internos de imagens, redes e volumes Docker.
- Scripts de healthcheck e smoke test, desde que comprovem os critérios da spec.
- Organização de documentação, unidade `systemd` e instalador nativo dentro do repositório `otserv`.

### Declined / Undiscussed Gray Areas → Assumptions

- As portas públicas do TFS serão abertas somente na etapa de deploy, depois de confirmar regras existentes do firewall.
- O MCP da Hostinger não oferece terminal; a execução do instalador nativo exigirá uma sessão SSH separada ou execução manual pelo usuário.

---

## Specific References

- Server upstream: `https://github.com/otland/forgottenserver`
- Client upstream: `https://github.com/opentibiabr/otclient`
- GitHub owner: `https://github.com/RonaldoAntonucci`

---

## Deferred Ideas

- Datapack completo/global e definição do mundo final.
- Build e distribuição do cliente para Windows/macOS.
- Website, domínio, TLS, updater e criação pública de contas.
- Backup automatizado, monitoramento e hardening de produção.
