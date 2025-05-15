#include <iostream>
#include <boost/asio.hpp>
#include <boost/asio/ssl.hpp>
#include <sqlite3.h>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <system_error>
#include <chrono>
#include <thread>
#include <map>

using namespace boost::asio;
using namespace boost::asio::ip;
using namespace boost::asio::ssl;
using namespace std;

// Contexto SSL
using ssl_socket = ssl::stream<tcp::socket>;
ssl::context ssl_ctx(ssl::context::sslv23);
int active_port = 8443; // Porta padrão

// Função para obter o IP do servidor
string getServerIP(io_context& io_context) {
    try {
        tcp::resolver resolver(io_context);
        tcp::resolver::results_type endpoints = resolver.resolve(tcp::v4(), "localhost", "0");
        for (const auto& endpoint : endpoints) {
            auto ip = endpoint.endpoint().address().to_string();
            if (ip != "127.0.0.1" && ip.find(":") == string::npos) { // Evita localhost e IPv6
                return ip;
            }
        }
    } catch (const std::exception& e) {
        cerr << "Erro ao obter IP: " << e.what() << endl;
    }
    return "localhost"; // Fallback
}

// Funções de gerenciamento SSH
void criarUsuario(const string& nome, const string& senha, int validade, int limite) {
    string cmd = "useradd -m -s /bin/bash " + nome + " && echo '" + nome + ":" + senha + "' | chpasswd";
    system(cmd.c_str());
    auto expTime = chrono::system_clock::to_time_t(chrono::system_clock::now() + chrono::hours(validade * 24));
    string expDate = string(ctime(&expTime));
    expDate = expDate.substr(0, expDate.length() - 1);
    system(("chage -E " + expDate + " " + nome).c_str());
    ofstream limits("/etc/security/limits.conf", ios::app);
    limits << nome << " - maxlogins " << limite << endl;
    limits.close();
}

void removerUsuario(const string& nome) {
    string cmd = "userdel -r " + nome;
    system(cmd.c_str());
}

void testeConexaoSSH(int minutos) {
    string nome = "temp_test_" + to_string(chrono::system_clock::now().time_since_epoch().count());
    string senha = "temp123";
    criarUsuario(nome, senha, minutos / 1440, 1);
    cout << "Usuário de teste criado: " << nome << "@" << system("hostname") << ", Senha: " << senha << endl;
    this_thread::sleep_for(chrono::seconds(minutos * 60));
    removerUsuario(nome);
}

void alterarLimite(const string& nome, int limite) {
    ifstream in("/etc/security/limits.conf");
    string line, newContent;
    bool found = false;
    while (getline(in, line)) {
        if (line.find(nome) != string::npos) {
            newContent += nome + " - maxlogins " + to_string(limite) + "\n";
            found = true;
        } else {
            newContent += line + "\n";
        }
    }
    in.close();
    if (!found) newContent += nome + " - maxlogins " + to_string(limite) + "\n";
    ofstream out("/etc/security/limits.conf");
    out << newContent;
    out.close();
    system("systemctl restart sshd");
}

void alterarValidade(const string& nome, int dias) {
    auto expTime = chrono::system_clock::to_time_t(chrono::system_clock::now() + chrono::hours(dias * 24));
    string expDate = string(ctime(&expTime));
    expDate = expDate.substr(0, expDate.length() - 1);
    system(("chage -E " + expDate + " " + nome).c_str());
}

void alterarSenha(const string& nome, const string& senha) {
    string cmd = "echo '" + nome + ":" + senha + "' | chpasswd";
    system(cmd.c_str());
}

string listarUsuarios() {
    string result = "Usuários: ";
    system("getent passwd | grep /bin/bash > temp_users.txt");
    ifstream file("temp_users.txt");
    string line;
    while (getline(file, line)) {
        string username = line.substr(0, line.find(":"));
        result += username + ", ";
    }
    file.close();
    system("rm temp_users.txt");
    return result.substr(0, result.length() - 2) + "\n";
}

