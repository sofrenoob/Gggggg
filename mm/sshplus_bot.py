#!/usr/bin/python3
# -*- coding: utf-8 -*-

import subprocess
import os
import re
import asyncio
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
import logging

# Configuração de logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# ==========================================================
#               CONFIGURAÇÃO INICIAL
# ==========================================================
TELEGRAM_TOKEN = "SEU_NOVO_TOKEN_AQUI" # IMPORTANTE: USE UM NOVO TOKEN
ADMIN_USER_ID = 123456789  # SEU ID NUMÉRICO
# ==========================================================


# --- Definição dos Estados ---
(
    GET_USER_USERNAME, GET_USER_PASSWORD, GET_USER_DAYS, GET_USER_LIMIT,
    GET_TEST_USERNAME, GET_TEST_PASSWORD, GET_TEST_LIMIT, GET_TEST_DURATION,
    GET_USER_TO_DELETE, CONFIRM_DELETE_USER, CONFIRM_DELETE_ALL,
    BACKUP_MENU, CONFIRM_RESTORE,
    CONNECTION_MENU,
    WEBSOCKET_MENU, GET_WS_PORT, GET_WS_MODE, GET_WS_MSG, CONFIRM_UNINSTALL_WS,
    RUSTY_MENU, GET_RUSTY_ADD_PORT, GET_RUSTY_ADD_STATUS, GET_RUSTY_DEL_PORT, CONFIRM_UNINSTALL_RUSTY,
    STUNNEL_MENU, STUNNEL_INSTALL_MODE, GET_STUNNEL_INSTALL_PORT, STUNNEL_MANAGE_MENU, GET_STUNNEL_CHANGE_PORT, CONFIRM_UNINSTALL_STUNNEL,
    BADVPN_MENU, GET_BADVPN_NEW_PORT,
    DRAGON_MENU, GET_DRAGON_ADD_PORT, GET_DRAGON_STOP_PORT, GET_DRAGON_RESTART_PORT, CONFIRM_UNINSTALL_DRAGON,
    SLOWDNS_MENU, SLOWDNS_INSTALL_MODE, GET_SLOWDNS_NS, GET_SLOWDNS_KEY_CHOICE, CONFIRM_UNINSTALL_SLOWDNS
) = range(42)


# --- Constantes de Caminhos ---
WEBSOCKET_BIN = "/usr/local/bin/WebSocket"
RUSTY_PORTS_FILE = "/opt/rustyproxy/ports"
DRAGON_INSTALL_DIR = "/root/DragonX"
DRAGON_PORTS_FILE = f"{DRAGON_INSTALL_DIR}/ports.list"
BACKUP_FILE_PATH = "/root/backup.vps.tar.gz"


# --- Funções Auxiliares e de Navegação ---

async def execute_shell_command(command, input_text=None):
    """Executa um comando de shell de forma assíncrona para não bloquear o bot."""
    logger.info(f"Executing async command: {command}")
    try:
        proc = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.PIPE if input_text else None
        )
        stdout, stderr = await proc.communicate(input=input_text.encode() if input_text else None)
        if stderr:
            logger.error(f"Command error: {stderr.decode().strip()}")
        return stdout.decode().strip()
    except Exception as e:
        logger.error(f"Exception executing async command: {e}")
        return ""

