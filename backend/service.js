const express = require('express');
const sql = require('mssql');
const cors = require('cors');
const app = express();
const port = 3000;

const config = {
  user:'sa',
  password: '520052',
  port: 1433,
  server: 'localhost',
  database: 'LibraryDB',
  options: {
    encrypt: false,
    trustServerCertificate: true, // 本地开发用
  }
};

// 启用 CORS
app.use(cors());
app.use(express.json());

// 连接数据库
sql.connect(config).then(pool => {
  console.log('✅ SQL Server 连接成功');
  
  // API 路由
  app.get('/api/books', async (req, res) => {
    try {
      const result = await pool.request().query('SELECT * FROM Book');
      res.json(result.recordset);
    } catch (err) {
      console.error('📚 查询图书错误:', err);
      res.status(500).json({ error: '数据库查询失败' });
    }
  });

  app.get('/api/readers', async (req, res) => {
    try {
      const result = await pool.request().query('SELECT * FROM Reader');
      res.json(result.recordset);
    } catch (err) {
      console.error('👥 查询读者错误:', err);
      res.status(500).json({ error: '数据库查询失败' });
    }
  });

  app.post('/api/borrow', async (req, res) => {
    const { readerId, isbn } = req.body;
    try {
      // 调用存储过程
      await pool.request()
        .input('reader_id', sql.Char(10), readerId)
        .input('isbn', sql.Char(13), isbn)
        .execute('sp_BorrowBook');
      res.json({ success: true, message: '借书成功!' });
    } catch (err) {
      console.error('📖 借书错误:', err);
      res.status(500).json({ error: err.message });
    }
  });

  // 其他 API 路由...
  
  app.listen(port, () => {
    console.log(`🚀 后端服务运行在 http://localhost:${port}`);
  });
}).catch(err => {
  console.error('❌ 数据库连接失败:', err);
});