string listarExpirados() {
    string result = "Usuários expirados: ";
    system("getent passwd | grep /bin/bash > temp_users.txt");
    ifstream file("temp_users.txt");
    string line;
    while (getline(file, line)) {
        string username = line.substr(0, line.find(":"));
        FILE* pipe = popen(("chage -l " + username + " | grep 'Account expires'").c_str(), "r");
        char buffer[128];
        string exp;
        while (fgets(buffer, sizeof(buffer), pipe)) exp += buffer;
        pclose(pipe);
        if (exp.find("expired") != string::npos) result += username + ", ";
    }
    file.close();
    system("rm temp_users.txt");
    return result.substr(0, result.length() - 2) + "\n";
}

string listarOnline() {
    string result = "Usuários online: ";
    system("who > temp_online.txt");
    ifstream file("temp_online.txt");
    string line;
    while (getline(file, line)) {
        string username = line.substr(0, line.find(" "));
        result += username + " (IP: " + line.substr(line.find("(") + 1, line.find(")") - line.find("(") - 1) + "), ";
    }
    file.close();
    system("rm temp_online.txt");
    return result.substr(0, result.length() - 2) + "\n";
}

string dadosUsuario(const string& nome) {
    string result = "Usuário: " + nome + "\n";
    string cmd = "chage -l " + nome + " | grep 'Account expires'";
    system((cmd + " > temp_data.txt").c_str());
    ifstream file("temp_data.txt");
    string line;
    if (getline(file, line)) result += "Validade: " + line.substr(line.find(":") + 2) + "\n";
    file.close();
    system("rm temp_data.txt");
    system(("grep " + nome + " /etc/security/limits.conf > temp_limit.txt").c_str());
    ifstream limitFile("temp_limit.txt");
    if (getline(limitFile, line)) result += "Limite: " + line.substr(line.find("maxlogins") + 9) + "\n";
    limitFile.close();
    system("rm temp_limit.txt");
    string online = system(("who | grep " + nome + " > /dev/null && echo 'Online' || echo 'Offline'").c_str()) ? "Offline" : "Online";
    result += "Status: " + online + "\n";
    return result;
}

// Funções de proxy e modos de conexão
map<string, int> conexoesAtivas = {{"Direct", 0}, {"DirectNoPayload", 0}, {"WebSocket", 0}, {"Security", 0}, {"SOCKS", 0}, {"SSLDirect", 0}, {"SSLPay", 0}};

void handleDirect(ssl_socket& socket) {
    conexoesAtivas["Direct"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec) socket.write_some(buffer("Direct OK", 9), ec);
    conexoesAtivas["Direct"]--;
}

void handleDirectNoPayload(ssl_socket& socket) {
    conexoesAtivas["DirectNoPayload"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec) socket.write_some(buffer("DirectNoPayload OK", 18), ec);
    conexoesAtivas["DirectNoPayload"]--;
}

void handleWebSocket(ssl_socket& socket) {
    conexoesAtivas["WebSocket"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec && string(data, len).find("Upgrade: websocket") != string::npos) {
        socket.write_some(buffer("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n", 74), ec);
    }
    conexoesAtivas["WebSocket"]--;
}

void handleSecurity(ssl_socket& socket) {
    conexoesAtivas["Security"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec && string(data, len).find("user:pass") != string::npos) {
        socket.write_some(buffer("Security OK", 11), ec);
    }
    conexoesAtivas["Security"]--;
}

void handleSOCKS(ssl_socket& socket) {
    conexoesAtivas["SOCKS"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec && data[0] == 0x05) {
        socket.write_some(buffer("\x05\x00", 2), ec); // Resposta SOCKS5
    }
    conexoesAtivas["SOCKS"]--;
}

void handleSSLDirect(ssl_socket& socket) {
    conexoesAtivas["SSLDirect"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec) socket.write_some(buffer("SSLDirect OK", 11), ec);
    conexoesAtivas["SSLDirect"]--;
}

void handleSSLPay(ssl_socket& socket) {
    conexoesAtivas["SSLPay"]++;
    boost::system::error_code ec;
    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (!ec && string(data, len).find("PAYLOAD") != string::npos) {
        socket.write_some(buffer("SSLPay OK", 9), ec);
    }
    conexoesAtivas["SSLPay"]--;
}

