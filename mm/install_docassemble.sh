

echo "Iniciando instalação do projeto de construtor de páginas..."

# Atualizar sistema
sudo apt update
sudo apt upgrade -y
sudo apt install -y nodejs npm sqlite3

# Criar pasta do projeto
PROJ_DIR=~/page-builder
mkdir -p "$PROJ_DIR"/{backend,frontend}
cd "$PROJ_DIR"

# Criar package.json
cat > backend/package.json <<EOF
{
  "name": "page-builder-backend",
  "version": "1.0.0",
  "description": "Backend para construtor de páginas",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "sqlite3": "^5.0.18",
    "body-parser": "^1.20.2"
  }
}
EOF

# Criar app.js do backend
cat > backend/app.js <<'EOF'
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const port = 3000;

app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, '../frontend')));

const db = new sqlite3.Database('./db.sqlite');

db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS paginas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      html TEXT NOT NULL
    )
  `);
});

app.post('/save', (req, res) => {
  const html = req.body.html;
  db.run(`INSERT INTO paginas (html) VALUES (?)`, [html], function(err) {
    if (err) {
      res.json({ message: 'Erro ao salvar.' });
    } else {
      res.json({ message: 'Página salva com sucesso!', id: this.lastID });
    }
  });
});

app.get('/list', (req, res) => {
  db.all(`SELECT * FROM paginas`, [], (err, rows) => {
    if (err) {
      res.send('Erro ao listar páginas');
    } else {
      let html = '<h1>Páginas Salvas</h1><ul>';
      rows.forEach(row => {
        html += \`<li><a href="/page/\${row.id}" target="_blank">Página #\${row.id}</a></li>\`;
      });
      html += '</ul><a href="/">Criar nova página</a>';
      res.send(html);
    }
  });
});

app.get('/page/:id', (req, res) => {
  const id = req.params.id;
  db.get(`SELECT html FROM paginas WHERE id = ?`, [id], (err, row) => {
    if (err || !row) {
      res.send('Página não encontrada');
    } else {
      res.send(row.html);
    }
  });
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/index.html'));
});

app.listen(port, () => {
  console.log(\`Servidor rodando em http://localhost:\${port}\`);
});
EOF

# Criar frontend/index.html
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8" />
  <title>Construtor de Páginas</title>
  <link href="https://unpkg.com/grapesjs/dist/css/grapes.min.css" rel="stylesheet"/>
  <style>
    body, html {
      margin: 0;
      padding: 0;
      height: 100%;
    }
    #gjs {
      height: 90vh;
    }
    #buttons {
      padding: 10px;
      background-color: #f0f0f0;
      display: flex;
      gap: 10px;
    }
  </style>
</head>
<body>

<div id="buttons">
  <button id="saveBtn">Salvar Página</button>
  <button id="listarBtn">Listar Páginas</button>
</div>
<div id="gjs"></div>

<script src="https://unpkg.com/grapesjs/dist/grapes.min.js"></script>
<script>
  const editor = grapesjs.init({
    container: '#gjs',
    height: '90vh',
    fromElement: false,
    storageManager: { autoload: false },
  });

  document.getElementById('saveBtn').onclick = () => {
    const html = editor.getHtml();
    fetch('/save', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ html }),
    })
    .then(res => res.json())
    .then(data => alert(data.message))
    .catch(err => alert('Erro ao salvar: ' + err));
  };

  document.getElementById('listarBtn').onclick = () => {
    window.location.href = '/list';
  };
</script>

</body>
</html>
EOF

# Instalar dependências Node.js
cd backend
npm install

# Instruções finais
echo "Projeto configurado com sucesso!"
echo "Para iniciar o servidor, execute:"
echo "  cd ~/page-builder/backend"
echo "  npm start"
echo "Depois acesse em seu navegador: http://localhost:3000"
