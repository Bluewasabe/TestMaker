FROM alpine:3.19

# Install Perl, JSON module, and poppler (pdftotext)
RUN apk add --no-cache \
    perl \
    perl-json \
    poppler-utils

# Copy application files
COPY parsers/   /app/parsers/
COPY engine/    /app/engine/
COPY examples/  /app/examples/
COPY schemas/   /app/schemas/
COPY docker/server.pl /app/server.pl

WORKDIR /app

EXPOSE 8080

CMD ["perl", "server.pl"]