void handleConnection(ssl_socket socket) {
    boost::system::error_code ec;
    socket.handshake(ssl_socket::server, ec);
    if (ec) return;

    char data[1024];
    size_t len = socket.read_some(buffer(data), ec);
    if (ec) return;

    string request(data, len);
    if (request.find("Upgrade: websocket") != string::npos) {
        handleWebSocket(socket);
    } else if (request.find("user:pass") != string::npos) {
        handleSecurity(socket);
    } else if (request[0] == 0x05) {
        handleSOCKS(socket);
    } else if (request.find("NOPAYLOAD") != string::npos) {
        handleDirectNoPayload(socket);
    } else if (request.find("PAYLOAD") != string::npos) {
        handleSSLPay(socket);
    } else {
        handleDirect(socket);
        handleSSLDirect(socket); // Ambos podem coexistir
    }
}

void iniciarProxy(io_context& io_context, int porta) {
    ssl_ctx.use_certificate_file("/etc/ssl/certs/server.crt", ssl::context::pem);
    ssl_ctx.use_private_key_file("/etc/ssl/certs/server.key", ssl::context::pem);

    tcp::acceptor acceptor(io_context, tcp::endpoint(tcp::v4(), porta));
    cout << "Proxy iniciado na porta " << porta << " em " << chrono::system_clock::to_time_t(chrono::system_clock::now()) << endl;

    while (true) {
        ssl_socket socket(io_context, ssl_ctx);
        acceptor.accept(socket.lowest_layer());
        thread(handleConnection, move(socket)).detach();
    }
}

void verificarStatusProxy() {
    system("systemctl status sslh || echo 'sslh não encontrado'");
}

void reiniciarProxy() {
    system("systemctl restart sslh || echo 'Erro ao reiniciar sslh'");
}

string listarConexoes() {
    ostringstream oss;
    oss << "Conexões ativas em " << active_port << ":\n";
    for (const auto& [modo, count] : conexoesAtivas) {
        oss << modo << ": " << count << "\n";
    }
    return oss.str();
}

void escolherPorta(io_context& io_context, int porta) {
    if (porta == 80 || porta == 443 || porta == 8080) {
        active_port = porta;
        string server_ip = getServerIP(io_context); // Obtém o IP dinamicamente
        ofstream config("/etc/nginx/sites-available/anyvpn", ios::out);
        config << "server {\n"
               << "    listen " << porta << " ssl;\n"
               << "    server_name " << server_ip << ";\n"
               << "    ssl_certificate /etc/ssl/certs/server.crt;\n"
               << "    ssl_certificate_key /etc/ssl/certs/server.key;\n"
               << "    location /direct { proxy_pass http://localhost:8443; }\n"
               << "    location /directnopayload { proxy_pass http://localhost:8443; }\n"
               << "    location /websocket { proxy_pass http://localhost:8080; }\n"
               << "    location /security { proxy_pass http://localhost:8443; }\n"
               << "    location /socks { proxy_pass http://localhost:7300; }\n"
               << "    location /ssldirect { proxy_pass https://localhost:8443; }\n"
               << "    location /sslpay { proxy_pass https://localhost:8443; }\n"
               << "}";
        config.close();
        system("sudo ln -sf /etc/nginx/sites-available/anyvpn /etc/nginx/sites-enabled/ && sudo nginx -t && sudo systemctl restart nginx");
        cout << "Porta alterada para " << porta << " com IP " << server_ip << endl;
    } else {
        cout << "Porta inválida. Use 80, 443 ou 8080." << endl;
    }
}

void fecharPorta(int porta) {
    if (porta == 80 || porta == 443 || porta == 8080) {
        system(("sudo sed -i '/listen " + to_string(porta) + "/d' /etc/nginx/sites-available/anyvpn && sudo nginx -t && sudo systemctl restart nginx").c_str());
        cout << "Porta " << porta << " fechada." << endl;
    } else {
        cout << "Porta inválida. Use 80, 443 ou 8080." << endl;
    }
}

