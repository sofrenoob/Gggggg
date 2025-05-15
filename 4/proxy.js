
const readlineSync = require('readline-sync');
const { execSync } = require('child_process');
const cluster = require('cluster');
const os = require('os');
const fs = require('fs');
const https = require('https');
const winston = require('winston');

const numCPUs = os.cpus().length;
const PORT = 8080;

// Configuração de logs
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'proxy.log' })
  ]
});

function startWebSocketServer(port) {
  const server = new WebSocket.Server({ server: createHttpsServer(port) });

  server.on('connection', (ws) => {
    logger.info('Cliente conectado');

    ws.on('message', (message) => {
      logger.info(`Mensagem recebida: ${message}`);
    });

    ws.on('close', () => {
      logger.info('Cliente desconectado');
    });
  });

  logger.info(`Servidor WebSocket rodando na porta ${port}`);
}

function createHttpsServer(port) {
  const server = https.createServer({
    cert: fs.readFileSync('cert.pem'),
    key: fs.readFileSync('key.pem')
  });

  server.listen(port);
  return server;
}

function managePort(action, port) {
  try {
    if (action === 'open') {
      execSync(`sudo iptables -A INPUT -p tcp --dport ${port} -j ACCEPT`);
      logger.info(`Porta ${port} aberta.`);
    } else if (action === 'close') {
      execSync(`sudo iptables -A INPUT -p tcp --dport ${port} -j DROP`);
      logger.info(`Porta ${port} fechada.`);
    }
  } catch (error) {
    logger.error(`Erro ao ${action} porta: ${error}`);
  }
}

function listActivePorts() {
  try {
    const output = execSync('sudo netstat -tuln | grep LISTEN').toString();
    logger.info('Portas e serviços ativos:\n' + output);
  } catch (error) {
    logger.error('Erro ao listar portas:', error);
  }
}

function showMenu() {
  console.log("Menu de Gerenciamento de Proxy WebSocket");
  console.log("1. Iniciar servidor WebSocket");
  console.log("2. Abrir porta");
  console.log("3. Fechar porta");
  console.log("4. Listar portas e serviços ativos");
  console.log("5. Sair");

  const choice = readlineSync.question("Escolha uma opção: ");
  return choice;
}

function main() {
  if (cluster.isMaster) {
    logger.info(`Master ${process.pid} is running`);

    for (let i = 0; i < numCPUs; i++) {
      cluster.fork();
    }

    cluster.on('exit', (worker, code, signal) => {
      logger.warn(`Worker ${worker.process.pid} died`);
      cluster.fork(); // Reiniciar worker
    });
  } else {
    let running = true;
    while (running) {
      const choice = showMenu();
      switch (choice) {
        case '1':
          startWebSocketServer(PORT);
          break;
        case '2':
          const openPort = readlineSync.question("Digite a porta para abrir: ");
          managePort('open', openPort);
          break;
        case '3':
          const closePort = readlineSync.question("Digite a porta para fechar: ");
          managePort('close', closePort);
          break;
        case '4':
          listActivePorts();
          break;
        case '5':
          running = false;
          logger.info("Saindo...");
          break;
        default:
          console.log("Opção inválida, tente novamente.");
      }
    }
  }
}

main();
