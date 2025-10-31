#!/usr/bin/python3
# -*- coding: utf-8 -*-

import subprocess
import os
import re
from datetime import datetime, timedelta
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
    ConversationHandler,
    MessageHandler,
    filters,
)
from telegram.constants import ParseMode
from telegram.error import BadRequest

# ==========================================================
#               CONFIGURAÇÃO INICIAL
# ==========================================================
# ATENÇÃO: Substitua os valores abaixo pelo seu token e seu ID
TELEGRAM_TOKEN = "SEU_TOKEN_AQUI"
ADMIN_USER_ID = 123456789  # SEU ID NUMÉRICO DO TELEGRAM
# ==========================================================


# --- Definição dos Estados para as Conversas ---
(
    # Usuário normal
    GET_USER_USERNAME, GET_USER_PASSWORD, GET_USER_DAYS, GET_USER_LIMIT,
    # Usuário de teste
    GET_TEST_USERNAME, GET_TEST_PASSWORD, GET_TEST_LIMIT, GET_TEST_DURATION,
    # Deleção
    GET_USER_TO_DELETE, CONFIRM_DELETE_USER, CONFIRM_DELETE_ALL,
    # Backup
    BACKUP_OPTIONS, CONFIRM_GENERATE_LINK, CONFIRM_RESTORE,
    # Menu Principal de Conexão
    CONNECTION_MENU,
    # WebSocket
    WEBSOCKET_MENU, GET_WS_PORT, GET_WS_MODE, GET_WS_MSG, CONFIRM_UNINSTALL_WS,
    # Rusty Proxy
    RUSTY_MENU, GET_RUSTY_ADD_PORT, GET_RUSTY_ADD_STATUS, GET_RUSTY_DEL_PORT, CONFIRM_UNINSTALL_RUSTY,
    # Stunnel
    STUNNEL_MENU, STUNNEL_INSTALL_MODE, GET_STUNNEL_INSTALL_PORT, STUNNEL_MANAGE_MENU, GET_STUNNEL_CHANGE_PORT, CONFIRM_UNINSTALL_STUNNEL,
    # BadVPN
    BADVPN_MENU, GET_BADVPN_NEW_PORT,
    # Dragon Proxy
    DRAGON_MENU, GET_DRAGON_ADD_PORT, GET_DRAGON_STOP_PORT, GET_DRAGON_RESTART_PORT, CONFIRM_UNINSTALL_DRAGON,
    # SlowDNS
    SLOWDNS_MENU, SLOWDNS_INSTALL_MODE, GET_SLOWDNS_NS, GET_SLOWDNS_KEY_CHOICE, CONFIRM_UNINSTALL_SLOWDNS
) = range(46)


# --- Constantes de Caminhos ---
WEBSOCKET_BIN = "/usr/local/bin/WebSocket"
RUSTY_PORTS_FILE = "/opt/rustyproxy/ports"
DRAGON_INSTALL_DIR = "/root/DragonX"
DRAGON_PORTS_FILE = f"{DRAGON_INSTALL_DIR}/ports.list"


# --- Funções Auxiliares ---

def execute_shell_command(command, input_text=None):
    """Executa um comando de shell e retorna sua saída."""
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, check=False, input=input_text, shell=True
        )
        return result.stdout.strip()
    except Exception:
        return ""

async def cleanup_last_message(context: ContextTypes.DEFAULT_TYPE, message_id_to_keep=None):
    """Apaga a última mensagem enviada pelo bot para manter o chat limpo."""
    chat_id = context.chat_data.get('chat_id')
    last_message_id = context.chat_data.get('last_message_id')
    
    if chat_id and last_message_id and last_message_id != message_id_to_keep:
        try:
            await context.bot.delete_message(chat_id=chat_id, message_id=last_message_id)
        except BadRequest:
            pass

async def is_admin(update: Update) -> bool:
    """Verifica se o usuário é o administrador do bot."""
    user_id = update.effective_user.id
    if user_id != ADMIN_USER_ID:
        if update.callback_query:
            await update.callback_query.answer("❌ Acesso negado.", show_alert=True)
        else:
            await update.message.reply_text("❌ Acesso negado.")
        return False
    return True

async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Cancela a operação atual e retorna ao menu principal."""
    await update.message.reply_text('Operação cancelada.')
    await menu_command(update, context)
    return ConversationHandler.END


# --- Funções do Menu Principal (Relatórios, etc.) ---

async def user_info_report(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Gera e envia um relatório completo dos usuários SSH."""
    if not await is_admin(update): return
    query = update.callback_query
    await query.answer()
    await cleanup_last_message(context)
    sent_message = await query.message.reply_text("⚙️ Gerando relatório de usuários...")
    context.chat_data.update({'last_message_id': sent_message.message_id, 'chat_id': sent_message.chat_id})

    users_raw = execute_shell_command("awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -v 'nobody'")
    users = users_raw.splitlines()

    report = "👤 *Relatório de Usuários SSH*\n\n"
    report += "`{:<15} {:<13} {:<7} {:<10}`\n".format("Usuário", "Senha", "Limite", "Validade")
    report += "`" + "="*49 + "`\n"
    for user in users:
        limite = execute_shell_command(f"grep -w {user} /root/usuarios.db | cut -d' ' -f2") or "1"
        senha = execute_shell_command(f"cat /etc/SSHPlus/senha/{user}") or "N/A"
        validade_raw = execute_shell_command(f"chage -l {user} | grep -i 'Account expires' | awk -F: '{{print $2}}'").strip()
        if not validade_raw or "never" in validade_raw:
            validade = "Nunca"
        else:
            try:
                exp_date = datetime.strptime(validade_raw, '%b %d, %Y')
                today = datetime.now()
                validade = "Venceu" if exp_date < today else f"{(exp_date - today).days} dias"
            except ValueError:
                validade = "N/A"
        report += "`{:<15} {:<13} {:<7} {:<10}`\n".format(user[:14], senha[:12], limite[:6], validade[:9])
    
    report += "`" + "="*49 + "`\n\n"
    total_users = len(users)
    online_users = execute_shell_command("ps -x | grep sshd | grep -v root | grep priv | wc -l")
    report += f"👥 *Total:* {total_users} | 🟢 *Online:* {online_users}"

    await query.edit_message_text(report, parse_mode=ParseMode.MARKDOWN)
    context.chat_data['last_message_id'] = query.message.message_id