void modosConexao(const vector<string>& modos) {
    string config = "Modos ativados na porta " + to_string(active_port) + ": ";
    for (const string& modo : modos) config += modo + ", ";
    cout << config.substr(0, config.length() - 2) << endl;
}

void historicoUDP() {
    sqlite3 *db;
    sqlite3_open("udp_history.db", &db);
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, "SELECT ip_origem, ip_destino, dados, timestamp FROM udp_sessions", -1, &stmt, nullptr);
    cout << "Histórico UDP:" << endl;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        cout << "IP Origem: " << sqlite3_column_text(stmt, 0) << ", IP Destino: " << sqlite3_column_text(stmt, 1)
             << ", Dados: " << sqlite3_column_text(stmt, 2) << " MB, Tempo: " << sqlite3_column_text(stmt, 3) << endl;
    }
    sqlite3_finalize(stmt);
    sqlite3_close(db);
}

void usoRecursos() {
    system("top -bn1 | grep 'Cpu(s)' > temp_cpu.txt");
    system("free -h | grep 'Mem:' > temp_mem.txt");
    ifstream cpuFile("temp_cpu.txt"), memFile("temp_mem.txt");
    string cpuLine, memLine;
    getline(cpuFile, cpuLine); getline(memFile, memLine);
    cpuFile.close(); memFile.close();
    system("rm temp_cpu.txt temp_mem.txt");
    cout << "CPU: " << cpuLine << endl << "Memória: " << memLine << endl;
}

void logsGerais() {
    system("cat /var/log/syslog | tail -n 10");
}

void ativarBot(const string& token, const string& chatId) {
    ofstream status("bot_status.txt");
    status << "ativo " << token << " " << chatId;
    status.close();
    system("python3 bot_telegram.py &");
}

void desativarBot() {
    ofstream status("bot_status.txt");
    status << "desativado";
    status.close();
    system("pkill -f bot_telegram.py");
}

