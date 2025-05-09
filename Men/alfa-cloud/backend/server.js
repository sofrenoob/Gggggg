const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');
const userController = require('./controllers/userController');
const proxyController = require('./controllers/proxyController');
const { db } = require('./models/db');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Rotas da API
app.use('/api/users', userController);
app.use('/api/proxies', proxyController);

// Servir arquivos estáticos do frontend
app.use(express.static(path.join(__dirname, '../public')));

// Rota fallback (opcional, útil para SPA)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Inicialização do servidor
app.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
