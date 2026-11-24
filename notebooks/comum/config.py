"""Configurações e atalhos usados pelos notebooks."""
from __future__ import annotations

import os

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (BooleanType, DoubleType, IntegerType, StringType,
                               StructField, StructType, TimestampType)

BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")
DADOS = os.path.expanduser("~/dados")
PACOTE_KAFKA = "org.apache.spark:spark-sql-kafka-0-10_2.13:4.0.1"

# Só para testes sem Kafka: STREAMING_FONTE=arquivo lê JSON Lines de ~/dados/eventos/<topico>/
FONTE = os.environ.get("STREAMING_FONTE", "kafka")

# ---- esquemas dos eventos (o JSON publicado pelo comum/gerador.py) ------------
ESQUEMAS = {
    "cliques": StructType([
        StructField("evento_id", StringType()), StructField("usuario_id", StringType()),
        StructField("produto_id", StringType()), StructField("pagina", StringType()),
        StructField("cidade", StringType()), StructField("ts_evento", TimestampType())]),
    "pedidos": StructType([
        StructField("evento_id", StringType()), StructField("pedido_id", StringType()),
        StructField("usuario_id", StringType()), StructField("produto_id", StringType()),
        StructField("quantidade", IntegerType()), StructField("valor", DoubleType()),
        StructField("cidade", StringType()), StructField("ts_evento", TimestampType())]),
    "pagamentos": StructType([
        StructField("evento_id", StringType()), StructField("pedido_id", StringType()),
        StructField("metodo", StringType()), StructField("valor", DoubleType()),
        StructField("status", StringType()), StructField("ts_evento", TimestampType())]),
    "logins": StructType([
        StructField("evento_id", StringType()), StructField("usuario_id", StringType()),
        StructField("sucesso", BooleanType()), StructField("pais_ip", StringType()),
        StructField("ts_evento", TimestampType())]),
}


def criar_spark(nome: str = "aula") -> SparkSession:
    """SparkSession local (2 núcleos) já com o conector Kafka."""
    os.makedirs(DADOS, exist_ok=True)
    return (SparkSession.builder
            .appName(nome)
            .master("local[2]")
            .config("spark.jars.packages", PACOTE_KAFKA)
            .config("spark.driver.memory", "1500m")
            .config("spark.sql.shuffle.partitions", "4")      # o padrão (200) é exagero aqui
            .config("spark.sql.session.timeZone", "UTC")
            .config("spark.sql.streaming.forceDeleteTempCheckpointLocation", "true")
            .config("spark.ui.showConsoleProgress", "false")
            .getOrCreate())


def ler_topico(spark: SparkSession, topico: str, inicio: str = "latest") -> DataFrame:
    """Stream bruto de um tópico: key, value (string), topic, partition, offset, timestamp."""
    if FONTE == "arquivo":
        return (spark.readStream.text(os.path.join(DADOS, "eventos", topico))
                .select(F.lit(None).cast("string").alias("key"), F.col("value"),
                        F.lit(topico).alias("topic"), F.lit(0).alias("partition"),
                        F.lit(0).cast("long").alias("offset"), F.current_timestamp().alias("timestamp")))
    return (spark.readStream.format("kafka")
            .option("kafka.bootstrap.servers", BOOTSTRAP)
            .option("subscribe", topico)
            .option("startingOffsets", inicio)
            .option("failOnDataLoss", "false")
            .load()
            .select(F.col("key").cast("string"), F.col("value").cast("string"),
                    "topic", "partition", "offset", "timestamp"))


def ler_eventos(spark: SparkSession, topico: str, inicio: str = "latest") -> DataFrame:
    """Stream já convertido do JSON para colunas, mais o timestamp do Kafka (ts_kafka)."""
    bruto = ler_topico(spark, topico, inicio)
    return (bruto
            .select(F.from_json("value", ESQUEMAS[topico]).alias("e"), F.col("timestamp").alias("ts_kafka"))
            .select("e.*", "ts_kafka"))


def produtos_df(spark: SparkSession) -> DataFrame:
    """Tabela estática de produtos (para joins stream-static)."""
    from comum.catalogo import PRODUTOS
    return spark.createDataFrame(PRODUTOS, "produto_id string, nome string, categoria string, preco double")


def checkpoint(nome: str) -> str:
    return os.path.join(DADOS, "checkpoints", nome)


def parar_tudo(spark: SparkSession) -> None:
    """Para todas as queries de streaming ativas na sessão."""
    for q in spark.streams.active:
        print("parando", q.name or q.id)
        q.stop()


def mostrar(spark: SparkSession, tabela: str, n: int = 20, ordem: str | None = None) -> None:
    """Mostra o conteúdo atual de uma query com sink 'memory'."""
    df = spark.table(tabela)
    if ordem:
        df = df.orderBy(*[c.strip() for c in ordem.split(",")])
    df.show(n, truncate=False)


def criar_topicos(nomes=("cliques", "pedidos", "pagamentos", "logins", "alertas"),
                  particoes: int = 3, replicacao: int = 3) -> None:
    """Cria os tópicos do curso (ignora os que já existem)."""
    from confluent_kafka.admin import AdminClient, NewTopic
    admin = AdminClient({"bootstrap.servers": BOOTSTRAP})
    existentes = set(admin.list_topics(timeout=10).topics)
    novos = [NewTopic(t, num_partitions=particoes, replication_factor=replicacao)
             for t in nomes if t not in existentes]
    for t, fut in admin.create_topics(novos).items() if novos else []:
        fut.result()
        print("criado:", t)
    print("tópicos:", sorted(x for x in admin.list_topics(timeout=10).topics if not x.startswith("__")))


def aguardar(segundos: int, *queries) -> None:
    """Espera alguns micro-batches e imprime o progresso das queries."""
    import time
    time.sleep(segundos)
    for q in queries:
        p = q.lastProgress or {}
        print(f"[{q.name}] batch={p.get('batchId')} entrada={p.get('numInputRows')} linhas "
              f"({p.get('inputRowsPerSecond', 0) or 0:.1f}/s) ativa={q.isActive}")


class TabelaUpsert:
    """Sink de demonstração para o modo 'update': guarda o último valor de cada chave.

    Uso:  t = TabelaUpsert(["janela", "categoria"])
          df.writeStream.outputMode("update").foreachBatch(t.foreach_batch).start()
          t.mostrar()
    """
    def __init__(self, chaves):
        self.chaves = list(chaves)
        self.linhas = {}
        self.batches = 0

    def foreach_batch(self, df, batch_id):
        for r in df.collect():
            d = r.asDict(recursive=True)
            chave = tuple(str(d[c]) for c in self.chaves)
            self.linhas[chave] = d
        self.batches += 1

    def mostrar(self, n: int = 20, ordem=None, desc: bool = True):
        import pandas as pd
        pdf = pd.DataFrame(list(self.linhas.values()))
        if pdf.empty:
            print("(vazio — espere mais um pouco)")
            return pdf
        pdf = pdf.sort_values(ordem or self.chaves, ascending=not desc)
        print(f"{len(pdf)} chaves, {self.batches} batches recebidos")
        return pdf.head(n)
