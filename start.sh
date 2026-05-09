#!/bin/bash
set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — Enterprise Connectivity"
echo "  Diagnostic Platform"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Which role is this VM?"
echo ""
echo "  [1] Source Host      (VM A — Dashboard + Agent)"
echo "  [2] Destination Host (VM B — Target Simulator)"
echo ""
read -rp "  Enter 1 or 2: " CHOICE
echo ""

case "$CHOICE" in
  1)
    echo "  → Starting as Source Host (VM A)..."
    echo ""
    chmod +x "$(dirname "$0")/start-vma.sh"
    bash "$(dirname "$0")/start-vma.sh"
    ;;
  2)
    echo "  → Starting as Destination Host (VM B)..."
    echo ""
    chmod +x "$(dirname "$0")/simulator/start-vmb.sh"
    bash "$(dirname "$0")/simulator/start-vmb.sh"
    ;;
  *)
    echo "  ✗ Invalid choice. Please enter 1 or 2."
    exit 1
    ;;
esac
