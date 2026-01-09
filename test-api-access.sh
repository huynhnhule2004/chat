#!/bin/bash

echo "🔬 Comprehensive API Access Test"
echo "================================"
echo "Target: http://146.190.194.170:5000"
echo "Time: $(date)"
echo ""

echo "1️⃣ Basic connectivity test:"
ping -c 1 -W 3 146.190.194.170 2>/dev/null && echo "✅ Server reachable" || echo "❌ Server unreachable"

echo ""
echo "2️⃣ Port 5000 connectivity:"
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/146.190.194.170/5000' 2>/dev/null && echo "✅ Port 5000 open" || echo "❌ Port 5000 blocked"

echo ""
echo "3️⃣ HTTP Health Check:"
response=$(curl -s --connect-timeout 5 --max-time 10 http://146.190.194.170:5000/health 2>&1)
if [[ $? -eq 0 && -n "$response" ]]; then
    echo "✅ Health endpoint accessible"
    echo "Response: $response"
else
    echo "❌ Health endpoint failed"
fi

echo ""
echo "4️⃣ Swagger Docs Check:"
http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 http://146.190.194.170:5000/api/docs 2>/dev/null)
if [[ "$http_code" =~ ^(200|301|302)$ ]]; then
    echo "✅ Swagger docs accessible (HTTP $http_code)"
else
    echo "❌ Swagger docs failed (HTTP $http_code)"
fi

echo ""
echo "5️⃣ API Base Check:"
curl -s --connect-timeout 5 --max-time 10 -I http://146.190.194.170:5000/api 2>/dev/null | head -2 && echo "✅ API base responsive" || echo "❌ API base failed"

echo ""
echo "🎯 Quick Access Links:"
echo "   Health: http://146.190.194.170:5000/health"
echo "   Docs:   http://146.190.194.170:5000/api/docs"
echo "   API:    http://146.190.194.170:5000/api"

echo ""
echo "🛠️  If failed, try manual SSH check:"
echo "   ssh root@146.190.194.170"
echo "   curl http://localhost:5000/health"
