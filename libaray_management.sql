-- 创建数据库
CREATE DATABASE LibraryDB;
GO
USE LibraryDB;
GO

-- 1. 创建所有表
CREATE TABLE Reader (
    reader_id CHAR(10) PRIMARY KEY,
    name NVARCHAR(50) NOT NULL,
    dept NVARCHAR(50),
    phone VARCHAR(15),
    email VARCHAR(100),
    status TINYINT DEFAULT 1 CHECK (status IN (0,1))
);
    -- 读者（读者号！，名字，学院，电话，邮箱，状态）

CREATE TABLE Book (
    isbn CHAR(13) PRIMARY KEY,
    title NVARCHAR(200) NOT NULL,
    author NVARCHAR(100),
    publisher NVARCHAR(100),
    publish_year INT,
    total_copies INT NOT NULL CHECK (total_copies >= 0),
    available_copies INT NOT NULL CHECK (available_copies >= 0),
    CONSTRAINT chk_copies CHECK (available_copies <= total_copies)
);
    -- 书籍（ISBN号！，书名，作者，出版社，出版年，总量，余量）

CREATE TABLE BorrowRecord (
    borrow_id INT IDENTITY(1,1) PRIMARY KEY,
    reader_id CHAR(10) NOT NULL,
    isbn CHAR(13) NOT NULL,
    borrow_date DATE DEFAULT GETDATE(),
    due_date DATE,
    return_date DATE NULL,
    is_returned BIT DEFAULT 0,
    FOREIGN KEY (reader_id) REFERENCES Reader(reader_id),
    FOREIGN KEY (isbn) REFERENCES Book(isbn)
);
    -- 借阅记录（借书号！，读者号*，ISBN*，借阅时间，截止日期，归还日期，是否归还）

CREATE TABLE FineRecord (
    fine_id INT IDENTITY(1,1) PRIMARY KEY,
    borrow_id INT NOT NULL,
    fine_amount DECIMAL(6,2) NOT NULL CHECK (fine_amount > 0),
    fine_reason NVARCHAR(100),
    created_at DATETIME DEFAULT GETDATE(),
    is_paid BIT DEFAULT 0,
    FOREIGN KEY (borrow_id) REFERENCES BorrowRecord(borrow_id)
);
    -- 逾期记录（逾期号！，借书号*，逾期罚款，逾期原因，逾期日期，是否支付）

CREATE TABLE Recommendation (
    rec_id INT IDENTITY(1,1) PRIMARY KEY,
    reader_id CHAR(10) NOT NULL,
    book_title NVARCHAR(200) NOT NULL,
    author NVARCHAR(100),
    reason NVARCHAR(500),
    status TINYINT DEFAULT 0 CHECK (status IN (0,1,2)),
    submit_date DATE DEFAULT GETDATE(),
    FOREIGN KEY (reader_id) REFERENCES Reader(reader_id)
);
    -- 荐购（荐购号！，读者号*，书名，作者，原因，，提交日期）

-- 2. 创建视图（每个视图前加GO）
GO
CREATE VIEW vw_CurrentBorrowings AS
SELECT br.borrow_id, r.name AS reader_name, b.title, b.isbn, br.borrow_date, br.due_date
FROM BorrowRecord br
JOIN Reader r ON br.reader_id = r.reader_id
JOIN Book b ON br.isbn = b.isbn
WHERE br.is_returned = 0;

GO
CREATE VIEW vw_ReaderBorrowHistory AS
SELECT r.name, b.title, br.borrow_date, br.due_date, br.return_date,
       CASE WHEN br.return_date > br.due_date THEN '是' ELSE '否' END AS is_overdue
FROM BorrowRecord br
JOIN Reader r ON br.reader_id = r.reader_id
JOIN Book b ON br.isbn = b.isbn;

GO
CREATE VIEW vw_Top10PopularBooks AS
SELECT TOP 10 b.title, b.author, COUNT(*) AS borrow_count
FROM BorrowRecord br
JOIN Book b ON br.isbn = b.isbn
GROUP BY b.isbn, b.title, b.author
ORDER BY borrow_count DESC;

-- 3. 创建存储过程（每个存储过程前加GO）
GO
CREATE PROCEDURE sp_BorrowBook
    @reader_id CHAR(10),
    @isbn CHAR(13)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Reader WHERE reader_id = @reader_id AND status = 1)
    BEGIN
        RAISERROR('读者账号无效或已冻结', 16, 1);
        ROLLBACK; RETURN;
    END

    DECLARE @available INT;
    SELECT @available = available_copies FROM Book WHERE isbn = @isbn;
    IF @available <= 0
    BEGIN
        RAISERROR('该图书暂无可借副本', 16, 1);
        ROLLBACK; RETURN;
    END

    INSERT INTO BorrowRecord (reader_id, isbn, due_date)
    VALUES (@reader_id, @isbn, DATEADD(DAY, 30, GETDATE()));

    UPDATE Book SET available_copies = available_copies - 1 WHERE isbn = @isbn;
    COMMIT;
    PRINT '借书成功！';
END;

GO
CREATE PROCEDURE sp_ReturnBook
    @borrow_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM BorrowRecord WHERE borrow_id = @borrow_id AND is_returned = 0)
    BEGIN
        RAISERROR('无效的借阅记录或已归还', 16, 1);
        ROLLBACK; RETURN;
    END

    UPDATE BorrowRecord 
    SET return_date = GETDATE(), is_returned = 1
    WHERE borrow_id = @borrow_id;

    UPDATE Book 
    SET available_copies = available_copies + 1
    WHERE isbn = (SELECT isbn FROM BorrowRecord WHERE borrow_id = @borrow_id);
    COMMIT;
    PRINT '还书成功！';
END;

-- 4. 创建触发器（前加GO）
GO
CREATE TRIGGER trg_AutoGenerateFine
ON BorrowRecord
AFTER UPDATE
AS
BEGIN
    IF UPDATE(return_date) AND UPDATE(is_returned)
    BEGIN
        INSERT INTO FineRecord (borrow_id, fine_amount, fine_reason)
        SELECT 
            i.borrow_id,
            DATEDIFF(DAY, i.due_date, i.return_date) * 0.5,
            '逾期归还'
        FROM inserted i
        WHERE i.return_date > i.due_date 
          AND i.is_returned = 1
          AND NOT EXISTS (
              SELECT 1 FROM FineRecord f WHERE f.borrow_id = i.borrow_id
          );
    END
END;

-- 5. 插入测试数据（连续执行，无需GO）
INSERT INTO Reader (reader_id, name, dept, phone, email) VALUES
('20230001', '张三', '计算机学院', '13800138000', 'zhangsan@univ.edu'),
('20230002', '李四', '外语学院', '13900139000', 'lisi@univ.edu');

INSERT INTO Book (isbn, title, author, publisher, publish_year, total_copies, available_copies) VALUES
('9787111654321', '数据库系统概论', '王珊', '机械工业出版社', 2020, 5, 3),
('9787121356789', '人工智能导论', '万学良', '高等教育出版社', 2021, 3, 1);

INSERT INTO BorrowRecord (reader_id, isbn, due_date) VALUES
('20230001', '9787111654321', DATEADD(DAY, 30, '2023-10-01')),
('20230002', '9787121356789', DATEADD(DAY, 30, '2023-10-05'));

-- 6. 模拟逾期（测试触发器）
UPDATE BorrowRecord SET return_date = '2023-11-05' WHERE borrow_id = 1;