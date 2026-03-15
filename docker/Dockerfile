FROM alpine:3.19

# Install Perl, JSON module, and poppler (pdftotext)
RUN apk add --no-cache \
    perl \
    perl-json \
    poppler-utils

# Create a non-root user
RUN adduser -D -u 1000 testmaker

# Copy application files
COPY parsers/   /app/parsers/
COPY engine/    /app/engine/
COPY examples/  /app/examples/
COPY schemas/   /app/schemas/
COPY docker/server.pl /app/server.pl

RUN chown -R testmaker:testmaker /app

WORKDIR /app

USER testmaker

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["perl", "server.pl"]
