FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      pandoc \
      python3 \
      python3-pip \
      python3-venv \
      fonts-liberation \
      libpango-1.0-0 \
      libpangoft2-1.0-0 \
      libharfbuzz0b \
      libfontconfig1 \
      libffi-dev \
      libcairo2 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir weasyprint

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /cv

CMD sh -c " \
  pandoc content/cv.md \
    --template=template/template.html \
    --standalone \
    -o /tmp/cv.html \
  && weasyprint /tmp/cv.html build/cv.pdf \
    --base-url file:///cv/ \
"
