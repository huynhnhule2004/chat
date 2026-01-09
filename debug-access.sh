#!/bin/bash

echo "🔍 Debugging External API Access"
echo "================================"

echo "📡 Testing basic connectivity:"
ping -c 3 146.190.194.170 2>/dev/null || echo "❌ Ping failed"

echo ""
echo "🔌 Testing port 5000 connection:"
timeout 10 telnet 146.190.194.170 5000 2>/dev/null || nc -z -v 146.190.194.170 5000 2>&1 || echo "❌ Port 5000 not accessible"

echo ""
echo "🌐 Testing HTTP endpoints:"

echo "Health endpoint:"
curl -v --connect-timeout 10 http://146.190.194.170:5000/health 2>&1 | grep -E "(Connected|HTTP|Connection refused|timeout)" || echo "❌ Health endpoint failed"

echo ""
echo "API docs endpoint:"
curl -v --connect-timeout 10 http://146.190.194.170:5000/api/docs 2>&1 | head -5

echo ""
echo "📋 Possible issues:"
echo "   1. Firewall blocking port 5000"
echo "   2. Container not binding to external interface"
echo "   3. Docker network configuration issue"
echo "   4. SSH connection issues"

echo ""
echo "🛠️ Solutions to try:"
echo "   1. Check firewall: ufw allow 5000/tcp"
echo "   2. Use ports mapping instead of host network"
echo "   3. Check Docker container binding"