async def online_users_monitor(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Mostra os usuários online usando o script sshmonitor."""
    if not await is_admin(update): return
    query = update.callback_query
    await query.answer()
    await cleanup_last_message(context)
    sent_message = await query.message.reply_text("⚙️ Verificando usuários online...")
    context.chat_data.update({'last_message_id': sent_message.message_id, 'chat_id': sent_message.chat_id})
    
    raw_output = execute_shell_command("/usr/bin/sshmonitor")
    clean_output = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', raw_output)
    final_message = f"📊 *Monitor de Usuários Online*\n\n```\n{clean_output or 'Nenhum usuário online.'}\n```"
    
    await query.edit_message_text(final_message, parse_mode=ParseMode.MARKDOWN)
    context.chat_data['last_message_id'] = query.message.message_id


# --- Seção: Criação de Usuário ---

async def start_create_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.edit_message_text("Qual o nome do novo usuário?")
    context.chat_data['last_message_id'] = query.message.message_id
    return GET_USER_USERNAME

async def get_user_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context)
    username = update.message.text.strip()
    if not username or not username.isalnum() or len(username) < 2 or len(username) > 10:
        sent = await update.message.reply_text("Nome inválido (use 2-10 letras/números). Tente novamente.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_USER_USERNAME
    if execute_shell_command(f"id -u {username}"):
        sent = await update.message.reply_text("❌ Este usuário já existe. Tente outro nome.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_USER_USERNAME
    context.user_data['user_username'] = username
    sent = await update.message.reply_text("Ótimo. Agora, qual a senha (mínimo 4 caracteres)?")
    context.chat_data['last_message_id'] = sent.message_id
    return GET_USER_PASSWORD

async def get_user_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context)
    password = update.message.text.strip()
    if not password or len(password) < 4:
        sent = await update.message.reply_text("Senha inválida (mínimo 4 caracteres). Tente novamente.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_USER_PASSWORD
    context.user_data['user_password'] = password
    sent = await update.message.reply_text("Por quantos dias a conta será válida?")
    context.chat_data['last_message_id'] = sent.message_id
    return GET_USER_DAYS

async def get_user_days(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context)
    days = update.message.text.strip()
    if not days.isdigit() or int(days) < 1:
        sent = await update.message.reply_text("Número de dias inválido. Insira um número maior que 0.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_USER_DAYS
    context.user_data['user_days'] = days
    sent = await update.message.reply_text("Qual o limite de conexões simultâneas?")
    context.chat_data['last_message_id'] = sent.message_id
    return GET_USER_LIMIT

async def get_user_limit_and_create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context)
    limit = update.message.text.strip()
    if not limit.isdigit() or int(limit) < 1:
        sent = await update.message.reply_text("Limite inválido. Insira um número maior que 0.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_USER_LIMIT

    sent = await update.message.reply_text("⚙️ Processando... Criando usuário.")
    context.chat_data['last_message_id'] = sent.message_id
    
    nome = context.user_data['user_username']
    pasw = context.user_data['user_password']
    dias = int(context.user_data['user_days'])
    
    data_final = (datetime.now() + timedelta(days=dias)).strftime('%Y-%m-%d')
    execute_shell_command(f"useradd -M -s /bin/false -e {data_final} {nome}")
    execute_shell_command(f'echo "{nome}:{pasw}" | chpasswd')
    os.makedirs("/etc/SSHPlus/senha", exist_ok=True)
    with open(f"/etc/SSHPlus/senha/{nome}", "w") as f: f.write(pasw)
    with open("/root/usuarios.db", "a") as f: f.write(f"{nome} {limit}\n")

    ip_servidor = execute_shell_command("wget -qO- ifconfig.me")
    gui_data = (datetime.now() + timedelta(days=dias)).strftime('%d/%m/%Y')
    success_message = (f"✅ *Conta SSH Criada!*\n\n"
                       f"🌐 *IP:* `{ip_servidor}`\n👤 *Usuário:* `{nome}`\n🔑 *Senha:* `{pasw}`\n"
                       f"📶 *Limite:* `{limit}`\n⏳ *Expira em:* `{gui_data}` ({dias} dias)")
    
    await sent.edit_text(success_message, parse_mode=ParseMode.MARKDOWN)
    await menu_command(update, context, is_follow_up=True)
    return ConversationHandler.END


# --- Seção: Remoção de Usuário ---

async def start_delete_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    users_raw = execute_shell_command("awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -v 'nobody'")
    users = users_raw.splitlines()

    if not users:
        await query.edit_message_text("Não há usuários para remover.")
        await menu_command(update, context) # Retorna ao menu principal
        return ConversationHandler.END
    
    keyboard = [[InlineKeyboardButton(user, callback_data=f"del_{user}")] for user in users]
    keyboard.append([InlineKeyboardButton("❌ REMOVER TODOS ❌", callback_data="del_all")])
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data="back_to_main")])
    
    await query.edit_message_text("Selecione o usuário para remover:", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_USER_TO_DELETE

async def get_user_to_delete(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    user_to_delete = query.data.split('_', 1)[1]

    context.user_data['user_to_delete'] = user_to_delete
    keyboard = [
        [InlineKeyboardButton(f"Sim, deletar {user_to_delete}", callback_data="confirm_delete_user")],
        [InlineKeyboardButton("Não, cancelar", callback_data="back_to_main")]
    ]
    await query.edit_message_text(f"Tem certeza que deseja deletar o usuário *{user_to_delete}*?", 
                                  reply_markup=InlineKeyboardMarkup(keyboard),
                                  parse_mode=ParseMode.MARKDOWN)
    return CONFIRM_DELETE_USER

async def confirm_delete_single_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    user = context.user_data['user_to_delete']
    
    execute_shell_command(f"userdel -f {user}")
    execute_shell_command(f"sed -i '/^{user} /d' /root/usuarios.db")
    
    await query.edit_message_text(f"✅ Usuário *{user}* removido com sucesso!", parse_mode=ParseMode.MARKDOWN)
    await menu_command(update, context)
    return ConversationHandler.END

async def confirm_delete_all_users_prompt(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    keyboard = [
        [InlineKeyboardButton("SIM, TENHO CERTEZA ABSOLUTA", callback_data="confirm_delete_all")],
        [InlineKeyboardButton("NÃO, FOI UM ENGANO", callback_data="back_to_main")]
    ]
    await query.edit_message_text("⚠️ *ATENÇÃO*\n\nVocê está prestes a remover TODOS os usuários SSH criados. Esta ação é irreversível. Deseja continuar?",
                                  reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return CONFIRM_DELETE_ALL

async def execute_delete_all_users(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.edit_message_text("⚙️ Removendo todos os usuários...")
    
    users_raw = execute_shell_command("awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -v 'nobody'")
    users = users_raw.splitlines()
    for user in users:
        execute_shell_command(f"userdel -f {user}")
    # Limpa o banco de dados de usuários
    open("/root/usuarios.db", 'w').close()
    
    await query.edit_message_text("✅ Todos os usuários foram removidos com sucesso.")
    await menu_command(update, context)
    return ConversationHandler.END


# --- Seção: Menu de Conexão e Módulos ---

async def start_connection_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()

    ws_status = "✅" if "WebSocket" in execute_shell_command("ps x") else "❌"
    rusty_status = "✅" if os.path.exists(RUSTY_PORTS_FILE) and os.path.getsize(RUSTY_PORTS_FILE) > 0 else "❌"
    stunnel_status = "✅" if os.path.exists("/etc/stunnel/stunnel.conf") else "❌"
    badvpn_status = "✅" if "badvpn-udpgw" in execute_shell_command("ps x") else "❌"
    dragon_status = "✅" if os.path.exists(f"{DRAGON_INSTALL_DIR}/proxy.sh") else "❌"
    slowdns_status = "✅" if os.path.exists('/etc/slowdns/dns-server') else "❌"

    keyboard = [
        [InlineKeyboardButton(f"WebSocket {ws_status}", callback_data='conn_websocket'), InlineKeyboardButton(f"Rusty Proxy {rusty_status}", callback_data='conn_rusty')],
        [InlineKeyboardButton(f"SSL Tunnel {stunnel_status}", callback_data='conn_stunnel'), InlineKeyboardButton(f"BadVPN {badvpn_status}", callback_data='conn_badvpn')],
        [InlineKeyboardButton(f"Proxy Dragon {dragon_status}", callback_data='conn_dragon'), InlineKeyboardButton(f"SlowDNS {slowdns_status}", callback_data='conn_slowdns')],
        [InlineKeyboardButton("↩️ Voltar ao Menu Principal", callback_data='back_to_main')]
    ]
    await query.edit_message_text(
        text="🔌 *Menu de Conexão*\n\nSelecione um serviço para gerenciar:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return CONNECTION_MENU


# --- Módulo: WebSocket ---

def get_websocket_status():
    process_cmd = execute_shell_command(f"ps aux | grep '{WEBSOCKET_BIN}' | grep -v grep")
    if process_cmd:
        port_match = re.search(r'proxy_port \S+:(\d+)', process_cmd)
        port = port_match.group(1) if port_match else "N/A"
        mode = "TLS/SSL" if '-tls=true' in process_cmd else "Proxy"
        return "ATIVO", port, mode
    return "INATIVO", "N/A", "N/A"

async def start_websocket_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, port, mode = get_websocket_status()
    status_text = f"Status: 🟢 *{status}* | Porta: *{port}* | Modo: *{mode}*" if status == "ATIVO" else "Status: 🔴 *INATIVO*"

    keyboard = [
        [InlineKeyboardButton("🚀 Iniciar / Alterar", callback_data='ws_start')],
        [InlineKeyboardButton("🛑 Parar", callback_data='ws_stop'), InlineKeyboardButton("📥 Instalar / Atualizar", callback_data='ws_install')],
        [InlineKeyboardButton("🗑️ Desinstalar", callback_data='ws_uninstall')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.edit_message_text(
        text=f"🔌 *Gerenciador WebSocket*\n\n{status_text}\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return WEBSOCKET_MENU

async def websocket_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'ws_start':
        if not os.path.exists(WEBSOCKET_BIN):
            await query.message.reply_text("WebSocket não instalado. Por favor, instale primeiro.")
            return WEBSOCKET_MENU
        await query.edit_message_text("Digite a porta para o WebSocket (padrão: 80):")
        return GET_WS_PORT
        
    elif action == 'ws_stop':
        await query.edit_message_text("⚙️ Parando o serviço WebSocket...")
        execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit")
        await query.edit_message_text("✅ Serviço parado com sucesso!")
        return await start_websocket_menu(update, context)

    elif action == 'ws_install':
        await query.edit_message_text("⚙️ Instalando/Atualizando WebSocket...")
        execute_shell_command("apt-get update && apt-get install -y wget screen")
        execute_shell_command(f"wget -q -O {WEBSOCKET_BIN} --no-check-certificate https://gitea.com/alfalemos/SSHPLUS/raw/main/Modulos/WebSocket && chmod +x {WEBSOCKET_BIN}")
        if os.path.exists(WEBSOCKET_BIN):
            await query.edit_message_text("✅ WebSocket instalado/atualizado!")
        else:
            await query.edit_message_text("❌ Erro na instalação do WebSocket.")
        return await start_websocket_menu(update, context)

    elif action == 'ws_uninstall':
        keyboard = [[InlineKeyboardButton("Sim, tenho certeza", callback_data='ws_uninstall_confirm'), InlineKeyboardButton("Não, cancelar", callback_data='ws_cancel_uninstall')]]
        await query.edit_message_text("⚠️ Tem certeza que deseja remover o WebSocket?", reply_markup=InlineKeyboardMarkup(keyboard))
        return CONFIRM_UNINSTALL_WS
    
    elif action == 'back_to_connection_menu':
        return ConversationHandler.END # Retorna para o handler pai

    return WEBSOCKET_MENU

async def get_ws_port(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip() or "80"
    if not port.isdigit():
        await update.message.reply_text("Porta inválida. Tente novamente.")
        return GET_WS_PORT
    context.user_data['ws_port'] = port
    keyboard = [[InlineKeyboardButton("Proxy WS", callback_data='ws_mode_proxy'), InlineKeyboardButton("Proxy TLS/SSL", callback_data='ws_mode_tls')]]
    await update.message.reply_text("Escolha o modo de operação:", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_WS_MODE

async def get_ws_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    context.user_data['ws_mode'] = query.data
    await query.edit_message_text("Digite a mensagem de resposta (pressione Enter para usar o padrão):")
    return GET_WS_MSG

async def get_ws_msg_and_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    msg = update.message.text.strip() or "websocket-@alfalemos"
    port = context.user_data['ws_port']
    mode = context.user_data['ws_mode']
    
    await update.message.reply_text("⚙️ Iniciando o serviço WebSocket...")
    execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit")
    
    cmd = f"{WEBSOCKET_BIN} -proxy_port 0.0.0.0:{port} -msg='{msg}'"
    if mode == 'ws_mode_tls': cmd += " -tls=true"
    
    execute_shell_command(f"screen -dmS ws {cmd}")
    
    if "ws" in execute_shell_command("screen -list"):
        await update.message.reply_text("✅ Serviço WebSocket iniciado com sucesso!")
    else:
        await update.message.reply_text("❌ Erro ao iniciar o serviço WebSocket.")
    
    # Simula um clique para voltar ao menu
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_websocket_menu(fake_update, context)

async def confirm_uninstall_ws(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o WebSocket...")
    execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit; rm -f {WEBSOCKET_BIN}")
    await query.edit_message_text("✅ WebSocket desinstalado com sucesso.")
    return await start_websocket_menu(update, context)


# --- Módulo: Rusty Proxy --- (Toda a lógica está aqui)
def get_rusty_status():
    if os.path.exists("/opt/rustyproxy/proxyrust"):
        status = "Instalado"
        ports = "Nenhuma"
        if os.path.exists(RUSTY_PORTS_FILE) and os.path.getsize(RUSTY_PORTS_FILE) > 0:
            with open(RUSTY_PORTS_FILE, 'r') as f:
                ports = " ".join(f.read().splitlines())
    else:
        status = "Não Instalado"
        ports = "N/A"
    return status, ports

async def start_rusty_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, ports = get_rusty_status()
    status_text = f"Status: {status}\nPortas Ativas: {ports}"

    keyboard = [
        [InlineKeyboardButton("➕ Abrir Porta", callback_data='rusty_add'), InlineKeyboardButton("➖ Fechar Porta", callback_data='rusty_del')],
        [InlineKeyboardButton("📥 Instalar / Atualizar", callback_data='rusty_install')],
        [InlineKeyboardButton("🗑️ Desinstalar", callback_data='rusty_uninstall')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.edit_message_text(
        text=f"🦀 *Gerenciador Rusty Proxy*\n\n`{status_text}`\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return RUSTY_MENU

async def rusty_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'rusty_add':
        if not os.path.exists("/opt/rustyproxy/proxyrust"):
            await query.message.reply_text("Rusty Proxy não instalado.")
            return RUSTY_MENU
        await query.edit_message_text("Digite a porta a ser aberta:")
        return GET_RUSTY_ADD_PORT
    
    elif action == 'rusty_del':
        await query.edit_message_text("Digite a porta a ser fechada:")
        return GET_RUSTY_DEL_PORT
        
    elif action == 'rusty_install':
        await query.edit_message_text("⚙️ Instalando Rusty Proxy... Isso pode levar *vários minutos*. Por favor, aguarde.")
        output = execute_shell_command("proxyrust install")
        await query.edit_message_text(f"✅ *Resultado da Instalação:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
        return await start_rusty_menu(update, context)

    elif action == 'rusty_uninstall':
        keyboard = [[InlineKeyboardButton("Sim, tenho certeza", callback_data='rusty_uninstall_confirm'), InlineKeyboardButton("Não, cancelar", callback_data='rusty_cancel_uninstall')]]
        await query.edit_message_text("⚠️ Tem certeza que deseja remover o Rusty Proxy?", reply_markup=InlineKeyboardMarkup(keyboard))
        return CONFIRM_UNINSTALL_RUSTY
    
    elif action == 'back_to_connection_menu':
        return ConversationHandler.END

    return RUSTY_MENU

async def get_rusty_add_port(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit():
        await update.message.reply_text("Porta inválida. Tente novamente.")
        return GET_RUSTY_ADD_PORT
    context.user_data['rusty_port'] = port
    await update.message.reply_text("Digite o status de conexão (pressione Enter para o padrão):")
    return GET_RUSTY_ADD_STATUS

async def get_rusty_add_status_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    status = update.message.text.strip() or "@RustyProxy"
    port = context.user_data['rusty_port']
    await update.message.reply_text(f"⚙️ Abrindo a porta {port}...")
    output = execute_shell_command(f'proxyrust add "{port}" "{status}"')
    await update.message.reply_text(f"✅ *Resultado:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
    
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_rusty_menu(fake_update, context)

async def get_rusty_del_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return GET_RUSTY_DEL_PORT
    await update.message.reply_text(f"⚙️ Fechando a porta {port}...")
    output = execute_shell_command(f'proxyrust del "{port}"')
    await update.message.reply_text(f"✅ *Resultado:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
    
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_rusty_menu(fake_update, context)

async def confirm_uninstall_rusty(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o Rusty Proxy...")
    output = execute_shell_command("proxyrust uninstall")
    await query.edit_message_text(f"✅ *Resultado:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
    return await start_rusty_menu(update, context)


# --- Módulo: SSL Tunnel (Stunnel) --- (Toda a lógica está aqui)
def is_stunnel_installed():
    return os.path.exists('/etc/stunnel/stunnel.conf')

async def start_stunnel_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()

    if is_stunnel_installed():
        current_ports = execute_shell_command("netstat -nltp 2>/dev/null | grep 'stunnel' | awk '{print $4}' | awk -F: '{print $NF}' | tr '\n' ' '")
        status_text = f"Status: 🟢 *ATIVO* | Portas: *{current_ports or 'N/A'}*"
        keyboard = [
            [InlineKeyboardButton("🔩 Alterar Porta", callback_data='stunnel_change_port')],
            [InlineKeyboardButton("🗑️ Desinstalar", callback_data='stunnel_uninstall')],
            [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
        ]
        await query.edit_message_text(text=f"🔌 *Gerenciador SSL Tunnel*\n\n{status_text}\n\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return STUNNEL_MANAGE_MENU
    else:
        keyboard = [
            [InlineKeyboardButton("Padrão (SSH)", callback_data='stunnel_install_ssh'), InlineKeyboardButton("WebSocket (Proxy)", callback_data='stunnel_install_ws')],
            [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
        ]
        await query.edit_message_text(text="🔌 *Instalador SSL Tunnel*\n\nO Stunnel não está instalado. Escolha o modo de redirecionamento:", reply_markup=InlineKeyboardMarkup(keyboard))
        return STUNNEL_INSTALL_MODE

async def get_stunnel_install_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    context.user_data['stunnel_forward_port'] = '22' if query.data == 'stunnel_install_ssh' else '80'
    await query.edit_message_text("Digite a porta para o SSL Tunnel escutar (ex: 443):")
    return GET_STUNNEL_INSTALL_PORT

async def get_stunnel_install_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return GET_STUNNEL_INSTALL_PORT
    
    forward_port = context.user_data['stunnel_forward_port']
    await update.message.reply_text(f"⚙️ Instalando Stunnel na porta {port}...")
    
    execute_shell_command("apt-get update && apt-get install -y stunnel4")
    config = f"pid = /var/run/stunnel4.pid\ncert = /etc/stunnel/stunnel.pem\nclient = no\nsocket = a:SO_REUSEADDR=1\nsocket = l:TCP_NODELAY=1\nsocket = r:TCP_NODELAY=1\n\n[stunnel]\naccept = {port}\nconnect = 127.0.0.1:{forward_port}\n"
    with open("/etc/stunnel/stunnel.conf", "w") as f: f.write(config)
    execute_shell_command("openssl genrsa -out key.pem 2048; openssl req -new -x509 -key key.pem -out cert.pem -days 3650 -subj '/CN=localhost'; cat cert.pem key.pem > /etc/stunnel/stunnel.pem; rm cert.pem key.pem")
    execute_shell_command("sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4; service stunnel4 restart")

    await update.message.reply_text(f"✅ Stunnel instalado e ativo na porta {port}!")
    
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text, 'data': 'conn_stunnel'})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_stunnel_menu(fake_update, context)

async def stunnel_manage_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    if query.data == 'stunnel_change_port':
        await query.edit_message_text("Digite a nova porta para o Stunnel:")
        return GET_STUNNEL_CHANGE_PORT
    elif query.data == 'stunnel_uninstall':
        keyboard = [[InlineKeyboardButton("Sim, tenho certeza", callback_data='stunnel_uninstall_confirm'), InlineKeyboardButton("Não, cancelar", callback_data='stunnel_cancel_uninstall')]]
        await query.edit_message_text("⚠️ Tem certeza que deseja remover o Stunnel?", reply_markup=InlineKeyboardMarkup(keyboard))
        return CONFIRM_UNINSTALL_STUNNEL
    elif query.data == 'back_to_connection_menu':
        return ConversationHandler.END

async def get_stunnel_change_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    new_port = update.message.text.strip()
    if not new_port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return GET_STUNNEL_CHANGE_PORT
        
    execute_shell_command(f"sed -i 's/accept = .*/accept = {new_port}/' /etc/stunnel/stunnel.conf; service stunnel4 restart")
    await update.message.reply_text(f"✅ Porta do Stunnel alterada para {new_port}!")
    
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text, 'data': 'conn_stunnel'})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_stunnel_menu(fake_update, context)

async def confirm_uninstall_stunnel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o Stunnel...")
    execute_shell_command("service stunnel4 stop; apt-get purge stunnel4 -y; rm -rf /etc/stunnel /etc/default/stunnel4")
    await query.edit_message_text("✅ Stunnel removido com sucesso.")

    fake_query = type('FakeQuery', (), {'message': query.message, 'answer': (lambda: None), 'edit_message_text': query.message.reply_text, 'data': 'conn_stunnel'})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_stunnel_menu(fake_update, context)


# --- Módulo: BadVPN --- (Toda a lógica está aqui)
def get_badvpn_status():
    udpgw_procs = execute_shell_command("ps x | grep -w 'badvpn-udpgw' | grep -v grep")
    if udpgw_procs:
        status = "ATIVO"
        ports = execute_shell_command("netstat -npltu | grep 'badvpn-ud' | awk '{print $4}' | cut -d: -f2 | xargs")
    else:
        status = "INATIVO"
        ports = "Nenhuma"
    return status, ports

async def start_badvpn_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, ports = get_badvpn_status()
    status_text = f"Status: 🟢 *{status}* | Portas: *{ports}*" if status == "ATIVO" else "Status: 🔴 *INATIVO*"

    keyboard = [
        [InlineKeyboardButton("🚀 Ativar/Desativar (Padrão 7300)", callback_data='badvpn_toggle_default')],
        [InlineKeyboardButton("➕ Abrir Nova Porta", callback_data='badvpn_add_port')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.edit_message_text(text=f"🔌 *Gerenciador BadVPN PRO*\n\n{status_text}\n\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return BADVPN_MENU

async def badvpn_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'badvpn_toggle_default':
        status, _ = get_badvpn_status()
        if status == "ATIVO":
            await query.edit_message_text("⚙️ Desativando todos os serviços BadVPN...")
            execute_shell_command("screen -ls | grep -E '.udpvpn|.tun2socks' | awk '{print $1}' | xargs -I {} screen -S {} -X quit")
            await query.edit_message_text("✅ BadVPN desativado com sucesso!")
        else:
            await query.edit_message_text("⚙️ Ativando BadVPN (Porta 7300)...")
            execute_shell_command("wget -O /bin/badvpn-udpgw https://bit.ly/3zV39hE -q && chmod +x /bin/badvpn-udpgw")
            execute_shell_command("screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000")
            await query.edit_message_text("✅ BadVPN ativado com sucesso na porta 7300!")
        return await start_badvpn_menu(update, context)

    elif action == 'badvpn_add_port':
        if get_badvpn_status()[0] == "INATIVO":
            await query.message.reply_text("❌ Ative o BadVPN Padrão primeiro.")
            return BADVPN_MENU
        await query.edit_message_text("Digite a nova porta UDP a ser aberta:")
        return GET_BADVPN_NEW_PORT
    
    elif action == 'back_to_connection_menu':
        return ConversationHandler.END

async def get_badvpn_new_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return GET_BADVPN_NEW_PORT
    
    await update.message.reply_text(f"⚙️ Abrindo a porta {port}...")
    execute_shell_command(f"screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:{port} --max-clients 10000")
    await update.message.reply_text(f"✅ Porta {port} ativada com sucesso!")
    
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_badvpn_menu(fake_update, context)


# --- Módulo: Proxy Dragon --- (Toda a lógica está aqui)
def get_dragon_status():
    if not os.path.exists(f"{DRAGON_INSTALL_DIR}/proxy.sh"): return "Não Instalado", []
    active_ports = []
    if os.path.exists(DRAGON_PORTS_FILE):
        with open(DRAGON_PORTS_FILE, 'r') as f:
            ports = f.read().splitlines()
            for port in ports:
                is_active = "active" in execute_shell_command(f"systemctl is-active dragonx_port_{port}.service")
                active_ports.append({'port': port, 'active': is_active})
    return "Instalado", active_ports

async def start_dragon_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, ports = get_dragon_status()
    status_text = f"Status: {status}\n"
    if ports:
        status_text += "Portas Ativas:\n"
        for p in ports: status_text += f"  - Porta `{p['port']}` ({'🟢' if p['active'] else '🔴'})\n"
    else:
        status_text += "Nenhuma porta configurada."

    keyboard = [
        [InlineKeyboardButton("➕ Iniciar Porta", callback_data='dragon_add'), InlineKeyboardButton("🛑 Parar Porta", callback_data='dragon_stop')],
        [InlineKeyboardButton("🔄 Reiniciar Porta", callback_data='dragon_restart'), InlineKeyboardButton("📥 Instalar", callback_data='dragon_install')],
        [InlineKeyboardButton("🗑️ Desinstalar", callback_data='dragon_uninstall')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.edit_message_text(text=f"🐉 *Gerenciador Proxy Dragon*\n\n{status_text}\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return DRAGON_MENU

async def dragon_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    context.user_data['dragon_action'] = action.split('_')[1]

    if action == 'dragon_add':
        await query.edit_message_text("Digite a porta a ser iniciada:")
        return GET_DRAGON_ADD_PORT
    elif action == 'dragon_stop':
        await query.edit_message_text("Digite a porta a ser parada:")
        return GET_DRAGON_STOP_PORT
    elif action == 'dragon_restart':
        await query.edit_message_text("Digite a porta a ser reiniciada:")
        return GET_DRAGON_RESTART_PORT
    elif action == 'dragon_install':
        await query.edit_message_text("⚙️ Instalando o Proxy Dragon...")
        output = execute_shell_command("proxyd install")
        await query.edit_message_text(f"✅ *Resultado da Instalação:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
        return await start_dragon_menu(update, context)
    elif action == 'dragon_uninstall':
        keyboard = [[InlineKeyboardButton("Sim, tenho certeza", callback_data='dragon_uninstall_confirm'), InlineKeyboardButton("Não, cancelar", callback_data='dragon_cancel_uninstall')]]
        await query.edit_message_text("⚠️ Tem certeza que deseja remover o Proxy Dragon?", reply_markup=InlineKeyboardMarkup(keyboard))
        return CONFIRM_UNINSTALL_DRAGON
    elif action == 'back_to_connection_menu':
        return ConversationHandler.END

async def get_dragon_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    action = context.user_data.get('dragon_action', 'add')
    if not port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return context.user_data.get('current_state')
    
    action_text = {"add": "Iniciando", "stop": "Parando", "restart": "Reiniciando"}
    await update.message.reply_text(f"⚙️ {action_text.get(action, '')} a porta {port}...")
    output = execute_shell_command(f'proxyd {action} "{port}"')
    await update.message.reply_text(f"✅ *Resultado:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
    
    fake_query = type('FakeQuery', (), {'message': update.message, 'answer': (lambda: None), 'edit_message_text': update.message.reply_text})()
    fake_update = type('FakeUpdate', (), {'callback_query': fake_query})()
    return await start_dragon_menu(fake_update, context)

async def confirm_uninstall_dragon(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o Proxy Dragon...")
    output = execute_shell_command("proxyd uninstall")
    await query.edit_message_text(f"✅ *Resultado:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
    return await start_dragon_menu(update, context)


# --- Módulo: SlowDNS --- (Toda a lógica está aqui)
async def start_slowdns_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()

    if os.path.exists('/etc/slowdns/dns-server'):
        status = "🟢 ATIVO" if "slowdns" in execute_shell_command("screen -ls") else "🔴 INATIVO"
        keyboard = [
            [InlineKeyboardButton("🚀 Iniciar", callback_data='slowdns_start'), InlineKeyboardButton("🛑 Parar", callback_data='slowdns_stop'), InlineKeyboardButton("🔄 Reiniciar", callback_data='slowdns_restart')],
            [InlineKeyboardButton("ℹ️ Ver Info (NS/Chave)", callback_data='slowdns_info')],
            [InlineKeyboardButton("🗑️ Desinstalar", callback_data='slowdns_uninstall')],
            [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
        ]
        await query.edit_message_text(text=f"🔌 *Gerenciador SlowDNS*\n\nStatus: *{status}*\n\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return SLOWDNS_MENU
    else:
        keyboard = [
            [InlineKeyboardButton("Modo SSH", callback_data='slowdns_install_ssh'), InlineKeyboardButton("Modo SSL", callback_data='slowdns_install_ssl')],
            [InlineKeyboardButton("Modo Drop", callback_data='slowdns_install_drop'), InlineKeyboardButton("Modo SOCKS", callback_data='slowdns_install_socks')],
            [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
        ]
        await query.edit_message_text(text="🔌 *Instalador SlowDNS*\n\nO SlowDNS não está instalado. Escolha o modo:", reply_markup=InlineKeyboardMarkup(keyboard))
        return SLOWDNS_INSTALL_MODE

async def get_slowdns_install_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    context.user_data['slowdns_mode'] = query.data.split('_')[-1]
    await query.edit_message_text(f"Modo selecionado: *{context.user_data['slowdns_mode'].upper()}*\n\nDigite seu Nameserver (NS):", parse_mode=ParseMode.MARKDOWN)
    return GET_SLOWDNS_NS

async def get_slowdns_ns(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    ns = update.message.text.strip()
    if not ns:
        await update.message.reply_text("Nameserver inválido.")
        return GET_SLOWDNS_NS
    context.user_data['slowdns_ns'] = ns
    keyboard = [[InlineKeyboardButton("Gerar Nova Chave", callback_data='slowdns_key_new'), InlineKeyboardButton("Usar Chave Padrão", callback_data='slowdns_key_default')]]
    await update.message.reply_text("Escolha como gerenciar a chave do servidor:", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_SLOWDNS_KEY_CHOICE

async def install_slowdns_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    mode, ns = context.user_data['slowdns_mode'], context.user_data['slowdns_ns']
    await query.edit_message_text(f"⚙️ Instalando SlowDNS (Modo: {mode.upper()})...")
    
    execute_shell_command("apt-get update && apt-get install -y screen dnsutils wget; mkdir -p /etc/slowdns; wget -q -O /etc/slowdns/dns-server https://gitea.com/alfalemos/SSHPLUS/raw/branch/main/Modulos/dns-server && chmod +x /etc/slowdns/dns-server")
    execute_shell_command("iptables -I INPUT -p udp --dport 5300 -j ACCEPT; iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300")
    with open('/etc/slowdns/infons', 'w') as f: f.write(ns)
    with open('/etc/slowdns/mode', 'w') as f: f.write(mode)
    
    if query.data == 'slowdns_key_new': execute_shell_command("/etc/slowdns/dns-server -gen-key -privkey-file /root/server.key -pubkey-file /root/server.pub; cp /root/server.key /etc/slowdns/")
    else: execute_shell_command("echo '6b19f3ea1cabc68daeda4155987a1ebe3ce7e47818e2b86666d3cd4e367c83a6' > /etc/slowdns/server.key; echo '7d631e6ca0f7c6df2b3f2b4dc413fbb8c9ecd05245ccb529787ea131478e6a65' > /root/server.pub")

    port = {'ssh': '22', 'ssl': '443', 'drop': '80', 'socks': '1080'}.get(mode, '22')
    execute_shell_command(f"screen -dmS slowdns /etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key '{ns}' '127.0.0.1:{port}'")
    
    await query.edit_message_text("✅ SlowDNS instalado e iniciado com sucesso!")
    return await start_slowdns_menu(update, context)

async def slowdns_manage_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action in ['slowdns_start', 'slowdns_restart']:
        msg = "Reiniciando" if action == 'slowdns_restart' else "Iniciando"
        await query.edit_message_text(f"⚙️ {msg} o SlowDNS...")
        execute_shell_command("screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill")
        if action == 'slowdns_start':
            mode, ns = execute_shell_command("cat /etc/slowdns/mode"), execute_shell_command("cat /etc/slowdns/infons")
            port = {'ssh': '22', 'ssl': '443', 'drop': '80', 'socks': '1080'}.get(mode, '22')
            execute_shell_command(f"screen -dmS slowdns /etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key '{ns}' '127.0.0.1:{port}'")
        await query.edit_message_text("✅ Serviço SlowDNS (re)iniciado!")
        
    elif action == 'slowdns_stop':
        await query.edit_message_text("⚙️ Parando o SlowDNS...")
        execute_shell_command("screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill")
        await query.edit_message_text("✅ Serviço SlowDNS parado!")
        
    elif action == 'slowdns_info':
        ns, pubkey = execute_shell_command("cat /etc/slowdns/infons"), execute_shell_command("cat /root/server.pub")
        await query.edit_message_text(f"ℹ️ *Informações SlowDNS*\n\n🌐 *NS:* `{ns}`\n🔑 *Chave:* `{pubkey}`", parse_mode=ParseMode.MARKDOWN)

    elif action == 'slowdns_uninstall':
        keyboard = [[InlineKeyboardButton("Sim, tenho certeza", callback_data='slowdns_uninstall_confirm'), InlineKeyboardButton("Não, cancelar", callback_data='slowdns_cancel_uninstall')]]
        await query.edit_message_text("⚠️ Tem certeza que deseja remover o SlowDNS?", reply_markup=InlineKeyboardMarkup(keyboard))
        return CONFIRM_UNINSTALL_SLOWDNS
        
    return await start_slowdns_menu(update, context)

async def confirm_uninstall_slowdns(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o SlowDNS...")
    execute_shell_command("screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill; rm -rf /etc/slowdns /root/server.key /root/server.pub")
    execute_shell_command("iptables -D INPUT -p udp --dport 5300 -j ACCEPT; iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300")
    await query.edit_message_text("✅ SlowDNS removido com sucesso.")
    return await start_slowdns_menu(update, context)


# --- Menu Principal e Ponto de Entrada ---

async def menu_command(update: Update, context: ContextTypes.DEFAULT_TYPE, is_follow_up=False) -> None:
    """Exibe o menu principal de ações."""
    if not await is_admin(update): return

    keyboard = [
        [InlineKeyboardButton("➕ Criar Usuário", callback_data='start_create_user'), InlineKeyboardButton("➖ Remover Usuário", callback_data='start_delete_user')],
        [InlineKeyboardButton("ℹ️ Info Usuários", callback_data='user_info_report'), InlineKeyboardButton("📊 Usuários Online", callback_data='online_users_monitor')],
        [InlineKeyboardButton("🔌 Conexão", callback_data='start_connection_menu')]
        # Botão de backup pode ser adicionado aqui se a lógica for implementada
    ]
    text = "🤖 *Gerenciador SSHPlus*\n\nSelecione uma opção:"
    
    if update.callback_query:
        await update.callback_query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        context.chat_data['last_message_id'] = update.callback_query.message.message_id
    else:
        await cleanup_last_message(context)
        sent_message = await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        context.chat_data.update({'chat_id': sent_message.chat_id, 'last_message_id': sent_message.message_id})


def main() -> None:
    """Inicia o bot e configura todos os handlers."""
    application = Application.builder().token(TELEGRAM_TOKEN).build()

    # --- Handlers de Conversação Aninhados para os Módulos de Conexão ---
    
    websocket_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_websocket_menu, pattern='^conn_websocket$')],
        states={
            WEBSOCKET_MENU: [CallbackQueryHandler(websocket_menu_handler)],
            GET_WS_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ws_port)],
            GET_WS_MODE: [CallbackQueryHandler(get_ws_mode, pattern='^ws_mode_')],
            GET_WS_MSG: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ws_msg_and_start)],
            CONFIRM_UNINSTALL_WS: [
                CallbackQueryHandler(confirm_uninstall_ws, pattern='^ws_uninstall_confirm$'),
                CallbackQueryHandler(start_websocket_menu, pattern='^ws_cancel_uninstall$')
            ],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')],
        map_to_parent={-1: CONNECTION_MENU}
    )
    
    rusty_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_rusty_menu, pattern='^conn_rusty$')],
        states={
            RUSTY_MENU: [CallbackQueryHandler(rusty_menu_handler)],
            GET_RUSTY_ADD_PORT: [MessageHandler(filters.TEXT, get_rusty_add_port)],
            GET_RUSTY_ADD_STATUS: [MessageHandler(filters.TEXT, get_rusty_add_status_and_run)],
            GET_RUSTY_DEL_PORT: [MessageHandler(filters.TEXT, get_rusty_del_port_and_run)],
            CONFIRM_UNINSTALL_RUSTY: [
                CallbackQueryHandler(confirm_uninstall_rusty, pattern='^rusty_uninstall_confirm$'),
                CallbackQueryHandler(start_rusty_menu, pattern='^rusty_cancel_uninstall$')
            ],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')],
        map_to_parent={-1: CONNECTION_MENU}
    )

    stunnel_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_stunnel_menu, pattern='^conn_stunnel$')],
        states={
            STUNNEL_INSTALL_MODE: [CallbackQueryHandler(get_stunnel_install_mode)],
            GET_STUNNEL_INSTALL_PORT: [MessageHandler(filters.TEXT, get_stunnel_install_port_and_run)],
            STUNNEL_MANAGE_MENU: [CallbackQueryHandler(stunnel_manage_handler)],
            GET_STUNNEL_CHANGE_PORT: [MessageHandler(filters.TEXT, get_stunnel_change_port_and_run)],
            CONFIRM_UNINSTALL_STUNNEL: [
                CallbackQueryHandler(confirm_uninstall_stunnel, pattern='^stunnel_uninstall_confirm$'),
                CallbackQueryHandler(start_stunnel_menu, pattern='^stunnel_cancel_uninstall$')
            ],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')],
        map_to_parent={-1: CONNECTION_MENU}
    )
    
    badvpn_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_badvpn_menu, pattern='^conn_badvpn$')],
        states={
            BADVPN_MENU: [CallbackQueryHandler(badvpn_menu_handler)],
            GET_BADVPN_NEW_PORT: [MessageHandler(filters.TEXT, get_badvpn_new_port_and_run)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')],
        map_to_parent={-1: CONNECTION_MENU}
    )

    dragon_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_dragon_menu, pattern='^conn_dragon$')],
        states={
            DRAGON_MENU: [CallbackQueryHandler(dragon_menu_handler)],
            GET_DRAGON_ADD_PORT: [MessageHandler(filters.TEXT, get_dragon_port_and_run)],
            GET_DRAGON_STOP_PORT: [MessageHandler(filters.TEXT, get_dragon_port_and_run)],
            GET_DRAGON_RESTART_PORT: [MessageHandler(filters.TEXT, get_dragon_port_and_run)],
            CONFIRM_UNINSTALL_DRAGON: [
                CallbackQueryHandler(confirm_uninstall_dragon, pattern='^dragon_uninstall_confirm$'),
                CallbackQueryHandler(start_dragon_menu, pattern='^dragon_cancel_uninstall$')
            ],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')],
        map_to_parent={-1: CONNECTION_MENU}
    )

    slowdns_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_slowdns_menu, pattern='^conn_slowdns$')],
        states={
            SLOWDNS_MENU: [CallbackQueryHandler(slowdns_manage_handler)],
            SLOWDNS_INSTALL_MODE: [CallbackQueryHandler(get_slowdns_install_mode)],
            GET_SLOWDNS_NS: [MessageHandler(filters.TEXT, get_slowdns_ns)],
            GET_SLOWDNS_KEY_CHOICE: [CallbackQueryHandler(install_slowdns_run)],
            CONFIRM_UNINSTALL_SLOWDNS: [
                CallbackQueryHandler(confirm_uninstall_slowdns, pattern='^slowdns_uninstall_confirm$'),
                CallbackQueryHandler(start_slowdns_menu, pattern='^slowdns_cancel_uninstall$')
            ],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')],
        map_to_parent={-1: CONNECTION_MENU}
    )

    # --- Handlers de Conversação Principais ---
    
    create_user_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_create_user_convo, pattern='^start_create_user$')],
        states={
            GET_USER_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_username)],
            GET_USER_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_password)],
            GET_USER_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_days)],
            GET_USER_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_limit_and_create)],
        },
        fallbacks=[CommandHandler('cancel', cancel), CallbackQueryHandler(menu_command, pattern='^back_to_main$')]
    )
    
    delete_user_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_delete_user, pattern='^start_delete_user$')],
        states={
            GET_USER_TO_DELETE: [
                CallbackQueryHandler(get_user_to_delete, pattern='^del_'),
                CallbackQueryHandler(confirm_delete_all_users_prompt, pattern='^del_all$')
            ],
            CONFIRM_DELETE_USER: [CallbackQueryHandler(confirm_delete_single_user, pattern='^confirm_delete_user$')],
            CONFIRM_DELETE_ALL: [CallbackQueryHandler(execute_delete_all_users, pattern='^confirm_delete_all$')]
        },
        fallbacks=[CommandHandler('cancel', cancel), CallbackQueryHandler(menu_command, pattern='^back_to_main$')]
    )

    connection_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_connection_menu, pattern='^start_connection_menu$')],
        states={
            CONNECTION_MENU: [
                websocket_conv, rusty_conv, stunnel_conv, badvpn_conv, dragon_conv, slowdns_conv
            ],
        },
        fallbacks=[CommandHandler('cancel', cancel), CallbackQueryHandler(menu_command, pattern='^back_to_main$')],
    )
    
    # Adicionando todos os handlers à aplicação
    application.add_handler(CommandHandler("start", menu_command))
    application.add_handler(CommandHandler("menu", menu_command))
    
    application.add_handler(create_user_conv)
    application.add_handler(delete_user_conv)
    application.add_handler(connection_conv)

    # Handlers para botões que não iniciam uma conversa
    application.add_handler(CallbackQueryHandler(user_info_report, pattern='^user_info_report$'))
    application.add_handler(CallbackQueryHandler(online_users_monitor, pattern='^online_users_monitor$'))
    # Handler para o botão "Voltar" dentro de uma conversa que não foi capturado por fallbacks específicos
    application.add_handler(CallbackQueryHandler(menu_command, pattern='^back_to_main$'))

    print("Bot iniciado! Pressione Ctrl+C para parar.")
    application.run_polling()

if __name__ == '__main__':
    main()