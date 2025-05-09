module.exports = {
  apps: [
    {
      name: "alfa-cloud",
      script: "server.js",
      watch: false,
      env: {
        NODE_ENV: "production"
      }
    }
  ]
}
