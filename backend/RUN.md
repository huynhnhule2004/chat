# Backend Run Guide

## Yêu cầu môi trường
- OS: Windows/Linux/macOS đều được.
- Node.js: >= 18 (khuyến nghị; tránh cảnh báo engine của mongoose/mongodb). Kèm npm >= 9.
- MongoDB: server đang chạy và truy cập được qua `MONGODB_URI` (TCP 27017 mở ra địa chỉ cấu hình).
- Dung lượng: tối thiểu 1 GB free disk để lưu uploads và MongoDB (tăng nếu test file lớn 100MB).
- Mạng: cần internet nếu dùng `npm install` lần đầu; cần truy cập host MongoDB cấu hình.

## Cài đặt
```bash
cd backend
npm install
```

## Cấu hình `.env`
Ví dụ (đã có sẵn):
```
MONGODB_URI=mongodb://chate2ee_user:<password>!@146.190.194.170:27017/chate2ee?authSource=chate2ee
PORT=5000
NODE_ENV=development
JWT_SECRET=your-secret-key-here-change-in-production
CLIENT_URL=http://localhost:3000
```

## Seed dữ liệu mẫu
```bash
cd backend
npm run seed
```
- Tạo sẵn user: admin/Admin123!, demo/Demo123!, alice/bob/charlie/diana/eve.
- Tạo 1 group demo và tin nhắn mẫu.

## Chạy server
```bash
cd backend
npm start           # chạy sản xuất
# hoặc
npm run dev         # dùng nodemon
```
Server mặc định: http://localhost:5000 (theo `.env`).

## Smoke test API (health, login, group messages, upload file/ảnh)
```bash
cd backend
npm run test:api
```
- Yêu cầu Mongo đang chạy và `.env` hợp lệ.

## Lưu ý bảo mật
- Đổi `JWT_SECRET`, mật khẩu Mongo trước khi deploy.
- Hạn chế CORS theo domain thật, cân nhắc rate limit và kiểm MIME/file. 
