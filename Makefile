# Makefile for fortplotlib Fortran Project with STB TrueType
# Handles compilation with STB TrueType C wrapper and all required libraries

# No external library dependencies needed - using STB headers only
ALL_CFLAGS = 
ALL_LIBS =

# FPM commands with full library support
FPM_FLAGS = --c-flag "$(ALL_CFLAGS)" --link-flag "$(ALL_LIBS)"

# Allow additional arguments to be passed
ARGS ?=

.PHONY: clean help check-deps ref

# Generate Python reference plots for visual comparison
ref:
	@echo "Generating Python matplotlib reference plots..."
	@python3 example/basic_plots/basic_plots_ref.py
	@python3 example/line_styles/line_styles_ref.py
	@python3 example/scale_examples/scale_examples_ref.py
	@python3 example/contour_demo/contour_demo_ref.py
	@echo "Reference plots generated! Compare *_ref.png files with fortplotlib output."

# Clean build artifacts
clean:
	echo y | fpm clean
	rm -f *.png *.pdf
	find example/ -name "*.png" -o -name "*.pdf" -o -name "*.txt" -not -name "CMakeLists.txt" | xargs rm -f

# Build with release optimizations
release:
	fpm build --profile release $(FPM_FLAGS) $(ARGS)

# Run with release optimizations
run-release:
	fpm run --profile release $(FPM_FLAGS) $(ARGS)

# Check dependencies and show detected flags
check-deps:
	@echo "Checking dependencies..."
	@echo "Combined CFLAGS: $(ALL_CFLAGS)"
	@echo "Combined LIBS:   $(ALL_LIBS)"
	@echo ""
	@echo "FPM command will be:"
	@echo "fpm <target> $(FPM_FLAGS)"

# Help target
help:
	@echo "Available targets:"
	@echo "  build       - Compile the project"
	@echo "  example     - Build and run all examples"
	@echo "  debug       - Build and run apps for debugging"
	@echo "  ref         - Generate Python matplotlib reference plots"
	@echo "  test        - Run all tests"
	@echo "  clean       - Clean build artifacts"
	@echo "  release     - Build with optimizations"
	@echo "  run-release - Run optimized build"
	@echo "  check-deps  - Show detected library flags"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Pass additional fpm arguments using ARGS variable:"
	@echo "  make example ARGS=\"basic_plots\""
	@echo "  make test ARGS=\"--target test_specific\""
	@echo "  make debug ARGS=\"--target debug_feature\""
	@echo ""
	@echo "This project uses STB TrueType and STB Image Write for text and PNG compression."
	@echo "All dependencies are included as header-only libraries."
	@echo "No external packages required."
