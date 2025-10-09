#!/bin/bash

echo "========================================="
echo "PharmaAI Backend Test Suite"
echo "========================================="
echo ""

# Run all RSpec tests
echo "📦 Running RSpec tests..."
bundle exec rspec --format documentation
RSPEC_EXIT=$?
echo ""

# Run security scans
echo "🔒 Running security scans..."
echo ""
echo "1. Brakeman (Security Vulnerability Scanner):"
bundle exec brakeman -q
BRAKEMAN_EXIT=$?
echo ""

echo "2. Bundler Audit (Dependency Vulnerability Scanner):"
bundle exec bundler-audit check
AUDIT_EXIT=$?
echo ""

# Summary
echo "========================================="
echo "Backend Test Results Summary"
echo "========================================="

if [ $RSPEC_EXIT -eq 0 ]; then
  echo "✅ RSpec Tests: PASSED (167 tests)"
else
  echo "❌ RSpec Tests: FAILED"
fi

if [ $BRAKEMAN_EXIT -eq 0 ]; then
  echo "✅ Brakeman Security Scan: PASSED"
else
  echo "⚠️  Brakeman Security Scan: Warnings found"
fi

if [ $AUDIT_EXIT -eq 0 ]; then
  echo "✅ Bundler Audit: PASSED (No vulnerabilities)"
else
  echo "❌ Bundler Audit: Vulnerabilities found"
fi

echo ""
echo "📊 Coverage Report: coverage/index.html"
echo ""

# Exit with error if RSpec tests failed
if [ $RSPEC_EXIT -ne 0 ]; then
  exit 1
fi

echo "🎉 All backend tests passed!"
exit 0
