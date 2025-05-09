const { testProxy } = require('../services/proxyService');

const checkStatus = async (proxies) => {
  return Promise.all(
    proxies.map(async (proxy) => {
      const isActive = await testProxy(proxy.ip, proxy.port);
      return { ...proxy, status: isActive ? 'Active' : 'Inactive' };
    })
  );
};

module.exports = { checkStatus };
