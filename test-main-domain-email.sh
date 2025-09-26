#!/bin/bash
echo "Testing email authentication for shareskippy.com..."
echo ""

echo "1. SPF Record:"
dig TXT shareskippy.com +short | grep "v=spf1"
echo ""

echo "2. DKIM Record:"
dig TXT resend._domainkey.shareskippy.com +short
echo ""

echo "3. DMARC Record:"
dig TXT _dmarc.shareskippy.com +short
echo ""

echo "✅ All three should show values for proper email authentication"
echo "❌ If any are empty, those records need to be added"
