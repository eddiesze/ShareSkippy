#!/bin/bash
echo "Testing DMARC record after update..."
echo ""
echo "Current DMARC record:"
dig TXT _dmarc.send.shareskippy.com +short
echo ""
echo "Expected format should include:"
echo "- p=quarantine (not p=none)"
echo "- rua=mailto:dmarc@shareskippy.com"
echo "- ruf=mailto:dmarc@shareskippy.com"
echo ""
echo "If you see 'p=none', the change hasn't propagated yet."
echo "Wait 30 minutes and run this script again."