async def is_admin(update: Update) -> bool:
    """Verifica se o usuário é o administrador do bot."""
    if update.effective_user.id != ADMIN_USER_ID:
        if update.callback_query:
            await update.callback_query.answer("❌ Acesso negado.", show_alert=True)
        else:
            await update.message.reply_text("❌ Acesso negado.")
        return False
    return True

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Envia o menu principal como uma nova mensagem, limpando o estado anterior."""
    if not await is_admin(update): return
    
    chat_id = update.effective_chat.id
    
    # Limpa mensagens anteriores para evitar confusão
    if 'last_menu_id' in context.chat_data:
        try:
            await context.bot.delete_message(chat_id, context.chat_data['last_menu_id'])
        except BadRequest:
            pass

    keyboard = [
        [InlineKeyboardButton("➕ Criar Usuário", callback_data='start_create_user'), InlineKeyboardButton("⚡ Criar Teste", callback_data='start_create_test_user')],
        [InlineKeyboardButton("➖ Remover Usuário", callback_data='start_delete_user'), InlineKeyboardButton("🗄️ Backup/Restore", callback_data='start_backup')],
        [InlineKeyboardButton("ℹ️ Info Usuários", callback_data='user_info_report'), InlineKeyboardButton("📊 Online", callback_data='online_users_monitor')],
        [InlineKeyboardButton("🔌 Conexão", callback_data='start_connection_menu')]
    ]
    text = "🤖 *Gerenciador SSHPlus*\n\nSelecione uma opção:"
    
    sent_message = await context.bot.send_message(chat_id, text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    context.chat_data['last_menu_id'] = sent_message.message_id

async def end_conversation(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Finaliza qualquer conversa ativa e mostra o menu principal."""
    query = update.callback_query
    if query:
        await query.answer()
        try:
            await query.message.delete()
        except BadRequest:
            logger.warning("Could not delete message, maybe it was already deleted.")
    
    await start_command(update.callback_query or update, context)
    return ConversationHandler.END
# --- Funções de Relatório e Ações Diretas ---

