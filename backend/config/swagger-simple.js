const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'API Chat E2EE - End-to-End Encrypted Chat',
      version: '1.0.0',
      description: `
## API ứng dụng Chat mã hóa đầu cuối (E2EE)

API hỗ trợ chat real-time với mã hóa đầu cuối sử dụng RSA + AES, WebSocket, và quản lý người dùng.

### Tính năng chính:
- 🔐 **Mã hóa E2EE**: RSA để trao đổi key, AES để mã hóa tin nhắn
- 💬 **Chat real-time**: WebSocket với Socket.io
- 👥 **Group chat**: Hỗ trợ chat nhóm với mã hóa
- 📁 **File sharing**: Upload và chia sẻ file
- 🔑 **JWT Authentication**: Xác thực bằng JWT token
- 👨‍💼 **Admin panel**: Quản lý người dùng và hệ thống

### WebSocket Events:
- \`join_room\`: Tham gia phòng chat
- \`leave_room\`: Rời phòng chat
- \`new_message\`: Gửi tin nhắn mới
- \`message_received\`: Nhận tin nhắn
- \`user_typing\`: Thông báo đang gõ
- \`user_online\`: Trạng thái online
- \`user_offline\`: Trạng thái offline

### Bảo mật:
- Tất cả endpoints yêu cầu JWT token (trừ auth endpoints)
- Tin nhắn được mã hóa E2EE trước khi gửi lên server
- Public keys được quản lý và phân phối qua API
      `,
      contact: {
        name: 'Support',
        url: 'https://github.com/huynhnhule2004/chat',
        email: 'support@example.com'
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT'
      }
    },
    servers: [
      {
        url: 'http://localhost:5000',
        description: 'Development Server'
      },
      {
        url: 'ws://localhost:5000',
        description: 'WebSocket Server'
      }
    ],
    components: {
      securitySchemes: {
        BearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'JWT token obtained from login endpoint'
        }
      },
      schemas: {
        User: {
          type: 'object',
          required: ['username', 'email', 'publicKey'],
          properties: {
            _id: {
              type: 'string',
              description: 'Unique user identifier',
              example: '60f7b3b3b3b3b3b3b3b3b3b3'
            },
            username: {
              type: 'string',
              minLength: 3,
              maxLength: 30,
              description: 'Unique username',
              example: 'john_doe'
            },
            email: {
              type: 'string',
              format: 'email',
              description: 'User email address',
              example: 'john.doe@example.com'
            },
            publicKey: {
              type: 'string',
              description: 'RSA public key in PEM format for E2EE',
              example: '-----BEGIN PUBLIC KEY-----\nMIIBIjANBg...\n-----END PUBLIC KEY-----'
            },
            avatar: {
              type: 'string',
              description: 'URL to user avatar image',
              example: '/uploads/avatars/avatar-60f7b3b3-1234567890.jpg'
            },
            isOnline: {
              type: 'boolean',
              description: 'User online status',
              example: true
            },
            role: {
              type: 'string',
              enum: ['user', 'admin'],
              description: 'User role',
              default: 'user',
              example: 'user'
            },
            lastSeen: {
              type: 'string',
              format: 'date-time',
              description: 'Last seen timestamp',
              example: '2024-01-01T12:00:00.000Z'
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
              description: 'Account creation timestamp',
              example: '2024-01-01T12:00:00.000Z'
            }
          }
        },
        Message: {
          type: 'object',
          required: ['senderId', 'encryptedContent', 'messageType'],
          properties: {
            _id: {
              type: 'string',
              description: 'Unique message identifier',
              example: '60f7b3b3b3b3b3b3b3b3b3b4'
            },
            senderId: {
              type: 'string',
              description: 'ID of message sender',
              example: '60f7b3b3b3b3b3b3b3b3b3b3'
            },
            recipientId: {
              type: 'string',
              description: 'ID of message recipient (for direct messages)',
              example: '60f7b3b3b3b3b3b3b3b3b3b5'
            },
            roomId: {
              type: 'string',
              description: 'ID of room/group (for group messages)',
              example: '60f7b3b3b3b3b3b3b3b3b3b6'
            },
            encryptedContent: {
              type: 'string',
              description: 'AES encrypted message content',
              example: 'U2FsdGVkX1+vupppZksvRf5pq5g5XjFRlipRkwB0K1Y96Qsv2Lm+31cmzaAILwyt'
            },
            messageType: {
              type: 'string',
              enum: ['text', 'file', 'image', 'voice'],
              description: 'Type of message content',
              example: 'text'
            },
            fileUrl: {
              type: 'string',
              description: 'URL to file attachment (if messageType is file/image)',
              example: '/uploads/1234567890-document.pdf'
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Message creation timestamp',
              example: '2024-01-01T12:00:00.000Z'
            },
            isRead: {
              type: 'boolean',
              description: 'Message read status',
              default: false,
              example: false
            }
          }
        },
        Room: {
          type: 'object',
          required: ['name', 'ownerId'],
          properties: {
            _id: {
              type: 'string',
              description: 'Unique room identifier',
              example: '60f7b3b3b3b3b3b3b3b3b3b6'
            },
            name: {
              type: 'string',
              minLength: 1,
              maxLength: 100,
              description: 'Room/group name',
              example: 'Development Team'
            },
            description: {
              type: 'string',
              maxLength: 500,
              description: 'Room description',
              example: 'Discussion for development team members'
            },
            ownerId: {
              type: 'string',
              description: 'ID of room owner/creator',
              example: '60f7b3b3b3b3b3b3b3b3b3b3'
            },
            members: {
              type: 'array',
              items: { type: 'string' },
              description: 'Array of member user IDs',
              example: ['60f7b3b3b3b3b3b3b3b3b3b3', '60f7b3b3b3b3b3b3b3b3b3b4']
            },
            avatar: {
              type: 'string',
              description: 'URL to room avatar image',
              example: '/uploads/rooms/room-60f7b3b3-1234567890.jpg'
            },
            isPasswordProtected: {
              type: 'boolean',
              description: 'Whether room requires password to join',
              default: false,
              example: false
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
              description: 'Room creation timestamp',
              example: '2024-01-01T12:00:00.000Z'
            },
            lastActivity: {
              type: 'string',
              format: 'date-time',
              description: 'Last message timestamp in room',
              example: '2024-01-01T12:30:00.000Z'
            }
          }
        },
        RoomMember: {
          type: 'object',
          required: ['roomId', 'userId', 'encryptedSessionKey'],
          properties: {
            _id: {
              type: 'string',
              description: 'Unique room member identifier',
              example: '60f7b3b3b3b3b3b3b3b3b3b7'
            },
            roomId: {
              type: 'string',
              description: 'ID of the room',
              example: '60f7b3b3b3b3b3b3b3b3b3b6'
            },
            userId: {
              type: 'string',
              description: 'ID of the user',
              example: '60f7b3b3b3b3b3b3b3b3b3b3'
            },
            encryptedSessionKey: {
              type: 'string',
              description: 'Session key encrypted with user public key',
              example: 'RSA_ENCRYPTED_SESSION_KEY_BASE64'
            },
            role: {
              type: 'string',
              enum: ['owner', 'admin', 'member'],
              description: 'Member role in room',
              default: 'member',
              example: 'member'
            },
            joinedAt: {
              type: 'string',
              format: 'date-time',
              description: 'When user joined the room',
              example: '2024-01-01T12:00:00.000Z'
            }
          }
        },
        AuthResponse: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              example: 'Login successful'
            },
            token: {
              type: 'string',
              description: 'JWT access token',
              example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
            },
            user: {
              $ref: '#/components/schemas/User'
            }
          }
        },
        FileUploadResponse: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              example: 'File uploaded successfully'
            },
            fileUrl: {
              type: 'string',
              description: 'Relative URL to access the file',
              example: '/uploads/1234567890-document.pdf'
            },
            filename: {
              type: 'string',
              description: 'Generated filename on server',
              example: '1234567890-document.pdf'
            },
            originalName: {
              type: 'string',
              description: 'Original filename',
              example: 'document.pdf'
            },
            size: {
              type: 'integer',
              description: 'File size in bytes',
              example: 1024000
            },
            mimetype: {
              type: 'string',
              description: 'MIME type of the file',
              example: 'application/pdf'
            }
          }
        },
        Error: {
          type: 'object',
          required: ['error'],
          properties: {
            error: {
              type: 'string',
              description: 'Error message',
              example: 'Invalid credentials'
            },
            code: {
              type: 'string',
              description: 'Error code',
              example: 'AUTH_ERROR'
            },
            details: {
              type: 'object',
              description: 'Additional error details'
            }
          }
        },
        SuccessResponse: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              example: 'Operation completed successfully'
            },
            data: {
              type: 'object',
              description: 'Response data'
            }
          }
        }
      },
      responses: {
        UnauthorizedError: {
          description: 'Authentication required',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Access token required',
                code: 'UNAUTHORIZED'
              }
            }
          }
        },
        ForbiddenError: {
          description: 'Insufficient permissions',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Admin access required',
                code: 'FORBIDDEN'
              }
            }
          }
        },
        NotFoundError: {
          description: 'Resource not found',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'User not found',
                code: 'NOT_FOUND'
              }
            }
          }
        },
        ValidationError: {
          description: 'Validation error',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Invalid input data',
                code: 'VALIDATION_ERROR',
                details: {
                  username: 'Username is required'
                }
              }
            }
          }
        },
        ServerError: {
          description: 'Internal server error',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: 'Internal server error',
                code: 'SERVER_ERROR'
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
  apis: ['./routes/*.js', './server.js', './docs/*.js']
};

const specs = swaggerJSDoc(options);
module.exports = specs;
