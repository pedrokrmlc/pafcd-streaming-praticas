# Jupyter Lab + PySpark + ferramentas de linha de comando do Kafka
FROM apache/kafka:4.0.0 AS kafka

FROM python:3.11-slim-bookworm
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-17-jre-headless procps curl less nano \
 && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# kafka-topics.sh, kafka-console-consumer.sh etc. disponíveis no terminal do Jupyter
COPY --from=kafka /opt/kafka /opt/kafka
ENV PATH=/opt/kafka/bin:$PATH

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

RUN useradd -m -u 1000 -s /bin/bash aluno
USER aluno
WORKDIR /home/aluno
ENV SHELL=/bin/bash \
    PYTHONPATH=/home/aluno/notebooks

# Baixa uma vez os conectores Kafka/Postgres do Spark (cache do Ivy dentro da imagem)
COPY --chown=aluno warmup.py /tmp/warmup.py
RUN python /tmp/warmup.py

# O terminal do Jupyter abre um shell de login, e o /etc/profile do Debian redefine o PATH.
# Este arquivo devolve as ferramentas do Kafka ao PATH em todo terminal.
USER root
RUN echo 'export PATH=/opt/kafka/bin:$PATH' > /etc/profile.d/kafka.sh
USER aluno

EXPOSE 8888 4040
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--ServerApp.root_dir=/home/aluno/notebooks"]
