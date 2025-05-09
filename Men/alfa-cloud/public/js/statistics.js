document.addEventListener("DOMContentLoaded", async () => {
  const totalUsersSpan = document.getElementById("total-users");
  const activeProxiesSpan = document.getElementById("active-proxies");

  const fetchStats = async () => {
    const usersResponse = await fetch("/api/users");
    const users = await usersResponse.json();

    const proxiesResponse = await fetch("/api/proxies");
    const proxies = await proxiesResponse.json();

    totalUsersSpan.textContent = users.length;
    activeProxiesSpan.textContent = proxies.filter((proxy) => proxy.status === "Active").length;
  };

  fetchStats();
});
