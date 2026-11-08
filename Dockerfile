# Compile once on the native builder architecture; the staged Play app is
# architecture-independent and is copied into each target runtime image.
FROM --platform=$BUILDPLATFORM eclipse-temurin:11-jdk AS build
WORKDIR /src

# Avoid JVMCI/Graal JIT compilation failures seen while compiling Scala 2.13.4.
ENV JAVA_TOOL_OPTIONS="-XX:+UnlockExperimentalVMOptions -XX:-UseJVMCICompiler"

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/paulp/sbt-extras/master/sbt -o /usr/local/bin/sbt \
    && chmod +x /usr/local/bin/sbt

COPY . .
RUN sbt clean stage

# Runtime stage follows the requested target platform (amd64 or arm64).
FROM eclipse-temurin:11-jre
ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:${PATH}" \
    CEREBRO_PORT=9000
WORKDIR /var/lib/cerebro

RUN groupadd --system --gid 10001 cerebro \
    && useradd --system --uid 10001 --gid cerebro --home-dir /var/lib/cerebro cerebro \
    && mkdir -p /opt/cerebro /var/lib/cerebro \
    && chown -R cerebro:cerebro /opt/cerebro /var/lib/cerebro

COPY --from=build --chown=cerebro:cerebro /src/target/universal/stage/ /opt/cerebro/

USER cerebro
EXPOSE 9000
VOLUME ["/var/lib/cerebro"]

ENTRYPOINT ["/opt/cerebro/bin/cerebro"]
CMD ["-Dhttp.address=0.0.0.0"]
