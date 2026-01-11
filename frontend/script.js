    // 获取图书数据
async function loadBooks() {
  try {
    const response = await fetch('http://localhost:3000/api/books');
    const books = await response.json();
    renderBooks(books);
  } catch (error) {
    console.error('加载图书失败:', error);
  }
}

// 渲染图书列表
function renderBooks(books) {
  const tableBody = document.getElementById('booksTable');
  tableBody.innerHTML = '';
  
  books.forEach(book => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${book.isbn}</td>
      <td>${book.title}</td>
      <td>${book.author}</td>
      <td>${book.publisher}</td>
      <td>${book.total_copies}</td>
      <td>${book.available_copies}</td>
      <td>
        <button class="btn btn-sm btn-info" 
                onclick="borrowBook('${book.isbn}')">
          借阅
        </button>
      </td>
    `;
    tableBody.appendChild(row);
  });
}

// 借书操作
async function borrowBook(isbn) {
  const readerId = document.getElementById('readerId').value;
  if (!readerId) {
    alert('请输入读者ID');
    return;
  }

  try {
    const response = await fetch('http://localhost:3000/api/borrow', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ readerId, isbn })
    });

    const result = await response.json();
    const resultDiv = document.getElementById('borrowResult');
    
    if (result.success) {
      resultDiv.className = 'alert alert-success';
      resultDiv.textContent = '✅ 借书成功！';
    } else {
      resultDiv.className = 'alert alert-danger';
      resultDiv.textContent = `❌ 错误: ${result.error}`;
    }
    
    resultDiv.style.display = 'block';
    setTimeout(() => resultDiv.style.display = 'none', 3000);
    
    // 重新加载图书列表
    loadBooks();
  } catch (error) {
    console.error('借书请求失败:', error);
  }
}

// 搜索功能
document.getElementById('searchBtn').addEventListener('click', () => {
  const query = document.getElementById('searchInput').value.toLowerCase();
  if (!query) return;
  
  fetch(`http://localhost:3000/api/books?query=${query}`)
    .then(response => response.json())
    .then(books => renderBooks(books));
});

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', () => {
  loadBooks();
  document.getElementById('borrowBtn').addEventListener('click', () => {
    const isbn = document.getElementById('isbn').value;
    const readerId = document.getElementById('readerId').value;
    if (isbn && readerId) borrowBook(isbn);
    else alert('请填写读者ID和图书ISBN');
  });
});