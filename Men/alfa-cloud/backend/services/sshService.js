const { exec } = require('child_process');

const createSSHUser = (username, password) => {
  return new Promise((resolve, reject) => {
    exec(`sudo useradd -m -p $(openssl passwd -1 ${password}) ${username}`, (err) => {
      if (err) reject(err);
      else resolve(`User ${username} created successfully`);
    });
  });
};

const deleteExpiredUsers = () => {
  // Logic to delete expired users
};

module.exports = { createSSHUser, deleteExpiredUsers };
