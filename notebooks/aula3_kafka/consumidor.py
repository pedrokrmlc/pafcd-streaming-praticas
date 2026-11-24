"""Consumidor de linha de comando para o Lab 3 (grupos de consumidores).

Abra 2 ou 3 terminais no Jupyter e rode em cada um, a partir da pasta notebooks:
    python aula3_kafka/consumidor.py --grupo analise
Depois mate um deles (Ctrl+C) e veja o rebalanceamento nos outros.
"""
import argparse
import os
import signal
import time

from confluent_kafka import Consumer, KafkaError

ap = argparse.ArgumentParser()
ap.add_argument("--topico", default="aula3-pedidos")
ap.add_argument("--grupo", default="analise")
ap.add_argument("--inicio", default="earliest", choices=["earliest", "latest"])
ap.add_argument("--lento", type=float, default=0.0, help="segundos de 'processamento' por mensagem")
a = ap.parse_args()

nome = f"consumidor-{os.getpid()}"
c = Consumer({
    "bootstrap.servers": os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092"),
    "group.id": a.grupo,
    "client.id": nome,
    "auto.offset.reset": a.inicio,
    "enable.auto.commit": True,
    "partition.assignment.strategy": "cooperative-sticky",
})


def ao_receber(consumer, particoes):
    print(f"[{nome}] + recebi partições {sorted(p.partition for p in particoes)}", flush=True)


def ao_perder(consumer, particoes):
    print(f"[{nome}] - perdi partições {sorted(p.partition for p in particoes)}", flush=True)


c.subscribe([a.topico], on_assign=ao_receber, on_revoke=ao_perder)

rodando = True
signal.signal(signal.SIGINT, lambda *_: globals().update(rodando=False))
print(f"[{nome}] grupo={a.grupo} tópico={a.topico}. Ctrl+C para sair.", flush=True)

lidas = 0
while rodando:
    msg = c.poll(1.0)
    if msg is None:
        continue
    if msg.error():
        if msg.error().code() != KafkaError._PARTITION_EOF:
            print("erro:", msg.error())
        continue
    lidas += 1
    chave = msg.key().decode() if msg.key() else None
    print(f"[{nome}] p{msg.partition()} off={msg.offset():<6} chave={chave} valor={msg.value()[:60]!r}", flush=True)
    if a.lento:
        time.sleep(a.lento)

c.close()   # sai do grupo de forma limpa (dispara rebalanceamento imediato)
print(f"[{nome}] saiu após ler {lidas} mensagens")
