const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'API Chat E2EE',
      version: '1.0.0',
      description: `
        API ứng dụng Chat mã hóa đầu cuối (End-to-End Encryption)
        
        ## Tính năng
        - 🔒 Mã hóa đầu cuối với RSA + AES
        - 💬 Nhắn tin thời gian thực qua Socket.io
        - 👥 Chat nhóm với khóa phiên mã hóa
        - 📁 Chia sẻ file có mã hóa
        - 👤 Quản lý hồ sơ người dùng
        - 🛡️ Panel quản trị viên
        
        ## Xác thực
        Hầu hết các endpoint yêu cầu xác thực JWT. Thêm token vào header Authorization:
        Authorization: Bearer <jwt-token-của-bạn>
        
        ## Socket.io Events
        Giao tiếp thời gian thực được xử lý qua Socket.io trên cùng port.
        Kết nối tại: ws://localhost:5000/socket.io/
      `,
      contact: {
        name: 'Hỗ trợ API',
        email: 'support@e2eechat.com'
      }
    },
    servers: [
      {
        url: 'http://localhost:5000',
        description: 'Server phát triển'
      }
    ],
    components: {
      securitySchemes: {
        BearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Nhập JWT token theo định dạng: Bearer <token>'
        }
      },
      schemas: {
        User: {
          type: 'object',
          description: 'Thông tin người dùng',
          properties: {
            _id: {
              type: 'string',
              description: 'ID người dùng',
              example: '60f7b3b3b3b3b3b3b3b3b3b3'
            },
            username: {
              type: 'string',
              description: 'Tên đăng nhập duy nhất',
              example: 'nguoidung123'
            },
            email: {
              type: 'string',
              format: 'email',
              description: 'Địa chỉ email',
              example: 'user@example.com'
            },
            publicKey: {
              type: 'string',
              description: 'Khóa công khai RSA cho E2EE'
            },
            avatar: {
              type: 'string',
              description: 'URL ảnh đại diện',
              nullable: true
            },
            isOnline: {
              type: 'boolean',
              description: 'Trạng thái trực tuyến',
              example: true
            },
            lastActive: {
              type: 'string',
              format: 'date-time',
              description: 'Thời gian hoạt động cuối'
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
              description: 'Ngày tạo tài khoản'
            },
            role: {
              type: 'string',
              enum: ['user', 'admin'],
              description: 'Vai trò người dùng',
              example: 'user'
            }
          }
        },
        Message: {
          type: 'object',
          description: 'Tin nhắn',
          properties: {
            _id: {
              type: 'string',
              description: 'ID tin nhắn'
            },
            senderId: {
              type: 'string',
              description: 'ID người gửi'
            },
            recipientId: {
              type: 'string',
              description: 'ID người nhận (tin nhắn riêng)'
            },
            roomId: {
              type: 'string',
              description: 'ID phòng (chat nhóm)',
              nullable: true
            },
            encryptedContent: {
              type: 'string',
              description: 'Nội dung tin nhắn đã mã hóa (base64)'
            },
            messageType: {
              type: 'string',
              enum: ['text', 'file', 'image'],
              description: 'Loại tin nhắn',
              example: 'text'
            },
            fileUrl: {
              type: 'string',
              description: 'URL file (cho tin nhắn file)',
              nullable: true
            },
            fileName: {
              type: 'string',
              description: 'Tên file gốc',
              nullable: true
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Thời gian gửi'
            },
            isRead: {
              type: 'boolean',
              description: 'Trạng thái đã đọc',
              example: false
            }
          }
        },
        Room: {
          type: 'object',
          description: 'Phòng chat nhóm',
          properties: {
            _id: {
              type: 'string',
              description: 'ID phòng'
            },
            name: {
              type: 'string',
              description: 'Tên phòng'
            },
            description: {
              type: 'string',
              description: 'Mô tả phòng'
            },
            avatar: {
              type: 'string',
              description: 'Ảnh đại diện phòng',
              nullable: true
            },
            ownerId: {
              type: 'string',
              description: 'ID chủ phòng'
            },
            isPasswordProtected: {
              type: 'boolean',
              description: 'Có yêu cầu mật khẩu không'
            },
            members: {
              type: 'array',
              items: {
                type: 'string'
              },
              description: 'Danh sách ID thành viên'
            },
            memberCount: {
              type: 'number',
              description: 'Số lượng thành viên'
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
              description: 'Ngày tạo phòng'
            }
          }
        },
        Error: {
          type: 'object',
          description: 'Lỗi',
          properties: {
            error: {
              type: 'string',
              description: 'Thông báo lỗi',
              example: 'Có lỗi xảy ra'
            }
          }
        },
        Success: {
          type: 'object',
          description: 'Thành công',
          properties: {
            message: {
              type: 'string',
              description: 'Thông báo thành công',
              example: 'Thao tác hoàn tất thành công'
            }
          }
        }
      },
      responses: {
        UnauthorizedError: {
          description: 'Thiếu hoặc không hợp lệ token xác thực',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Yêu cầu token truy cập'
              }
            }
          }
        },
        ForbiddenError: {
          description: 'Bị cấm truy cập - không đủ quyền',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Từ chối truy cập. Yêu cầu quyền quản trị viên.'
              }
            }
          }
        },
        NotFoundError: {
          description: 'Không tìm thấy tài nguyên',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Không tìm thấy tài nguyên'
              }
            }
          }
        },
        ValidationError: {
          description: 'Lỗi xác thực - dữ liệu đầu vào không hợp lệ',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Xác thực thất bại: thiếu trường bắt buộc'
              }
            }
          }
        },
        ServerError: {
          description: 'Lỗi máy chủ nội bộ',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Lỗi máy chủ nội bộ'
              }
            }
          }
        }
      }
    },
    security: [
      {
        BearerAuth: []
      }
    ]
  },
  apis: ['./routes/*.js', './server.js'] // chỉ scan các file routes và server
};

const specs = swaggerJSDoc(options);

module.exports = specs;