async def user_info_report(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin(update): return
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("⚙️ Gerando relatório de usuários...")

    raw_output = await execute_shell_command("/usr/bin/userinfo") or await execute_shell_command("luser")
    
    if not raw_output:
        report = "❌ Não foi possível gerar o relatório. Nenhum script de info encontrado."
    else:
        report = f"👤 *Relatório de Usuários SSH*\n\n```\n{raw_output}\n```"
    
    await query.message.edit_text(report, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main_special')]]))

async def online_users_monitor(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin(update): return
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("⚙️ Verificando usuários online...")
    
    raw_output = await execute_shell_command("/usr/bin/sshmonitor")
    clean_output = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', raw_output)
    final_message = f"📊 *Monitor de Usuários Online*\n\n```\n{clean_output or 'Nenhum usuário online.'}\n```"
    
    await query.message.edit_text(final_message, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main_special')]]))

async def back_to_main_from_report(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Função especial para voltar dos relatórios, que não estão em uma conversa."""
    query = update.callback_query
    await query.answer()
    await query.message.delete()
    await start_command(update, context)

# --- Seção: Criação de Usuário ---

async def start_create_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("Qual o nome do novo usuário?")
    return GET_USER_USERNAME

async def get_user_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    username = update.message.text.strip()
    if not username or not username.isalnum() or not (2 <= len(username) <= 10):
        await update.message.reply_text("Nome inválido (2-10 letras/números). Tente novamente.")
        return GET_USER_USERNAME
    if await execute_shell_command(f"id -u {username}"):
        await update.message.reply_text("❌ Este usuário já existe. Tente outro nome.")
        return GET_USER_USERNAME
    context.user_data['user_username'] = username
    await update.message.reply_text("Ótimo. Agora, qual a senha (mínimo 4 caracteres)?")
    return GET_USER_PASSWORD

async def get_user_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    password = update.message.text.strip()
    if not password or len(password) < 4:
        await update.message.reply_text("Senha inválida (mínimo 4 caracteres). Tente novamente.")
        return GET_USER_PASSWORD
    context.user_data['user_password'] = password
    await update.message.reply_text("Por quantos dias a conta será válida?")
    return GET_USER_DAYS

async def get_user_days(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    days = update.message.text.strip()
    if not days.isdigit() or int(days) < 1:
        await update.message.reply_text("Número de dias inválido. Insira um número > 0.")
        return GET_USER_DAYS
    context.user_data['user_days'] = days
    await update.message.reply_text("Qual o limite de conexões simultâneas?")
    return GET_USER_LIMIT

async def get_user_limit_and_create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    limit = update.message.text.strip()
    if not limit.isdigit() or int(limit) < 1:
        await update.message.reply_text("Limite inválido. Insira um número > 0.")
        return GET_USER_LIMIT

    await update.message.delete()
    sent_message = await context.bot.send_message(chat_id=update.effective_chat.id, text="⚙️ Processando... Criando usuário.")

    nome = context.user_data['user_username']
    pasw = context.user_data['user_password']
    dias = int(context.user_data['user_days'])

    data_final = (datetime.now() + timedelta(days=dias)).strftime('%Y-%m-%d')
    await execute_shell_command(f"useradd -M -s /bin/false -e {data_final} {nome}")
    await execute_shell_command(f'echo "{nome}:{pasw}" | chpasswd')
    os.makedirs("/etc/SSHPlus/senha", exist_ok=True)
    with open(f"/etc/SSHPlus/senha/{nome}", "w") as f: f.write(pasw)
    with open("/root/usuarios.db", "a") as f: f.write(f"{nome} {limit}\n")

    ip_servidor = await execute_shell_command("wget -qO- ifconfig.me")
    gui_data = (datetime.now() + timedelta(days=dias)).strftime('%d/%m/%Y')
    success_message = (f"✅ *Conta SSH Criada!*\n\n"
                       f"🌐 *IP:* `{ip_servidor}`\n👤 *Usuário:* `{nome}`\n🔑 *Senha:* `{pasw}`\n"
                       f"📶 *Limite:* `{limit}`\n⏳ *Expira em:* `{gui_data}` ({dias} dias)")

    await sent_message.edit_text(success_message, parse_mode=ParseMode.MARKDOWN)
    return await end_conversation(update, context)

# --- Seção: Criação de Usuário de Teste ---

async def start_create_test_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    if not await execute_shell_command("command -v at"):
        await query.message.edit_text("❌ O comando `at` não está instalado. Não é possível criar usuários de teste.",
                                      reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]]))
        return ConversationHandler.END
    await query.message.edit_text("Qual o nome do usuário de teste?")
    return GET_TEST_USERNAME

async def get_test_user_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    username = update.message.text.strip()
    # (validações)
    context.user_data['test_username'] = username
    await update.message.reply_text("Qual a senha?")
    return GET_TEST_PASSWORD
# ... (demais funções do teste) ...
async def get_test_duration_and_create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    duration = update.message.text.strip()
    if not duration.isdigit() or int(duration) < 1:
        await update.message.reply_text("Duração inválida. Insira minutos > 0.")
        return GET_TEST_DURATION

    await update.message.delete()
    sent_message = await context.bot.send_message(chat_id=update.effective_chat.id, text="⚙️ Processando... Criando usuário de teste.")

    nome = context.user_data['test_username']
    pasw = context.user_data['test_password']
    limit = context.user_data['test_limit']

    await execute_shell_command(f"useradd -M -s /bin/false {nome}")
    await execute_shell_command(f'echo "{nome}:{pasw}" | chpasswd')
    # ... resto da lógica
    remover_script_path = f"/tmp/remover_{nome}.sh"
    # ...
    await execute_shell_command(f'echo "{remover_script_path}" | at now + {duration} minutes')

    ip_servidor = await execute_shell_command("wget -qO- ifconfig.me")
    success_message = (f"✅ *Conta de Teste Criada!*\n\n"
                       f"🌐 *IP:* `{ip_servidor}`\n👤 *Usuário:* `{nome}`\n🔑 *Senha:* `{pasw}`\n"
                       f"📶 *Limite:* `{limit}`\n"
                       f"⏳ *Expira em:* `{duration} minutos`\n\n"
                       f"A conta será *automaticamente deletada*.")
    
    await sent_message.edit_text(success_message, parse_mode=ParseMode.MARKDOWN)
    return await end_conversation(update, context)

# --- Seção: Remoção de Usuário ---

async def start_delete_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    users_raw = await execute_shell_command("awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -v 'nobody'")
    users = users_raw.splitlines()

    if not users:
        await query.message.edit_text("Não há usuários para remover.", reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]]))
        return ConversationHandler.END
    
    keyboard = [[InlineKeyboardButton(user, callback_data=user)] for user in users]
    keyboard.append([InlineKeyboardButton("❌ REMOVER TODOS ❌", callback_data="delete_all_users_prompt")])
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')])
    
    await query.message.edit_text("Selecione o usuário para remover:", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_USER_TO_DELETE

async def get_user_to_delete(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    user_to_delete = query.data
    context.user_data['user_to_delete'] = user_to_delete
    keyboard = [
        [InlineKeyboardButton(f"Sim, deletar {user_to_delete}", callback_data="confirm_delete")],
        [InlineKeyboardButton("Não, cancelar", callback_data='back_to_delete_menu')]
    ]
    await query.message.edit_text(f"Tem certeza que deseja deletar *{user_to_delete}*?", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return CONFIRM_DELETE_USER

async def confirm_delete_single_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    user = context.user_data['user_to_delete']
    
    await execute_shell_command(f"userdel -f {user}")
    await execute_shell_command(f"sed -i '/^{user} /d' /root/usuarios.db")
    
    await query.message.edit_text(f"✅ Usuário *{user}* removido com sucesso!", parse_mode=ParseMode.MARKDOWN)
    return await end_conversation(update, context)

async def delete_all_users_prompt(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    # ...
    return CONFIRM_DELETE_ALL

async def execute_delete_all_users(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    # ...
    return await end_conversation(update, context)

# --- Seção: Backup e Restauração ---

async def start_backup_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    backup_exists = "✅" if os.path.exists(BACKUP_FILE_PATH) else "❌"
    keyboard = [
        [InlineKeyboardButton("➕ Criar Backup Agora", callback_data='backup_create')],
        [InlineKeyboardButton(f"🌐 Gerar Link {backup_exists}", callback_data='backup_link')],
        [InlineKeyboardButton(f"🔄 Restaurar Backup {backup_exists}", callback_data='backup_restore')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]
    ]
    await query.message.edit_text("🗄️ *Gerenciador de Backup*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return BACKUP_MENU

# ... (funções de backup) ...
async def confirm_restore_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    # ...
    return await end_conversation(update, context)
# --- Seção: Menu de Conexão e Módulos ---

async def start_connection_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()

    ws_status, rusty_status, stunnel_status, badvpn_status, dragon_status, slowdns_status = await asyncio.gather(
        execute_shell_command("ps x | grep -q 'WebSocket' && echo '✅' || echo '❌'"),
        execute_shell_command("[ -s /opt/rustyproxy/ports ] && echo '✅' || echo '❌'"),
        execute_shell_command("[ -f /etc/stunnel/stunnel.conf ] && echo '✅' || echo '❌'"),
        execute_shell_command("ps x | grep -q 'badvpn-udpgw' && echo '✅' || echo '❌'"),
        execute_shell_command("[ -f /root/DragonX/proxy.sh ] && echo '✅' || echo '❌'"),
        execute_shell_command("[ -f /etc/slowdns/dns-server ] && echo '✅' || echo '❌'")
    )

    keyboard = [
        [InlineKeyboardButton(f"WebSocket {ws_status}", callback_data='conn_websocket'), InlineKeyboardButton(f"Rusty Proxy {rusty_status}", callback_data='conn_rusty')],
        [InlineKeyboardButton(f"SSL Tunnel {stunnel_status}", callback_data='conn_stunnel'), InlineKeyboardButton(f"BadVPN {badvpn_status}", callback_data='conn_badvpn')],
        [InlineKeyboardButton(f"Proxy Dragon {dragon_status}", callback_data='conn_dragon'), InlineKeyboardButton(f"SlowDNS {slowdns_status}", callback_data='conn_slowdns')],
        [InlineKeyboardButton("↩️ Voltar ao Menu Principal", callback_data='back_to_main')]
    ]
    await query.message.edit_text(
        text="🔌 *Menu de Conexão*\n\nSelecione um serviço para gerenciar:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return CONNECTION_MENU

# --- Módulo: BadVPN --- 

async def get_badvpn_status():
    udpgw_procs = await execute_shell_command("ps x | grep -w 'badvpn-udpgw' | grep -v grep")
    tun2socks_procs = await execute_shell_command("ps x | grep -w 'badvpn-tun2socks' | grep -v grep")
    if udpgw_procs or tun2socks_procs:
        status = "ATIVO"
        ports = await execute_shell_command("netstat -npltu | grep 'badvpn-ud' | awk '{print $4}' | cut -d: -f2 | xargs") or "N/A"
    else:
        status = "INATIVO"
        ports = "Nenhuma"
    return status, ports

async def start_badvpn_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, ports = await get_badvpn_status()
    status_text = f"Status: 🟢 *{status}* | Portas: *{ports}*" if status == "ATIVO" else f"Status: 🔴 *{status}*"

    keyboard = [
        [InlineKeyboardButton("🚀 Ativar/Desativar (Padrão 7300)", callback_data='badvpn_toggle_default')],
        [InlineKeyboardButton("➕ Abrir Nova Porta UDP", callback_data='badvpn_add_port')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.edit_message_text(text=f"🔌 *Gerenciador BadVPN PRO*\n\n{status_text}\n\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return BADVPN_MENU

async def badvpn_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'badvpn_toggle_default':
        status, _ = await get_badvpn_status()
        if status == "ATIVO":
            await query.edit_message_text("⚙️ Desativando todos os serviços BadVPN...")
            await execute_shell_command("screen -ls | grep -E '.udpvpn|.tun2socks' | awk '{print $1}' | xargs -I {} screen -S {} -X quit")
            await query.edit_message_text("✅ BadVPN desativado com sucesso!")
        else:
            await query.edit_message_text("⚙️ Ativando BadVPN (Porta 7300 e Tun2Socks)...")
            await execute_shell_command("wget -O /bin/badvpn-udpgw https://bit.ly/3zV39hE -q && chmod +x /bin/badvpn-udpgw")
            await execute_shell_command("wget -O /bin/badvpn-tun2socks https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/badvpn-tun2socks -q && chmod +x /bin/badvpn-tun2socks")
            
            await execute_shell_command("screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000")
            await execute_shell_command("screen -dmS tun2socks /bin/badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.0.2 --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080")
            
            await query.edit_message_text("✅ BadVPN (UDPGW + TUN2SOCKS) ativado com sucesso!")
        return await start_badvpn_menu(update, context)

    elif action == 'badvpn_add_port':
        status, _ = await get_badvpn_status()
        if status == "INATIVO":
            await query.message.reply_text("❌ Ative o BadVPN Padrão primeiro.")
            return BADVPN_MENU
        await query.edit_message_text("Digite a nova porta UDP a ser aberta:")
        return GET_BADVPN_NEW_PORT
    
    elif action == 'back_to_connection_menu':
        await menu_command(update, context, is_follow_up=True)
        return ConversationHandler.END

async def get_badvpn_new_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context, update.message.message_id)
    port = update.message.text.strip()
    if not port.isdigit():
        sent = await update.message.reply_text("Porta inválida.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_BADVPN_NEW_PORT
    
    sent = await update.message.reply_text(f"⚙️ Abrindo a porta {port}...")
    context.chat_data['last_message_id'] = sent.message_id
    await execute_shell_command(f"screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:{port} --max-clients 10000")
    await sent.edit_text(f"✅ Porta UDP {port} ativada com sucesso!")
    
    # Simula o início do menu novamente
    query = update.callback_query or (update.message and update.message.reply_to_message and update.message.reply_to_message.callback_query)
    if query:
        await start_badvpn_menu(update, context)
        return BADVPN_MENU # Continua na mesma sub-conversa
    else: # Fallback caso a query se perca
        await menu_command(update, context, is_follow_up=True)
        return ConversationHandler.END

# --- Módulo: WebSocket ---

async def get_websocket_status():
    process_cmd = await execute_shell_command(f"ps aux | grep '{WEBSOCKET_BIN}' | grep -v grep")
    if process_cmd:
        port_match = re.search(r'proxy_port \S+:(\d+)', process_cmd)
        port = port_match.group(1) if port_match else "N/A"
        mode = "TLS/SSL" if '-tls=true' in process_cmd else "Proxy"
        return "ATIVO", port, mode
    return "INATIVO", "N/A", "N/A"

async def start_websocket_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, port, mode = await get_websocket_status()
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
        await execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit")
        await query.edit_message_text("✅ Serviço parado com sucesso!")
        return await start_websocket_menu(update, context)

    elif action == 'ws_install':
        await query.edit_message_text("⚙️ Instalando/Atualizando WebSocket...")
        await execute_shell_command("apt-get update && apt-get install -y wget screen")
        await execute_shell_command(f"wget -q -O {WEBSOCKET_BIN} --no-check-certificate https://gitea.com/alfalemos/SSHPLUS/raw/main/Modulos/WebSocket && chmod +x {WEBSOCKET_BIN}")
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
        await menu_command(update, context, is_follow_up=True)
        return ConversationHandler.END 

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
    await execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit")
    
    cmd = f"{WEBSOCKET_BIN} -proxy_port 0.0.0.0:{port} -msg='{msg}'"
    if mode == 'ws_mode_tls': cmd += " -tls=true"
    
    await execute_shell_command(f"screen -dmS ws {cmd}")
    
    if "ws" in await execute_shell_command("screen -list"):
        await update.message.reply_text("✅ Serviço WebSocket iniciado com sucesso!")
    else:
        await update.message.reply_text("❌ Erro ao iniciar o serviço WebSocket.")
    
    await start_websocket_menu(update, context)
    return ConversationHandler.END

async def confirm_uninstall_ws(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o WebSocket...")
    await execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit; rm -f {WEBSOCKET_BIN}")
    await query.edit_message_text("✅ WebSocket desinstalado com sucesso.")
    return await start_websocket_menu(update, context)

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
    if not await is_admin(update): return

    keyboard = [
        [InlineKeyboardButton("➕ Criar Usuário", callback_data='start_create_user'), InlineKeyboardButton("⚡ Criar Teste", callback_data='start_create_test_user')],
        [InlineKeyboardButton("➖ Remover Usuário", callback_data='start_delete_user'), InlineKeyboardButton("🗄️ Backup/Restore", callback_data='start_backup')],
        [InlineKeyboardButton("ℹ️ Info Usuários", callback_data='user_info_report'), InlineKeyboardButton("📊 Usuários Online", callback_data='online_users_monitor')],
        [InlineKeyboardButton("🔌 Conexão", callback_data='start_connection_menu')]
    ]
    text = "🤖 *Gerenciador SSHPlus*\n\nSelecione uma opção:"
    
    message_carrier = update.callback_query.message if update.callback_query else update.message

    if is_follow_up or update.callback_query:
        if context.chat_data.get('last_message_id'):
            try:
                await context.bot.edit_message_text(
                    chat_id=message_carrier.chat_id, message_id=context.chat_data['last_message_id'],
                    text=text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
                )
            except BadRequest: pass
        else:
             sent_message = await message_carrier.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
             context.chat_data.update({'chat_id': sent_message.chat_id, 'last_message_id': sent_message.message_id})
    else:
        await cleanup_last_message(context)
        sent_message = await message_carrier.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        context.chat_data.update({'chat_id': sent_message.chat_id, 'last_message_id': sent_message.message_id})


def main() -> None:
    application = Application.builder().token(TELEGRAM_TOKEN).build()

    # Handlers de Conversação para Módulos
    websocket_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_websocket_menu, pattern='^conn_websocket$')],
        states={
            WEBSOCKET_MENU: [CallbackQueryHandler(websocket_menu_handler, pattern='^ws_')],
            GET_WS_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ws_port)],
            GET_WS_MODE: [CallbackQueryHandler(get_ws_mode, pattern='^ws_mode_')],
            GET_WS_MSG: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ws_msg_and_start)],
            CONFIRM_UNINSTALL_WS: [
                CallbackQueryHandler(confirm_uninstall_ws, pattern='^ws_uninstall_confirm$'),
                CallbackQueryHandler(start_websocket_menu, pattern='^ws_cancel_uninstall$')
            ],
        },
        fallbacks=[CallbackQueryHandler(cancel, pattern='^back_to_connection_menu$')],
        map_to_parent={ConversationHandler.END: CONNECTION_MENU}
    )
    badvpn_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_badvpn_menu, pattern='^conn_badvpn$')],
        states={
            BADVPN_MENU: [CallbackQueryHandler(badvpn_menu_handler, pattern='^badvpn_')],
            GET_BADVPN_NEW_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_badvpn_new_port_and_run)],
        },
        fallbacks=[CallbackQueryHandler(cancel, pattern='^back_to_connection_menu$')],
        map_to_parent={ConversationHandler.END: CONNECTION_MENU}
    )
    
    # Handler da Conversa Principal de Conexão
    connection_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_connection_menu, pattern='^start_connection_menu$')],
        states={CONNECTION_MENU: [websocket_conv, badvpn_conv]}, # Adicione outros módulos aqui
        fallbacks=[CommandHandler('cancelar', cancel), CallbackQueryHandler(cancel, pattern='^back_to_main$')],
    )
    
    # Handlers de Conversa do Menu Principal
    create_user_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_create_user_convo, pattern='^start_create_user$')],
        states={
            GET_USER_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_username)],
            GET_USER_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_password)],
            GET_USER_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_days)],
            GET_USER_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_limit_and_create)],
        },
        fallbacks=[CommandHandler('cancelar', cancel), CallbackQueryHandler(cancel, pattern='^back_to_main$')]
    )
    create_test_user_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_create_test_user_convo, pattern='^start_create_test_user$')],
        states={
            GET_TEST_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_user_username)],
            GET_TEST_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_user_password)],
            GET_TEST_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_user_limit)],
            GET_TEST_DURATION: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_duration_and_create)],
        },
        fallbacks=[CommandHandler('cancelar', cancel), CallbackQueryHandler(cancel, pattern='^back_to_main$')]
    )
    delete_user_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_delete_user, pattern='^start_delete_user$')],
        states={
            GET_USER_TO_DELETE: [CallbackQueryHandler(get_user_to_delete, pattern='^del_'), CallbackQueryHandler(confirm_delete_all_users_prompt, pattern='^del_all$')],
            CONFIRM_DELETE_USER: [CallbackQueryHandler(confirm_delete_single_user, pattern='^confirm_delete_user$')],
            CONFIRM_DELETE_ALL: [CallbackQueryHandler(execute_delete_all_users, pattern='^confirm_delete_all$')]
        },
        fallbacks=[CommandHandler('cancelar', cancel), CallbackQueryHandler(cancel, pattern='^back_to_main$')]
    )
    backup_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_backup_menu, pattern='^start_backup$')],
        states={
            BACKUP_MENU: [CallbackQueryHandler(backup_menu_handler, pattern='^backup_')],
            CONFIRM_RESTORE: [CallbackQueryHandler(confirm_restore_handler, pattern='^confirm_restore$|^cancel_restore$')],
        },
        fallbacks=[CommandHandler('cancelar', cancel), CallbackQueryHandler(cancel, pattern='^back_to_main$')]
    )

    # Adicionando todos os handlers à aplicação
    application.add_handler(CommandHandler("start", menu_command))
    application.add_handler(CommandHandler("menu", menu_command))
    application.add_handler(create_user_conv)
    application.add_handler(create_test_user_conv)
    application.add_handler(delete_user_conv)
    application.add_handler(backup_conv)
    application.add_handler(connection_conv)
    application.add_handler(CallbackQueryHandler(user_info_report, pattern='^user_info_report$'))
    application.add_handler(CallbackQueryHandler(online_users_monitor, pattern='^online_users_monitor$'))
    application.add_handler(CallbackQueryHandler(cancel, pattern='^back_to_main$'))

    print("Bot iniciado! Pressione Ctrl+C para parar.")
    application.run_polling()

if __name__ == '__main__':
    main()