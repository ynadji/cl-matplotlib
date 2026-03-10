PYTHON := .venv/bin/python
SBCL := ros run --

REFERENCE_SCRIPTS_DIR := reference_scripts
REFERENCE_IMAGES_DIR := reference_images
EXAMPLES_DIR := examples
COMPARISON_REPORT_DIR := comparison_report
COMPARISON_TOOL := tools/compare.py

.PHONY: setup-python reference-images cl-images compare compare-png compare-svg compare-pdf report clean all

setup-python:
	@echo "Setting up Python virtual environment..."
	python -m venv .venv
	.venv/bin/pip install -r requirements.txt
	@echo "Setup complete. Run: .venv/bin/python -c \"import matplotlib; print(matplotlib.__version__)\""

reference-images:
	@echo "Generating Python reference images..."
	@mkdir -p $(REFERENCE_IMAGES_DIR)
	@for f in $(REFERENCE_SCRIPTS_DIR)/*.py; do \
		echo "Running $$f..."; \
		$(PYTHON) "$$f" || echo "WARNING: $$f failed"; \
	done
	@echo "Reference images generated in $(REFERENCE_IMAGES_DIR)/"

cl-images:
	@echo "Generating CL images..."
	@for f in $(EXAMPLES_DIR)/*.lisp; do \
		echo "Running $$f..."; \
		$(SBCL) --load "$$f" --quit 2>&1 || echo "WARNING: $$f failed"; \
	done
	@echo "CL images generated in $(EXAMPLES_DIR)/"

compare: cl-images
	@echo "Running combined comparison (PNG + SVG + PDF)..."
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(REFERENCE_IMAGES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--format all \
		--allowlist allowlist.json \
		--output $(COMPARISON_REPORT_DIR)/
	@echo "Report: $(COMPARISON_REPORT_DIR)/index.html"

compare-png:
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(REFERENCE_IMAGES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--format png \
		--threshold 0.95 \
		--allowlist allowlist.json \
		--output $(COMPARISON_REPORT_DIR)/png/

compare-svg:
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(REFERENCE_IMAGES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--format svg \
		--threshold 0.90 \
		--allowlist allowlist.json \
		--output $(COMPARISON_REPORT_DIR)/svg/

compare-pdf:
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(REFERENCE_IMAGES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--format pdf \
		--threshold 0.88 \
		--allowlist allowlist.json \
		--output $(COMPARISON_REPORT_DIR)/pdf/

report: compare
	@echo "Report generated at $(COMPARISON_REPORT_DIR)/index.html"

clean:
	rm -f $(REFERENCE_IMAGES_DIR)/*.png
	rm -f $(REFERENCE_IMAGES_DIR)/*.svg
	rm -f $(REFERENCE_IMAGES_DIR)/*.pdf
	rm -rf $(COMPARISON_REPORT_DIR)
	rm -f $(EXAMPLES_DIR)/*.png
	rm -f $(EXAMPLES_DIR)/*.svg
	rm -f $(EXAMPLES_DIR)/*.pdf

all: setup-python reference-images cl-images compare
