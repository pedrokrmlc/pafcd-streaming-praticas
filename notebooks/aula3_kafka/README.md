# Aula 3 · Apache Kafka: roteiro da parte prática (~1h45)

**Pré-requisito:** ambiente criado e no ar (veja `docs/primeiros_passos.md`).
Crie o ambiente **antes da aula**: a primeira montagem leva de 10 a 15 minutos.

| Tempo | Lab | O que o aluno vê na prática |
|---|---|---|
| 10 min | Checagem do ambiente | Jupyter, Kafka UI e os 3 brokers funcionando |
| 25 min | `01_topicos_e_particoes` | tópico = partições × réplicas, líderes e ISR, CLI × código |
| 30 min | `02_produtor` | chave → partição → ordem; `acks`; latência × throughput (`linger.ms`) |
| 30 min | `03_consumidores_e_offsets` | grupos, rebalanceamento, lag, replay por offset e por horário |
| 10 min | `04_replicacao_e_falhas` | derrubar brokers, eleição de líder, `min.insync.replicas` |

O Lab 4 dá para fazer como **demonstração do professor** se o tempo apertar: só uma pessoa precisa derrubar os brokers.

## Checagem do ambiente (10 min)

1. No Cloud Shell: `bash infra/ligar.sh` (se a VM estiver desligada) e `bash infra/status.sh`.
2. Abra o Jupyter (porta 8888) e, num **terminal** (File → New → Terminal), rode:
   ```bash
   kafka-broker-api-versions.sh --bootstrap-server kafka1:9092 | grep -c "id:"   # deve mostrar 3
   ```
3. Abra a Kafka UI (porta 8080, usuário `aluno`, senha = token) e confira os 3 brokers.

## Durante a aula

- Os notebooks ficam em `aula3_kafka/`. Execute célula a célula (Shift+Enter) e leia o markdown entre elas.
- O **gerador de eventos da loja** (usado no exercício 3 do Lab 3 e nas próximas aulas) roda num terminal:
  ```bash
  python -m comum.gerador --taxa 20
  ```
  Ele publica nos tópicos `cliques`, `pedidos`, `pagamentos` e `logins`. Veja `python -m comum.gerador --help`.
- O script `consumidor.py` é para abrir em vários terminais ao mesmo tempo (Lab 3).

## Ao final

```bash
bash infra/desligar.sh     # no Cloud Shell: para de cobrar CPU/RAM
```

## Comandos de CLI mais usados

```bash
kafka-topics.sh          --bootstrap-server kafka1:9092 --list
kafka-topics.sh          --bootstrap-server kafka1:9092 --describe --topic pedidos
kafka-console-consumer.sh --bootstrap-server kafka1:9092 --topic pedidos --from-beginning --max-messages 5 --property print.key=true
kafka-console-producer.sh --bootstrap-server kafka1:9092 --topic aula3-pedidos --property parse.key=true --property key.separator=:
kafka-consumer-groups.sh  --bootstrap-server kafka1:9092 --list
kafka-consumer-groups.sh  --bootstrap-server kafka1:9092 --describe --group analise
```
