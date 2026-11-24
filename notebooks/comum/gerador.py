"""Gerador de eventos da loja fictícia.

Publica quatro tópicos no Kafka:
  cliques     usuário viu uma página/produto              (chave: usuario_id)
  pedidos     usuário comprou um produto                  (chave: usuario_id)
  pagamentos  resultado do pagamento, chega DEPOIS do pedido (chave: pedido_id)
  logins      tentativas de login; às vezes um "ataque" de força bruta (chave: usuario_id)

Também simula problemas reais de streaming:
  --atraso P      fração de eventos que chegam atrasados (o ts_evento é o momento real,
                  mas a mensagem só é publicada de 30 s a --atraso-max s depois)
  --duplicado P   fração de eventos publicados duas vezes (mesmo evento_id)

Uso (terminal do Jupyter, a partir da pasta notebooks):
  python -m comum.gerador --taxa 20 --duracao 600
  python -m comum.gerador --taxa 50 --atraso 0.1 --duplicado 0.05
  python -m comum.gerador --topicos logins --ataque 0.05
"""
from __future__ import annotations

import argparse
import heapq
import itertools
import json
import os
import random
import signal
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone

from comum.catalogo import METODOS_PAGAMENTO, PAGINAS, PRODUTOS, USUARIOS

TOPICOS = ("cliques", "pedidos", "pagamentos", "logins")


def iso(ts: datetime) -> str:
    return ts.isoformat(timespec="milliseconds")


class Gerador:
    def __init__(self, prob_atraso=0.0, atraso_max_s=180, prob_duplicado=0.0,
                 prob_compra=0.15, prob_sem_pagamento=0.08, prob_ataque=0.01,
                 topicos=TOPICOS, seed=None):
        self.r = random.Random(seed)
        self.prob_atraso = prob_atraso
        self.atraso_max_s = max(atraso_max_s, 31)
        self.prob_duplicado = prob_duplicado
        self.prob_compra = prob_compra
        self.prob_sem_pagamento = prob_sem_pagamento
        self.prob_ataque = prob_ataque
        self.topicos = set(topicos)
        self._fila = []                  # (instante_de_publicar, seq, topico, chave, evento)
        self._seq = itertools.count()

    # ---- agenda -------------------------------------------------------------
    def _agendar(self, quando, topico, chave, evento, pode_atrasar=True):
        if topico not in self.topicos:
            return
        if pode_atrasar and self.r.random() < self.prob_atraso:
            quando = quando + timedelta(seconds=self.r.uniform(30, self.atraso_max_s))
        heapq.heappush(self._fila, (quando, next(self._seq), topico, chave, evento))
        if self.r.random() < self.prob_duplicado:
            heapq.heappush(self._fila, (quando + timedelta(milliseconds=self.r.randint(10, 3000)),
                                        next(self._seq), topico, chave, evento))

    def _prontos(self, agora):
        while self._fila and self._fila[0][0] <= agora:
            _, _, topico, chave, evento = heapq.heappop(self._fila)
            yield topico, chave, evento

    # ---- eventos ------------------------------------------------------------
    def passo(self, agora: datetime):
        """Gera os eventos de um 'tique' e devolve os que já devem ser publicados."""
        usuario_id, cidade = self.r.choice(USUARIOS)
        produto_id, _, _, preco = self.r.choice(PRODUTOS)

        self._agendar(agora, "cliques", usuario_id, {
            "evento_id": uuid.uuid4().hex[:12], "usuario_id": usuario_id, "produto_id": produto_id,
            "pagina": self.r.choice(PAGINAS), "cidade": cidade, "ts_evento": iso(agora)})

        if self.r.random() < self.prob_compra:
            pedido_id = "o" + uuid.uuid4().hex[:10]
            qtd = self.r.choices([1, 2, 3], weights=[70, 22, 8])[0]
            valor = round(preco * qtd, 2)
            self._agendar(agora, "pedidos", usuario_id, {
                "evento_id": uuid.uuid4().hex[:12], "pedido_id": pedido_id, "usuario_id": usuario_id,
                "produto_id": produto_id, "quantidade": qtd, "valor": valor, "cidade": cidade,
                "ts_evento": iso(agora)})
            if self.r.random() >= self.prob_sem_pagamento:
                quando = agora + timedelta(seconds=self.r.uniform(2, 60))
                self._agendar(quando, "pagamentos", pedido_id, {
                    "evento_id": uuid.uuid4().hex[:12], "pedido_id": pedido_id,
                    "metodo": self.r.choice(METODOS_PAGAMENTO), "valor": valor,
                    "status": "aprovado" if self.r.random() < 0.92 else "recusado",
                    "ts_evento": iso(quando)})

        if self.r.random() < 0.3:
            ok = self.r.random() < 0.95
            self._agendar(agora, "logins", usuario_id, self._login(usuario_id, ok, agora, "BR"))

        if self.r.random() < self.prob_ataque:
            # força bruta: várias falhas em poucos segundos e depois um sucesso
            alvo, _ = self.r.choice(USUARIOS)
            t = agora
            for _ in range(self.r.randint(3, 6)):
                t += timedelta(seconds=self.r.uniform(1, 8))
                self._agendar(t, "logins", alvo, self._login(alvo, False, t, "XX"), pode_atrasar=False)
            t += timedelta(seconds=self.r.uniform(1, 10))
            self._agendar(t, "logins", alvo, self._login(alvo, True, t, "XX"), pode_atrasar=False)

        return list(self._prontos(agora))

    def _login(self, usuario_id, sucesso, ts, pais):
        return {"evento_id": uuid.uuid4().hex[:12], "usuario_id": usuario_id, "sucesso": sucesso,
                "pais_ip": pais, "ts_evento": iso(ts)}


