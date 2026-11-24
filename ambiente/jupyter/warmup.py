"""Roda no build da imagem só para baixar o conector Kafka do Spark para o cache."""
from pyspark.sql import SparkSession

PACOTES = "org.apache.spark:spark-sql-kafka-0-10_2.13:4.0.1"

spark = SparkSession.builder.master("local[1]").config("spark.jars.packages", PACOTES).getOrCreate()
print("Spark", spark.version, "pronto com", PACOTES)
spark.stop()
