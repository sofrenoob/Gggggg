document.addEventListener("DOMContentLoaded", () => {
  const proxyList = document.getElementById("proxy-list");
  const addProxyButton = document.getElementById("add-proxy");

  const loadProxies = async () => {
    const response = await fetch("/api/proxies");
    const proxies = await response.json();

    proxyList.innerHTML = "";
    proxies.forEach((proxy) => {
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${proxy.id}</td>
        <td>${proxy.name}</td>
        <td>${proxy.ip}</td>
        <td>${proxy.port}</td>
        <td>${proxy.mode}</td>
        <td>${proxy.status}</td>
        <td>
          <button class="edit" data-id="${proxy.id}">Edit</button>
          <button class="delete" data-id="${proxy.id}">Delete</button>
        </td>
      `;
      proxyList.appendChild(row);
    });

    document.querySelectorAll(".edit").forEach((button) => {
      button.addEventListener("click", () => editProxy(button.dataset.id));
    });

    document.querySelectorAll(".delete").forEach((button) => {
      button.addEventListener("click", () => deleteProxy(button.dataset.id));
    });
  };

  const editProxy = (id) => {
    alert(`Edit proxy ${id} (feature in progress)`);
  };

  const deleteProxy = async (id) => {
    await fetch(`/api/proxies/${id}`, { method: "DELETE" });
    loadProxies();
  };

  addProxyButton.addEventListener("click", () => {
    alert("Add new proxy (feature in progress)");
  });

  loadProxies();
});