# ---- saídas -------------------------------------------------------------------
class SaidaKafka:
    def __init__(self, bootstrap):
        from confluent_kafka import Producer
        self.p = Producer({"bootstrap.servers": bootstrap, "acks": "all",
                           "enable.idempotence": True, "linger.ms": 20})

    def enviar(self, topico, chave, evento):
        while True:
            try:
                self.p.produce(topico, key=chave, value=json.dumps(evento, ensure_ascii=False))
                break
            except BufferError:
                self.p.poll(0.5)
        self.p.poll(0)

    def fechar(self):
        self.p.flush(10)


class SaidaArquivo:
    """Grava JSON Lines em <dir>/<topico>/ (útil para testar sem Kafka)."""
    def __init__(self, diretorio):
        self.dir = diretorio
        self.buf = {}

    def enviar(self, topico, chave, evento):
        self.buf.setdefault(topico, []).append(json.dumps(evento, ensure_ascii=False))

    def descarregar(self):
        for topico, linhas in self.buf.items():
            os.makedirs(os.path.join(self.dir, topico), exist_ok=True)
            nome = os.path.join(self.dir, topico, f"{time.time_ns()}.json")
            with open(nome + ".tmp", "w") as f:
                f.write("\n".join(linhas) + "\n")
            os.rename(nome + ".tmp", nome)
        self.buf = {}

    def fechar(self):
        self.descarregar()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--taxa", type=float, default=10, help="cliques por segundo (default 10)")
    ap.add_argument("--duracao", type=float, default=0, help="segundos; 0 = até Ctrl+C")
    ap.add_argument("--atraso", type=float, default=0.0, help="fração de eventos atrasados (0-1)")
    ap.add_argument("--atraso-max", type=float, default=180, help="atraso máximo em segundos")
    ap.add_argument("--duplicado", type=float, default=0.0, help="fração de eventos duplicados (0-1)")
    ap.add_argument("--ataque", type=float, default=0.01, help="probabilidade de ataque de login por tique")
    ap.add_argument("--topicos", default=",".join(TOPICOS))
    ap.add_argument("--saida", choices=["kafka", "arquivo"], default="kafka")
    ap.add_argument("--dir", default=os.path.expanduser("~/dados/eventos"))
    ap.add_argument("--seed", type=int)
    a = ap.parse_args(argv)

    g = Gerador(prob_atraso=a.atraso, atraso_max_s=a.atraso_max, prob_duplicado=a.duplicado,
                prob_ataque=a.ataque, topicos=a.topicos.split(","), seed=a.seed)
    saida = SaidaKafka(os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")) if a.saida == "kafka" \
        else SaidaArquivo(a.dir)

    parar = False
    def _sinal(*_):
        nonlocal parar
        parar = True
    signal.signal(signal.SIGINT, _sinal)
    signal.signal(signal.SIGTERM, _sinal)

    inicio = time.time()
    intervalo = 1.0 / a.taxa
    total = {t: 0 for t in TOPICOS}
    ultimo_log = ultimo_flush = inicio
    print(f"Gerando ~{a.taxa:g} cliques/s em {a.topicos} -> {a.saida}. Ctrl+C para parar.", flush=True)
    while not parar and (a.duracao <= 0 or time.time() - inicio < a.duracao):
        agora = datetime.now(timezone.utc)
        for topico, chave, evento in g.passo(agora):
            saida.enviar(topico, chave, evento)
            total[topico] += 1
        if isinstance(saida, SaidaArquivo) and time.time() - ultimo_flush >= 1:
            ultimo_flush = time.time()
            saida.descarregar()
        if time.time() - ultimo_log >= 10:
            ultimo_log = time.time()
            print(time.strftime("%H:%M:%S"), " ".join(f"{t}={n}" for t, n in total.items()), flush=True)
        time.sleep(intervalo)
    saida.fechar()
    print("Fim.", total, flush=True)


if __name__ == "__main__":
    sys.exit(main())