string processarComandoTelegram(const string& comando) {
    vector<string> args;
    string arg;
    stringstream ss(comando);
    while (ss >> arg) args.push_back(arg);

    ofstream respFile("bot_response.txt");
    if (args[0] == "/criarusuario" && args.size() == 5) {
        criarUsuario(args[1], args[2], stoi(args[3]), stoi(args[4]));
        respFile << "Usuário " << args[1] << " criado com sucesso!";
    } else if (args[0] == "/removerusuario" && args.size() == 2) {
        removerUsuario(args[1]);
        respFile << "Usuário " << args[1] << " removido ou erro reportado.";
    } else if (args[0] == "/testessh" && args.size() == 2) {
        testeConexaoSSH(stoi(args[1]));
        respFile << "Teste SSH iniciado por " << args[1] << " minutos.";
    } else if (args[0] == "/alterarlimite" && args.size() == 3) {
        alterarLimite(args[1], stoi(args[2]));
        respFile << "Limite de " << args[1] << " alterado.";
    } else if (args[0] == "/alterarvalidade" && args.size() == 3) {
        alterarValidade(args[1], stoi(args[2]));
        respFile << "Validade de " << args[1] << " alterada.";
    } else if (args[0] == "/alterarsenha" && args.size() == 3) {
        alterarSenha(args[1], args[2]);
        respFile << "Senha de " << args[1] << " alterada.";
    } else if (args[0] == "/listarusuarios") {
        respFile << listarUsuarios();
    } else if (args[0] == "/listarexpirados") {
        respFile << listarExpirados();
    } else if (args[0] == "/listaronline") {
        respFile << listarOnline();
    } else if (args[0] == "/dadosusuario" && args.size() == 2) {
        respFile << dadosUsuario(args[1]);
    } else if (args[0] == "/statusproxy") {
        string result = system("systemctl status sslh 2>&1") ? "sslh não encontrado" : "Proxy ativo";
        respFile << result;
    } else if (args[0] == "/reiniciarproxy") {
        reiniciarProxy();
        respFile << "Proxy reiniciado.";
    } else if (args[0] == "/listarconexoes") {
        respFile << listarConexoes();
    } else if (args[0] == "/escolherporta" && args.size() == 2) {
        escolherPorta(io_context, stoi(args[1]));
        respFile << "Porta alterada para " << args[1] << ".";
    } else if (args[0] == "/fecharporta" && args.size() == 2) {
        fecharPorta(stoi(args[1]));
        respFile << "Porta " << args[1] << " fechada.";
    } else if (args[0] == "/modosconexao") {
        vector<string> modos = {"Direct", "DirectNoPayload", "WebSocket", "Security", "SOCKS", "SSLDirect", "SSLPay"};
        modosConexao(modos);
        respFile << "Modos configurados na porta " << active_port << ".";
    } else if (args[0] == "/historicoudp") {
        ostringstream oss;
        sqlite3 *db;
        sqlite3_open("udp_history.db", &db);
        sqlite3_stmt *stmt;
        sqlite3_prepare_v2(db, "SELECT ip_origem, ip_destino, dados, timestamp FROM udp_sessions", -1, &stmt, nullptr);
        oss << "Histórico UDP:\n";
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            oss << "IP Origem: " << sqlite3_column_text(stmt, 0) << ", IP Destino: " << sqlite3_column_text(stmt, 1)
                << ", Dados: " << sqlite3_column_text(stmt, 2) << " MB, Tempo: " << sqlite3_column_text(stmt, 3) << "\n";
        }
        sqlite3_finalize(stmt);
        sqlite3_close(db);
        respFile << oss.str();
    } else if (args[0] == "/usorecursos") {
        ostringstream oss;
        system("top -bn1 | grep 'Cpu(s)' > temp_cpu.txt");
        system("free -h | grep 'Mem:' > temp_mem.txt");
        ifstream cpuFile("temp_cpu.txt"), memFile("temp_mem.txt");
        string cpuLine, memLine;
        getline(cpuFile, cpuLine); getline(memFile, memLine);
        cpuFile.close(); memFile.close();
        system("rm temp_cpu.txt temp_mem.txt");
        oss << "CPU: " << cpuLine << "\nMemória: " << memLine;
        respFile << oss.str();
    } else if (args[0] == "/logsgerais") {
        system("cat /var/log/syslog | tail -n 10 > temp_logs.txt");
        ifstream logFile("temp_logs.txt");
        string logContent((istreambuf_iterator<char>(logFile)), istreambuf_iterator<char>());
        logFile.close();
        system("rm temp_logs.txt");
        respFile << "Logs gerais:\n" << logContent;
    } else {
        respFile << "Comando inválido!";
    }
    respFile.close();
    return "";
}

