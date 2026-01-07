# MongoDB Quick Reference

## Connection Information
- **Host**: 146.190.194.170:27017
- **Database**: chate2ee
- **Username**: chate2ee_user
- **Password**: ChatE2EEPass123!

## Quick Connect
```bash
mongosh "mongodb://chate2ee_user:ChatE2EEPass123!@146.190.194.170:27017/chate2ee?authSource=chate2ee"
```

## Common Commands

### Show all databases
```javascript
show dbs
```

### Switch to chate2ee database
```javascript
use chate2ee
```

### Show all collections
```javascript
show collections
```

### Query users
```javascript
db.users.find().pretty()
db.users.countDocuments()
```

### Query messages
```javascript
db.messages.find().limit(10).sort({createdAt: -1}).pretty()
db.messages.countDocuments()
```

### Query rooms
```javascript
db.rooms.find().pretty()
db.rooms.countDocuments()
```

### Create indexes (for better performance)
```javascript
db.messages.createIndex({ roomId: 1, createdAt: -1 })
db.messages.createIndex({ senderId: 1 })
db.rooms.createIndex({ members: 1 })
db.users.createIndex({ email: 1 }, { unique: true })
```

## Backup & Restore

### Backup database
```bash
ssh root@146.190.194.170
mongodump --uri="mongodb://chate2ee_user:ChatE2EEPass123!@localhost:27017/chate2ee?authSource=chate2ee" --out=/root/backups/$(date +%Y%m%d)
```

### Restore database
```bash
mongorestore --uri="mongodb://chate2ee_user:ChatE2EEPass123!@localhost:27017/chate2ee?authSource=chate2ee" /root/backups/20260107/chate2ee
```

## Monitoring

### Check MongoDB status
```bash
ssh root@146.190.194.170 'systemctl status mongod'
```

### View MongoDB logs
```bash
ssh root@146.190.194.170 'tail -f /var/log/mongodb/mongod.log'
```

### Check database size
```javascript
use chate2ee
db.stats()
```

## Security Notes

⚠️ **IMPORTANT**: 
- The passwords shown here are examples. Change them in production!
- Add your server IP to MongoDB firewall rules if needed
- Enable SSL/TLS for production use
- Set up regular automated backups
