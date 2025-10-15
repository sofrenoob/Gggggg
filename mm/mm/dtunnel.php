<?php
session_start();

// Criar diretórios se não existirem
if (!file_exists("configs")) {
    mkdir("configs", 0755, true);
}
if (!file_exists("categorias")) {
    mkdir("categorias", 0755, true);
}

// Função para gerar UUID
function generateUUID() {
    return sprintf("%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

// Função para gerar timestamp
function getCurrentTimestamp() {
    return date("Y-m-d H:i:s");
}

// Função para carregar arquivo JSON existente ou criar array vazio
function loadJsonFile($filepath) {
    if (file_exists($filepath)) {
        $content = file_get_contents($filepath);
        $data = json_decode($content, true);
        return is_array($data) ? $data : [];
    }
    return [];
}

// Função para salvar array no arquivo JSON
function saveJsonFile($filepath, $data) {
    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    return file_put_contents($filepath, $json);
}

// Função para encontrar o próximo ID disponível
function getNextId($data) {
    if (empty($data)) {
        return 1;
    }
    $maxId = 0;
    foreach ($data as $item) {
        if (isset($item["id"]) && $item["id"] > $maxId) {
            $maxId = $item["id"];
        }
    }
    return $maxId + 1;
}

// Processar formulário de configuração
if (isset($_POST["action"]) && $_POST["action"] === "add_config") {
    $configFile = "configs/config.json";
    $existingConfigs = loadJsonFile($configFile);
    
    // Salvar uma cópia do arquivo atual antes de modificar (backup automático)
    if (!empty($existingConfigs)) {
        $backupFilename = "configs/config_" . date("Y-m-d_H-i-s") . ".json";
        saveJsonFile($backupFilename, $existingConfigs);
    }

    $newConfig = [
        "id" => (int)($_POST["id"] ?: getNextId($existingConfigs)),
        "user_id" => $_POST["user_id"] ?: generateUUID(),
        "category_id" => (int)($_POST["category_id"] ?: 1),
        "name" => $_POST["name"] ?: "",
        "description" => $_POST["description"] ?: "",
        "config_payload" => [
            "payload" => $_POST["payload"] ?: null,
            "sni" => $_POST["sni"] ?: null
        ],
        "config_openvpn" => $_POST["config_openvpn"] ?: null,
        "config_v2ray" => $_POST["config_v2ray"] ?: null,
        "auth" => [
            "username" => $_POST["username"] ?: null,
            "password" => $_POST["password"] ?: null,
            "v2ray_uuid" => $_POST["v2ray_uuid"] ?: null
        ],
        "proxy" => [
            "host" => $_POST["proxy_host"] ?: null,
            "port" => (int)($_POST["proxy_port"] ?: 80)
        ],
        "server" => [
            "host" => $_POST["server_host"] ?: null,
            "port" => (int)($_POST["server_port"] ?: 80)
        ],
        "dnstt_key" => $_POST["dnstt_key"] ?: "",
        "dnstt_name_server" => $_POST["dnstt_name_server"] ?: "",
        "dnstt_server" => $_POST["dnstt_server"] ?: "",
        "hy_obfs" => $_POST["hy_obfs"] ?: "",
        "hy_up_mbps" => (int)($_POST["hy_up_mbps"] ?: 100),
        "hy_down_mbps" => (int)($_POST["hy_down_mbps"] ?: 150),
        "hy_insecure" => isset($_POST["hy_insecure"]) ? true : false,
        "hy_port" => $_POST["hy_port"] ?: "13375",
        "hy_version" => (int)($_POST["hy_version"] ?: 1),
        "dns_server" => [
            "dns1" => $_POST["dns1"] ?: "8.8.8.8",
            "dns2" => $_POST["dns2"] ?: "8.8.4.4"
        ],
        "udp_ports" => array_map("intval", explode(",", $_POST["udp_ports"] ?: "7100,7200,7300,7400,7500,7600,7700,7800,7900")),
        "mode" => $_POST["mode"] ?: "SSH_DIRECT",
        "tls_version" => $_POST["tls_version"] ?: "TLSv1.2",
        "status" => $_POST["status"] ?: "ACTIVE",
        "url_check_user" => $_POST["url_check_user"] ?: "",
        "icon" => $_POST["icon"] ?: "",
        "sorter" => (int)($_POST["sorter"] ?: count($existingConfigs) + 1),
        "created_at" => $_POST["created_at"] ?: getCurrentTimestamp(),
        "updated_at" => getCurrentTimestamp(),
        "category" => [
            "id" => (int)($_POST["category_id"] ?: 1),
            "user_id" => $_POST["user_id"] ?: generateUUID(),
            "name" => $_POST["category_name"] ?: "",
            "status" => "ACTIVE",
            "sorter" => (int)($_POST["sorter"] ?: count($existingConfigs) + 1),
            "color" => $_POST["category_color"] ?: "#80E122FF",
            "created_at" => getCurrentTimestamp(),
            "updated_at" => getCurrentTimestamp()
        ],
        "cdns" => []
    ];

    // Adicionar nova configuração ao array existente
    $existingConfigs[] = $newConfig;
    
    // Salvar arquivo atualizado
    saveJsonFile($configFile, $existingConfigs);
    
    $_SESSION["success_message"] = "Configuração adicionada com sucesso! Total de configurações: " . count($existingConfigs);
    header("Location: dtunnel.php?tab=config&success=1");
    exit;
}

// Processar download do arquivo completo de configurações
if (isset($_GET["action"]) && $_GET["action"] === "download_config") {
    $configFile = "configs/config.json";
    if (file_exists($configFile)) {
        header("Content-Type: application/json");
        header("Content-Disposition: attachment; filename=\"config.json\"");
        readfile($configFile);
        exit;
    }
}

// Processar formulário de categoria
if (isset($_POST["action"]) && $_POST["action"] === "add_category") {
    $categoryFile = "categorias/categoria.json";
    $existingCategories = loadJsonFile($categoryFile);
    
    // Salvar uma cópia do arquivo atual antes de modificar (backup automático)
    if (!empty($existingCategories)) {
        $backupFilename = "categorias/categoria_" . date("Y-m-d_H-i-s") . ".json";
        saveJsonFile($backupFilename, $existingCategories);
    }

    $newCategory = [
        "id" => (int)($_POST["id"] ?: getNextId($existingCategories)),
        "name" => $_POST["name"] ?: "",
        "status" => $_POST["status"] ?: "ACTIVE",
        "sorter" => (int)($_POST["sorter"] ?: count($existingCategories) + 1),
        "color" => $_POST["color"] ?: "#80E122FF"
    ];

    // Adicionar nova categoria ao array existente
    $existingCategories[] = $newCategory;
    
    // Salvar arquivo atualizado
    saveJsonFile($categoryFile, $existingCategories);
    
    $_SESSION["success_message"] = "Categoria adicionada com sucesso! Total de categorias: " . count($existingCategories);
    header("Location: dtunnel.php?tab=category&success=1");
    exit;
}

// Processar download do arquivo completo de categorias
if (isset($_GET["action"]) && $_GET["action"] === "download_category") {
    $categoryFile = "categorias/categoria.json";
    if (file_exists($categoryFile)) {
        header("Content-Type: application/json");
        header("Content-Disposition: attachment; filename=\"categoria.json\"");
        readfile($categoryFile);
        exit;
    }
}

// Processar ação de limpar configurações
if (isset($_GET["action"]) && $_GET["action"] === "clear_configs") {
    $configFile = "configs/config.json";
    // Salvar uma cópia do arquivo atual antes de limpar (backup automático)
    $existingConfigs = loadJsonFile($configFile);
    if (!empty($existingConfigs)) {
        $backupFilename = "configs/config_" . date("Y-m-d_H-i-s") . ".json";
        saveJsonFile($backupFilename, $existingConfigs);
    }
    saveJsonFile($configFile, []); // Esvazia o arquivo principal
    $_SESSION["success_message"] = "Todas as configurações foram limpas!";
    header("Location: dtunnel.php?tab=config&success=1");
    exit;
}

// Processar ação de limpar categorias
if (isset($_GET["action"]) && $_GET["action"] === "clear_categories") {
    $categoryFile = "categorias/categoria.json";
    // Salvar uma cópia do arquivo atual antes de limpar (backup automático)
    $existingCategories = loadJsonFile($categoryFile);
    if (!empty($existingCategories)) {
        $backupFilename = "categorias/categoria_" . date("Y-m-d_H-i-s") . ".json";
        saveJsonFile($backupFilename, $existingCategories);
    }
    saveJsonFile($categoryFile, []); // Esvazia o arquivo principal
    $_SESSION["success_message"] = "Todas as categorias foram limpas!";
    header("Location: dtunnel.php?tab=category&success=1");
    exit;
}

// Carregar dados existentes para exibição
$existingConfigs = loadJsonFile("configs/config.json");
$existingCategories = loadJsonFile("categorias/categoria.json");
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Editor de Configurações</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 10px;
        }

        .container {
            max-width: 100%;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            padding: 20px;
            text-align: center;
            position: relative;
        }

        .header h1 {
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 5px;
        }

        .header p {
            opacity: 0.9;
            font-size: 14px;
        }

        .stats-bar {
            background: rgba(255, 255, 255, 0.1);
            padding: 10px;
            margin-top: 15px;
            border-radius: 10px;
            display: flex;
            justify-content: space-around;
            text-align: center;
        }

        .stat-item {
            flex: 1;
        }

        .stat-number {
            font-size: 20px;
            font-weight: 700;
        }

        .stat-label {
            font-size: 12px;
            opacity: 0.8;
        }

        .tabs {
            display: flex;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
        }

        .tab {
            flex: 1;
            padding: 15px;
            text-align: center;
            background: none;
            border: none;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            color: #6c757d;
            transition: all 0.3s ease;
            position: relative;
        }

        .tab.active {
            color: #4facfe;
            background: white;
        }

        .tab.active::after {
            content: '';
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }

        .tab-content {
            display: none;
            padding: 20px;
        }

        .tab-content.active {
            display: block;
        }

        .success-message {
            background: #d4edda;
            color: #155724;
            padding: 15px;
            border-radius: 12px;
            margin-bottom: 20px;
            border: 1px solid #c3e6cb;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .download-section {
            background: #e7f3ff;
            border: 2px solid #4facfe;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            text-align: center;
        }

        .download-btn {
            background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
            margin: 5px;
        }

        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(40, 167, 69, 0.3);
        }

        .form-group {
            margin-bottom: 20px;
        }

        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #495057;
            font-size: 14px;
        }

        .form-control {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e9ecef;
            border-radius: 12px;
            font-size: 16px;
            transition: all 0.3s ease;
            background: white;
        }

        .form-control:focus {
            outline: none;
            border-color: #4facfe;
            box-shadow: 0 0 0 3px rgba(79, 172, 254, 0.1);
        }

        .form-control.textarea {
            min-height: 100px;
            resize: vertical;
            font-family: 'Courier New', monospace;
        }

        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }

        .form-row-3 {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
        }

        .checkbox-group {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-top: 8px;
        }

        .checkbox-group input[type="checkbox"] {
            width: 20px;
            height: 20px;
            accent-color: #4facfe;
        }

        .btn {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            width: 100%;
            margin-top: 20px;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(79, 172, 254, 0.3);
        }

        .btn:active {
            transform: translateY(0);
        }

        .btn-clear {
            background: linear-gradient(135deg, #dc3545 0%, #c82333 100%);
            margin-top: 10px;
        }

        .btn-clear:hover {
            box-shadow: 0 10px 20px rgba(220, 53, 69, 0.3);
        }

        .mode-selector {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 10px;
            margin-top: 10px;
        }

        .mode-option {
            position: relative;
        }

        .mode-option input[type="radio"] {
            position: absolute;
            opacity: 0;
        }

        .mode-option label {
            display: block;
            padding: 12px 8px;
            background: #f8f9fa;
            border: 2px solid #e9ecef;
            border-radius: 8px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 12px;
            font-weight: 600;
        }

        .mode-option input[type="radio"]:checked + label {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            border-color: #4facfe;
        }

        .section-title {
            font-size: 18px;
            font-weight: 700;
            color: #495057;
            margin: 30px 0 15px 0;
            padding-bottom: 10px;
            border-bottom: 2px solid #e9ecef;
        }

        .collapsible {
            background: #f8f9fa;
            border-radius: 12px;
            margin-bottom: 20px;
            overflow: hidden;
        }

        .collapsible-header {
            padding: 15px 20px;
            background: #e9ecef;
            cursor: pointer;
            font-weight: 600;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .collapsible-content {
            padding: 20px;
            display: none;
        }

        .collapsible.active .collapsible-content {
            display: block;
        }

        .collapsible-header::after {
            content: '+';
            font-size: 20px;
            transition: transform 0.3s ease;
        }

        .collapsible.active .collapsible-header::after {
            transform: rotate(45deg);
        }

        @media (max-width: 768px) {
            .form-row {
                grid-template-columns: 1fr;
            }
            
            .form-row-3 {
                grid-template-columns: 1fr;
            }
            
            .mode-selector {
                grid-template-columns: repeat(2, 1fr);
            }
            
            .header h1 {
                font-size: 20px;
            }

            .stats-bar {
                flex-direction: column;
                gap: 10px;
            }
        }

        .color-input {
            height: 50px;
            border: none;
            border-radius: 12px;
            cursor: pointer;
        }

        .info-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px;
            border-radius: 12px;
            margin-bottom: 20px;
            font-size: 14px;
        }

        .floating-action {
            position: fixed;
            bottom: 20px;
            right: 20px;
            width: 60px;
            height: 60px;
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 24px;
            box-shadow: 0 10px 20px rgba(79, 172, 254, 0.3);
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .floating-action:hover {
            transform: scale(1.1);
        }

        .nav-links {
            text-align: center;
            padding: 15px;
            background: #f8f9fa;
            border-top: 1px solid #e9ecef;
        }

        .nav-link {
            background: #6c757d;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
            margin: 0 5px;
        }

        .nav-link:hover {
            background: #495057;
            transform: translateY(-1px);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 DTunnel  MOD 4.4.8 Pro</h1>
            <p>Gerador de arquivos JSON para configurações DT180 😏</p>
            
            <div class="stats-bar">
                <div class="stat-item">
                    <div class="stat-number"><?php echo count($existingConfigs); ?></div>
                    <div class="stat-label">Configurações</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number"><?php echo count($existingCategories); ?></div>
                    <div class="stat-label">Categorias</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">7</div>
                    <div class="stat-label">Protocolos</div>
                </div>
            </div>
        </div>

        <div class="tabs">
            <button class="tab <?php echo (!isset($_GET["tab"]) || $_GET["tab"] === "config") ? "active" : ""; ?>" onclick="switchTab('config')">Configuração</button>
            <button class="tab <?php echo (isset($_GET["tab"]) && $_GET["tab"] === "category") ? "active" : ""; ?>" onclick="switchTab('category')">Categoria</button>
        </div>

        <!-- Tab Configuração -->
        <div id="config-tab" class="tab-content <?php echo (!isset($_GET["tab"]) || $_GET["tab"] === "config") ? "active" : ""; ?>">
            <?php if (isset($_GET["success"]) && isset($_SESSION["success_message"])): ?>
            <div class="success-message">
                <span>✅</span>
                <span><?php echo $_SESSION["success_message"]; unset($_SESSION["success_message"]); ?></span>
            </div>
            <?php endif; ?>

            <div class="download-section">
                <h3>📥 Download do Arquivo Consolidado</h3>
                <p>Baixe o arquivo config.json com todas as configurações adicionadas</p>
                <a href="?action=download_config" class="download-btn">📥 Baixar config.json (<?php echo count($existingConfigs); ?> configurações)</a>
                <?php if (count($existingConfigs) > 0): ?>
                <a href="?action=clear_configs" class="download-btn btn-clear" onclick="return confirm('Tem certeza que deseja limpar TODAS as configurações da página?')">🗑️ Limpar Configurações</a>
                <?php endif; ?>
            </div>

            <div class="info-box">
                💡 <strong>Dica:</strong> Cada nova configuração será adicionada ao arquivo config.json existente. Nenhum campo é obrigatório.
            </div>

            <form method="POST" id="config-form">
                <input type="hidden" name="action" value="add_config">

                <!-- Informações Básicas -->
                <div class="section-title">📋 Informações Básicas</div>
                
                <div class="form-row">
                    <div class="form-group">
                        <label for="name">Nome da Configuração</label>
                        <input type="text" id="name" name="name" class="form-control" placeholder="Ex: VIVO 01">
                    </div>
                    <div class="form-group">
                        <label for="description">Descrição</label>
                        <input type="text" id="description" name="description" class="form-control" placeholder="➔➔➔➔">
                    </div>
                </div>

                <!-- Modo de Conexão -->
                <div class="section-title">🔗 Modo de Conexão</div>
                <div class="mode-selector">
                    <div class="mode-option">
                        <input type="radio" id="ssh_direct" name="mode" value="SSH_DIRECT" checked>
                        <label for="ssh_direct">SSH_DIRECT</label>
                    </div>
                    <div class="mode-option">
                        <input type="radio" id="ssl_direct" name="mode" value="SSL_DIRECT">
                        <label for="ssl_direct">SSL_DIRECT</label>
                    </div>
                    <div class="mode-option">
                        <input type="radio" id="v2ray" name="mode" value="V2RAY">
                        <label for="v2ray">V2RAY</label>
                    </div>
                    <div class="mode-option">
                        <input type="radio" id="ssl_proxy" name="mode" value="SSL_PROXY">
                        <label for="ssl_proxy">SSL_PROXY</label>
                    </div>
                    <div class="mode-option">
                        <input type="radio" id="ssh_dnstt" name="mode" value="SSH_DNSTT">
                        <label for="ssh_dnstt">SSH_DNSTT</label>
                    </div>
                    <div class="mode-option">
                        <input type="radio" id="ssh_proxy" name="mode" value="SSH_PROXY">
                        <label for="ssh_proxy">SSH_PROXY</label>
                    </div>
                    <div class="mode-option">
                        <input type="radio" id="hysteria" name="mode" value="HYSTERIA">
                        <label for="hysteria">HYSTERIA</label>
                    </div>
                </div>

                <!-- Configurações Avançadas em Seções Colapsáveis -->
                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        🌐 Configurações de Servidor
                    </div>
                    <div class="collapsible-content">
                        <div class="form-row">
                            <div class="form-group">
                                <label for="server_host">Host do Servidor</label>
                                <input type="text" id="server_host" name="server_host" class="form-control" placeholder="151.200.100.00#site.com">
                            </div>
                            <div class="form-group">
                                <label for="server_port">Porta do Servidor</label>
                                <input type="number" id="server_port" name="server_port" class="form-control" placeholder="80" value="80">
                            </div>
                        </div>
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label for="proxy_host">Host do Proxy</label>
                                <input type="text" id="proxy_host" name="proxy_host" class="form-control" placeholder="151.200.200.00#site.com">
                            </div>
                            <div class="form-group">
                                <label for="proxy_port">Porta do Proxy</label>
                                <input type="number" id="proxy_port" name="proxy_port" class="form-control" placeholder="80" value="80">
                            </div>
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        🔐 Autenticação
                    </div>
                    <div class="collapsible-content">
                        <div class="form-row">
                            <div class="form-group">
                                <label for="username">Usuário</label>
                                <input type="text" id="username" name="username" class="form-control" placeholder="username">
                            </div>
                            <div class="form-group">
                                <label for="password">Senha</label>
                                <input type="password" id="password" name="password" class="form-control" placeholder="password">
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label for="v2ray_uuid">V2Ray UUID</label>
                            <input type="text" id="v2ray_uuid" name="v2ray_uuid" class="form-control" placeholder="UUID para V2Ray">
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        📦 Payload e Configurações
                    </div>
                    <div class="collapsible-content">
                        <div class="form-group">
                            <label for="payload">Payload</label>
                            <textarea id="payload" name="payload" class="form-control textarea" placeholder="Insira o payload aqui..."></textarea>
                        </div>
                        
                        <div class="form-group">
                            <label for="sni">SNI</label>
                            <input type="text" id="sni" name="sni" class="form-control" placeholder="SNI">
                        </div>
                        
                        <div class="form-group">
                            <label for="config_openvpn">Configuração OpenVPN</label>
                            <textarea id="config_openvpn" name="config_openvpn" class="form-control textarea" placeholder="Configuração OpenVPN..."></textarea>
                        </div>
                        
                        <div class="form-group">
                            <label for="config_v2ray">Configuração V2Ray</label>
                            <textarea id="config_v2ray" name="config_v2ray" class="form-control textarea" placeholder="Configuração V2Ray..."></textarea>
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        🌐 DNS e Rede
                    </div>
                    <div class="collapsible-content">
                        <div class="form-row">
                            <div class="form-group">
                                <label for="dns1">DNS Primário</label>
                                <input type="text" id="dns1" name="dns1" class="form-control" placeholder="8.8.8.8" value="8.8.8.8">
                            </div>
                            <div class="form-group">
                                <label for="dns2">DNS Secundário</label>
                                <input type="text" id="dns2" name="dns2" class="form-control" placeholder="8.8.4.4" value="8.8.4.4">
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label for="udp_ports">Portas UDP (separadas por vírgula)</label>
                            <input type="text" id="udp_ports" name="udp_ports" class="form-control" placeholder="7100,7200,7300,7400,7500,7600,7700,7800,7900" value="7100,7200,7300,7400,7500,7600,7700,7800,7900">
                        </div>
                        
                        <div class="form-group">
                            <label for="tls_version">Versão TLS</label>
                            <select id="tls_version" name="tls_version" class="form-control">
                                <option value="TLSv1.2" selected>TLSv1.2</option>
                                <option value="TLSv1.3">TLSv1.3</option>
                                <option value="TLSv1.1">TLSv1.1</option>
                            </select>
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        🔧 Configurações DNSTT
                    </div>
                    <div class="collapsible-content">
                        <div class="form-group">
                            <label for="dnstt_key">DNSTT Key</label>
                            <input type="text" id="dnstt_key" name="dnstt_key" class="form-control" placeholder="Chave DNSTT">
                        </div>
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label for="dnstt_name_server">DNSTT Name Server</label>
                                <input type="text" id="dnstt_name_server" name="dnstt_name_server" class="form-control" placeholder="Name Server">
                            </div>
                            <div class="form-group">
                                <label for="dnstt_server">DNSTT Server</label>
                                <input type="text" id="dnstt_server" name="dnstt_server" class="form-control" placeholder="Servidor DNSTT">
                            </div>
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        ⚡ Configurações Hysteria
                    </div>
                    <div class="collapsible-content">
                        <div class="form-group">
                            <label for="hy_obfs">Hysteria Obfs</label>
                            <input type="text" id="hy_obfs" name="hy_obfs" class="form-control" placeholder="Obfuscação Hysteria">
                        </div>
                        
                        <div class="form-row-3">
                            <div class="form-group">
                                <label for="hy_up_mbps">Upload (Mbps)</label>
                                <input type="number" id="hy_up_mbps" name="hy_up_mbps" class="form-control" placeholder="100" value="100">
                            </div>
                            <div class="form-group">
                                <label for="hy_down_mbps">Download (Mbps)</label>
                                <input type="number" id="hy_down_mbps" name="hy_down_mbps" class="form-control" placeholder="150" value="150">
                            </div>
                            <div class="form-group">
                                <label for="hy_port">Porta</label>
                                <input type="text" id="hy_port" name="hy_port" class="form-control" placeholder="13375" value="13375">
                            </div>
                        </div>
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label for="hy_version">Versão</label>
                                <select id="hy_version" name="hy_version" class="form-control">
                                    <option value="1" selected>Versão 1</option>
                                    <option value="2">Versão 2</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <div class="checkbox-group">
                                    <input type="checkbox" id="hy_insecure" name="hy_insecure" checked>
                                    <label for="hy_insecure">Insecure</label>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        ⚙️ Configurações Adicionais
                    </div>
                    <div class="collapsible-content">
                        <div class="form-row">
                            <div class="form-group">
                                <label for="url_check_user">URL Check User</label>
                                <input type="url" id="url_check_user" name="url_check_user" class="form-control" placeholder="http://151.272.200.109:2052">
                            </div>
                            <div class="form-group">
                                <label for="icon">URL do Ícone</label>
                                <input type="url" id="icon" name="icon" class="form-control" placeholder="https://i.ibb.co/y2CJfwR/file.png">
                            </div>
                        </div>
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label for="status">Status</label>
                                <select id="status" name="status" class="form-control">
                                    <option value="ACTIVE" selected>ATIVO</option>
                                    <option value="INACTIVE">INATIVO</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label for="sorter">Ordem</label>
                                <input type="number" id="sorter" name="sorter" class="form-control" placeholder="<?php echo count($existingConfigs) + 1; ?>" value="<?php echo count($existingConfigs) + 1; ?>">
                            </div>
                        </div>
                    </div>
                </div>

                <div class="collapsible">
                    <div class="collapsible-header" onclick="toggleCollapsible(this)">
                        📁 Categoria
                    </div>
                    <div class="collapsible-content">
                        <div class="form-row">
                            <div class="form-group">
                                <label for="category_id">ID da Categoria</label>
                                <input type="number" id="category_id" name="category_id" class="form-control" placeholder="1" value="1">
                            </div>
                            <div class="form-group">
                                <label for="category_name">Nome da Categoria</label>
                                <input type="text" id="category_name" name="category_name" class="form-control" placeholder="VIVO">
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label for="category_color">Cor da Categoria</label>
                            <input type="color" id="category_color" name="category_color" class="form-control color-input" value="#80E122">
                        </div>
                    </div>
                </div>

                <button type="submit" class="btn">➕ Adicionar Configuração</button>
            </form>
        </div>

        <!-- Tab Categoria -->
        <div id="category-tab" class="tab-content <?php echo (isset($_GET["tab"]) && $_GET["tab"] === "category") ? "active" : ""; ?>">
            <?php if (isset($_GET["success"]) && isset($_SESSION["success_message"])): ?>
            <div class="success-message">
                <span>✅</span>
                <span><?php echo $_SESSION["success_message"]; unset($_SESSION["success_message"]); ?></span>
            </div>
            <?php endif; ?>

            <div class="download-section">
                <h3>📥 Download do Arquivo Consolidado</h3>
                <p>Baixe o arquivo categoria.json com todas as categorias adicionadas</p>
                <a href="?action=download_category" class="download-btn">📥 Baixar categoria.json (<?php echo count($existingCategories); ?> categorias)</a>
                <?php if (count($existingCategories) > 0): ?>
                <a href="?action=clear_categories" class="download-btn btn-clear" onclick="return confirm('Tem certeza que deseja limpar TODAS as categorias da página?')">🗑️ Limpar Categorias</a>
                <?php endif; ?>
            </div>

            <div class="info-box">
                📂 <strong>Categoria:</strong> Cada nova categoria será adicionada ao arquivo categoria.json existente.
            </div>

            <form method="POST" id="category-form">
                <input type="hidden" name="action" value="add_category">

                <div class="form-group">
                    <label for="cat_name">Nome da Categoria</label>
                    <input type="text" id="cat_name" name="name" class="form-control" placeholder="Ex: VIVO, TIM, CLARO">
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label for="cat_status">Status</label>
                        <select id="cat_status" name="status" class="form-control">
                            <option value="ACTIVE" selected>ATIVO</option>
                            <option value="INACTIVE">INATIVO</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="cat_sorter">Ordem</label>
                        <input type="number" id="cat_sorter" name="sorter" class="form-control" placeholder="<?php echo count($existingCategories) + 1; ?>" value="<?php echo count($existingCategories) + 1; ?>">
                            </div>
                        </div>

                <div class="form-group">
                    <label for="cat_color">Cor da Categoria</label>
                    <input type="color" id="cat_color" name="color" class="form-control color-input" value="#80E122">
                </div>

                <button type="submit" class="btn">➕ Adicionar Categoria</button>
            </form>
        </div>
    </div>

    <div class="floating-action" onclick="window.scrollTo({top: 0, behavior: 'smooth'})">
        ↑
    </div>

    <script>
        function switchTab(tabName) {
            // Remove active class from all tabs and contents
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            
            // Add active class to clicked tab and corresponding content
            event.target.classList.add('active');
            document.getElementById(tabName + '-tab').classList.add('active');
            
            // Update URL without reload
            const url = new URL(window.location);
            url.searchParams.set('tab', tabName);
            window.history.pushState({}, '', url);
        }

        function toggleCollapsible(element) {
            const collapsible = element.parentElement;
            collapsible.classList.toggle('active');
        }

        // Form validation and enhancement
        document.getElementById('config-form').addEventListener('submit', function(e) {
            // Add loading state
            const submitBtn = this.querySelector('button[type="submit"]');
            const originalText = submitBtn.textContent;
            submitBtn.textContent = '⏳ Adicionando...';
            submitBtn.disabled = true;
        });

        document.getElementById('category-form').addEventListener('submit', function(e) {
            // Add loading state
            const submitBtn = this.querySelector('button[type="submit"]');
            const originalText = submitBtn.textContent;
            submitBtn.textContent = '⏳ Adicionando...';
            submitBtn.disabled = true;
        });

        // Show/hide fields based on mode selection
        document.querySelectorAll('input[name="mode"]').forEach(radio => {
            radio.addEventListener('change', function() {
                console.log('Mode changed to:', this.value);
            });
        });

        // Auto-clear form after successful submission
        <?php if (isset($_GET["success"])): ?>
        setTimeout(() => {
            if (confirm('Operação realizada com sucesso! Deseja limpar o formulário para adicionar uma nova?')) {
                document.querySelector('form').reset();
                // Reset order field to next number
                const orderField = document.querySelector('#sorter');
                if (orderField) {
                    orderField.value = parseInt(orderField.placeholder);
                }
                const catOrderField = document.querySelector('#cat_sorter');
                if (catOrderField) {
                    catOrderField.value = parseInt(catOrderField.placeholder);
                }
            }
        }, 1000);
        <?php endif; ?>
    </script>
</body>
</html>
