IMAGE  := cv-builder
PDF    := build/cv.pdf

.PHONY: build clean

build:
	@mkdir -p build
	docker build --platform linux/amd64 -t $(IMAGE) .
	docker run --rm \
	  -v "$(CURDIR)/content:/cv/content:ro" \
	  -v "$(CURDIR)/template:/cv/template:ro" \
	  -v "$(CURDIR)/style:/cv/style:ro" \
	  -v "$(CURDIR)/build:/cv/build" \
	  $(IMAGE)
	@echo "PDF généré : $(PDF)"

clean:
	rm -f $(PDF)
