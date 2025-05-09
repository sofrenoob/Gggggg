const { exec } = require('child_process');

const testProxy = (ip, port) => {
  return new Promise((resolve, reject) => {
    exec(`curl -x ${ip}:${port} -I -m 5`, (err, stdout) => {
      if (err) reject(err);
      else resolve(stdout.includes('200 OK'));
    });
  });
};

module.exports = { testProxy };