void mostrarMenu(io_context& io_context) {
    while (true) {
        auto now = chrono::system_clock::now();
        time_t tt = chrono::system_clock::to_time_t(now);
        string timeStr = ctime(&tt);
        timeStr = timeStr.substr(0, timeStr.length() - 1) + " -03";

        cout << "\n=== Sistema de Gerenciamento de Rede ANYVPN - " << timeStr << " ===\n";
        cout << "1. Gerenciar Usuários SSH\n"
             << "   1.1 Criar novo usuário\n"
             << "   1.2 Remover usuário\n"
             << "   1.3 Teste de conexão SSH\n"
             << "   1.4 Alterar limite de conexões\n"
             << "   1.5 Alterar validade\n"
             << "   1.6 Alterar senha\n"
             << "   1.7 Listar todos os usuários\n"
             << "   1.8 Listar usuários expirados\n"
             << "   1.9 Listar usuários online\n"
             << "   1.10 Dados de um usuário\n"
             << "2. Gerenciar Conexões\n"
             << "   2.1 Ver status do proxy\n"
             << "   2.2 Reiniciar proxy\n"
             << "   2.3 Listar conexões ativas\n"
             << "   2.4 Escolher porta dos serviços (80, 443, 8080)\n"
             << "   2.5 Fechar porta (80, 443, 8080)\n"
             << "   2.6 Modos de conexão\n"
             << "3. Informações do Sistema\n"
             << "   3.1 Histórico UDP (Badvpn)\n"
             << "   3.2 Uso de recursos (CPU, RAM)\n"
             << "   3.3 Logs gerais\n"
             << "4. Bot Telegram\n"
             << "   4.1 Ativar bot\n"
             << "   4.2 Desativar bot\n"
             << "   4.3 Configurar token e chat_id\n"
             << "5. Sair\n"
             << "Escolha uma opção (1-5): ";
        string opcao;
        getline(cin, opcao);

        if (opcao == "1.1") {
            string nome, senha; int validade, limite;
            cout << "Nome: "; getline(cin, nome);
            cout << "Senha: "; getline(cin, senha);
            cout << "Validade (dias): "; cin >> validade;
            cout << "Limite: "; cin >> limite; cin.ignore();
            criarUsuario(nome, senha, validade, limite);
        } else if (opcao == "1.2") {
            string nome; cout << "Nome: "; getline(cin, nome);
            removerUsuario(nome);
        } else if (opcao == "1.3") {
            int minutos; cout << "Minutos: "; cin >> minutos; cin.ignore();
            testeConexaoSSH(minutos);
        } else if (opcao == "1.4") {
            string nome; int limite;
            cout << "Nome: "; getline(cin, nome);
            cout << "Limite: "; cin >> limite; cin.ignore();
            alterarLimite(nome, limite);
        } else if (opcao == "1.5") {
            string nome; int dias;
            cout << "Nome: "; getline(cin, nome);
            cout << "Dias: "; cin >> dias; cin.ignore();
            alterarValidade(nome, dias);
        } else if (opcao == "1.6") {
            string nome, senha;
            cout << "Nome: "; getline(cin, nome);
            cout << "Nova senha: "; getline(cin, senha);
            alterarSenha(nome, senha);
        } else if (opcao == "1.7") {
            cout << listarUsuarios();
        } else if (opcao == "1.8") {
            cout << listarExpirados();
        } else if (opcao == "1.9") {
            cout << listarOnline();
        } else if (opcao == "1.10") {
            string nome; cout << "Nome: "; getline(cin, nome);
            cout << dadosUsuario(nome);
        } else if (opcao == "2.1") {
            verificarStatusProxy();
        } else if (opcao == "2.2") {
            reiniciarProxy();
        } else if (opcao == "2.3") {
            cout << listarConexoes();
        } else if (opcao == "2.4") {
            int porta; cout << "Escolha a porta (80, 443, 8080): "; cin >> porta; cin.ignore();
            escolherPorta(io_context, porta);
        } else if (opcao == "2.5") {
            int porta; cout << "Escolha a porta para fechar (80, 443, 8080): "; cin >> porta; cin.ignore();
            fecharPorta(porta);
        } else if (opcao == "2.6") {
            vector<string> modos = {"Direct", "DirectNoPayload", "WebSocket", "Security", "SOCKS", "SSLDirect", "SSLPay"};
            modosConexao(modos);
        } else if (opcao == "3.1") {
            historicoUDP();
        } else if (opcao == "3.2") {
            usoRecursos();
        } else if (opcao == "3.3") {
            logsGerais();
        } else if (opcao == "4.1") {
            string token, chatId;
            cout << "Token: "; getline(cin, token);
            cout << "Chat ID: "; getline(cin, chatId);
            ativarBot(token, chatId);
        } else if (opcao == "4.2" || opcao == "4.3") {
            string token, chatId;
            cout << "Token: "; getline(cin, token);
            cout << "Chat ID: "; getline(cin, chatId);
            ofstream status("bot_status.txt");
            status << "ativo " << token << " " << chatId;
            status.close();
            cout << "Configuração salva!" << endl;
        } else if (opcao == "5") {
            break;
        }
    }
}

int main() {
    io_context io_context;
    sqlite3 *db;
    sqlite3_open("udp_history.db", &db);
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS udp_sessions (ip_origem TEXT, ip_destino TEXT, dados TEXT, timestamp TEXT)", nullptr, nullptr, nullptr);
    sqlite3_close(db);

    thread proxyThread(iniciarProxy, ref(io_context), 8444); // Usa porta interna 8444
    proxyThread.detach();

    mostrarMenu(io_context);

    return 0;
}