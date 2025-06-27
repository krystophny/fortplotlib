#!/bin/bash
# Build and run TrueType tests using FPM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Running TrueType Tests with FPM...${NC}"
echo ""

# Check if FPM is available
if ! command -v fpm &> /dev/null; then
    echo -e "${RED}Error: FPM (Fortran Package Manager) not found.${NC}"
    echo "Please install FPM first: https://fpm.fortran-lang.org/"
    exit 1
fi

# Function to run a test and report results
run_test() {
    local test_name=$1
    echo -e "${YELLOW}=== $test_name ===${NC}"
    
    if fpm test --target $test_name; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
        return 1
    fi
}

# Run individual test suites or all tests
if [[ "$1" == "all" || "$1" == "" ]]; then
    echo "Running all TrueType tests..."
    echo ""
    
    failed_tests=0
    
    # Run each test
    run_test "test_truetype_font_reading" || ((failed_tests++))
    echo ""
    
    run_test "test_truetype_table_parsing" || ((failed_tests++))
    echo ""
    
    run_test "test_truetype_glyph_parsing" || ((failed_tests++))
    echo ""
    
    run_test "test_truetype_bitmap_rendering" || ((failed_tests++))
    echo ""
    
    run_test "test_truetype_comprehensive" || ((failed_tests++))
    echo ""
    
    # Summary
    echo "========================================="
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
        exit 0
    else
        echo -e "${RED}❌ $failed_tests TEST(S) FAILED${NC}"
        exit 1
    fi
    
elif [[ "$1" == "font_reading" ]]; then
    run_test "test_truetype_font_reading"
    
elif [[ "$1" == "table_parsing" ]]; then
    run_test "test_truetype_table_parsing"
    
elif [[ "$1" == "glyph_parsing" ]]; then
    run_test "test_truetype_glyph_parsing"
    
elif [[ "$1" == "bitmap_rendering" ]]; then
    run_test "test_truetype_bitmap_rendering"
    
elif [[ "$1" == "comprehensive" ]]; then
    run_test "test_truetype_comprehensive"
    
else
    echo "Usage: $0 [all|font_reading|table_parsing|glyph_parsing|bitmap_rendering|comprehensive]"
    echo ""
    echo "Available tests:"
    echo "  all                 - Run all TrueType tests (default)"
    echo "  font_reading        - Test font file reading and initialization"
    echo "  table_parsing       - Test TrueType table parsing"
    echo "  glyph_parsing       - Test glyph parsing functionality"
    echo "  bitmap_rendering    - Test bitmap rendering"
    echo "  comprehensive       - Run comprehensive test suite"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run all tests"
    echo "  $0 all                      # Run all tests"
    echo "  $0 font_reading             # Run only font reading tests"
    echo "  fpm test --target test_truetype_font_reading  # Direct FPM usage"
    exit 1
fi
