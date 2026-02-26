PYTHON := .venv/bin/python
SBCL := ros run --

REFERENCE_SCRIPTS_DIR := reference_scripts
REFERENCE_IMAGES_DIR := reference_images
EXAMPLES_DIR := examples
COMPARISON_REPORT_DIR := comparison_report
COMPARISON_TOOL := tools/compare.py
THRESHOLD := 0.95

.PHONY: setup-python reference-images cl-images compare compare-svg compare-pdf compare-all report clean all

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
	@echo "Running visual comparison..."
	@mkdir -p $(COMPARISON_REPORT_DIR)
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(REFERENCE_IMAGES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--threshold $(THRESHOLD) \
		--output $(COMPARISON_REPORT_DIR)/
	@echo "Comparison complete. Report: $(COMPARISON_REPORT_DIR)/index.html"

compare-svg: cl-images
	@echo "Running SVG visual comparison..."
	@mkdir -p comparison_report_svg/
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(EXAMPLES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--format svg \
		--dpi 96 \
		--threshold $(THRESHOLD) \
		--allowlist allowlist.json \
		--output comparison_report_svg/
	@echo "SVG comparison complete. Report: comparison_report_svg/index.html"

compare-pdf: cl-images
	@echo "Running PDF visual comparison..."
	@mkdir -p comparison_report_pdf/
	$(PYTHON) $(COMPARISON_TOOL) \
		--reference $(EXAMPLES_DIR)/ \
		--actual $(EXAMPLES_DIR)/ \
		--format pdf \
		--threshold $(THRESHOLD) \
		--allowlist allowlist.json \
		--output comparison_report_pdf/
	@echo "PDF comparison complete. Report: comparison_report_pdf/index.html"

compare-all: compare compare-svg compare-pdf
	@echo "All comparisons complete."

report: compare
	@echo "Report generated at $(COMPARISON_REPORT_DIR)/index.html"

clean:
	rm -f $(REFERENCE_IMAGES_DIR)/*.png
	rm -rf $(COMPARISON_REPORT_DIR)
	rm -f $(EXAMPLES_DIR)/*.png

all: setup-python reference-images cl-images compare compare-svg compare-pdf
