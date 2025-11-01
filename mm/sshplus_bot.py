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
import logging

# Configuração de logging para depuração
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

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
    BACKUP_MENU, CONFIRM_GENERATE_LINK, CONFIRM_RESTORE,
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
) = range(44)


# --- Constantes de Caminhos ---
WEBSOCKET_BIN = "/usr/local/bin/WebSocket"
RUSTY_PORTS_FILE = "/opt/rustyproxy/ports"
DRAGON_INSTALL_DIR = "/root/DragonX"
DRAGON_PORTS_FILE = f"{DRAGON_INSTALL_DIR}/ports.list"
BACKUP_FILE_PATH = "/root/backup.vps.tar.gz"


# --- Funções Auxiliares ---

def execute_shell_command(command, input_text=None):
    """Executa um comando de shell e retorna sua saída."""
    logger.info(f"Executing command: {command}")
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, check=False, input=input_text, shell=True
        )
        if result.stderr:
            logger.error(f"Command error: {result.stderr.strip()}")
        return result.stdout.strip()
    except Exception as e:
        logger.error(f"Exception executing command: {e}")
        return ""

async def cleanup_last_message(context: ContextTypes.DEFAULT_TYPE, message_id_to_keep=None):
    """Apaga a última mensagem enviada pelo bot para manter o chat limpo."""
    chat_id = context.chat_data.get('chat_id')
    last_message_id = context.chat_data.get('last_message_id')
    
    if chat_id and last_message_id and last_message_id != message_id_to_keep:
        try:
            await context.bot.delete_message(chat_id=chat_id, message_id=last_message_id)
        except BadRequest:
            logger.warning(f"Could not delete message {last_message_id} in chat {chat_id}.")

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
    query = update.callback_query
    if query:
        await query.answer()
        await menu_command(update, context)
        return ConversationHandler.END

    if update.message:
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

    raw_output = execute_shell_command("/usr/bin/userinfo") # Usando o script original para consistência
    
    if not raw_output:
        report = "❌ Não foi possível gerar o relatório. Verifique se o script `/usr/bin/userinfo` existe e é executável."
    else:
        report = f"👤 *Relatório de Usuários SSH*\n\n```\n{raw_output}\n```"
    
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
    clean_output = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', raw_output) # Remove códigos de cor ANSI
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
    await cleanup_last_message(context, update.message.message_id)
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
    await cleanup_last_message(context, update.message.message_id)
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
    await cleanup_last_message(context, update.message.message_id)
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
    await cleanup_last_message(context, update.message.message_id)
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

# --- Seção: Criação de Usuário de Teste ---

async def start_create_test_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Inicia a conversa para criar um usuário de teste."""
    query = update.callback_query
    await query.answer()
    
    if not execute_shell_command("command -v at"):
        await query.edit_message_text("❌ O comando `at` não está instalado. Por favor, instale-o (`sudo apt-get install at`) para usar esta função.")
        return ConversationHandler.END

    await query.edit_message_text("Qual o nome do usuário de teste?")
    context.chat_data['last_message_id'] = query.message.message_id
    return GET_TEST_USERNAME

async def get_test_user_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context, update.message.message_id)
    username = update.message.text.strip()
    if not username or not username.isalnum() or len(username) < 2 or len(username) > 10:
        sent = await update.message.reply_text("Nome inválido (2-10 letras/números). Tente novamente.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_TEST_USERNAME
    if execute_shell_command(f"id -u {username}"):
        sent = await update.message.reply_text("❌ Este usuário já existe. Tente outro nome.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_TEST_USERNAME
    context.user_data['test_username'] = username
    sent = await update.message.reply_text("Qual a senha (mínimo 4 caracteres)?")
    context.chat_data['last_message_id'] = sent.message_id
    return GET_TEST_PASSWORD

async def get_test_user_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context, update.message.message_id)
    password = update.message.text.strip()
    if not password or len(password) < 4:
        sent = await update.message.reply_text("Senha inválida (mínimo 4 caracteres). Tente novamente.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_TEST_PASSWORD
    context.user_data['test_password'] = password
    sent = await update.message.reply_text("Qual o limite de conexões?")
    context.chat_data['last_message_id'] = sent.message_id
    return GET_TEST_LIMIT

async def get_test_user_limit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context, update.message.message_id)
    limit = update.message.text.strip()
    if not limit.isdigit() or int(limit) < 1:
        sent = await update.message.reply_text("Limite inválido. Insira um número maior que 0.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_TEST_LIMIT
    context.user_data['test_limit'] = limit
    sent = await update.message.reply_text("Por quantos *minutos* a conta será válida?")
    context.chat_data['last_message_id'] = sent.message_id
    return GET_TEST_DURATION

async def get_test_duration_and_create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await cleanup_last_message(context, update.message.message_id)
    duration = update.message.text.strip()
    if not duration.isdigit() or int(duration) < 1:
        sent = await update.message.reply_text("Duração inválida. Insira um número de minutos maior que 0.")
        context.chat_data['last_message_id'] = sent.message_id
        return GET_TEST_DURATION

    sent = await update.message.reply_text("⚙️ Processando... Criando usuário de teste.")
    context.chat_data['last_message_id'] = sent.message_id

    nome = context.user_data['test_username']
    pasw = context.user_data['test_password']
    limit = context.user_data['test_limit']

    # Criar usuário
    execute_shell_command(f"useradd -M -s /bin/false {nome}")
    execute_shell_command(f'echo "{nome}:{pasw}" | chpasswd')
    os.makedirs("/etc/SSHPlus/senha", exist_ok=True)
    with open(f"/etc/SSHPlus/senha/{nome}", "w") as f: f.write(pasw)
    with open("/root/usuarios.db", "a") as f: f.write(f"{nome} {limit}\n")

    # Script de remoção
    remover_script_path = f"/tmp/remover_{nome}.sh"
    remover_script_content = f"""#!/bin/bash
pkill -f "{nome}"
userdel --force {nome}
grep -v "^{nome} " /root/usuarios.db > /tmp/usuarios.db.tmp && mv /tmp/usuarios.db.tmp /root/usuarios.db
rm -f /etc/SSHPlus/senha/{nome}
rm -- "$0"
"""
    with open(remover_script_path, "w") as f:
        f.write(remover_script_content)
    execute_shell_command(f"chmod +x {remover_script_path}")
    
    # Agendar remoção com 'at'
    execute_shell_command(f'echo "{remover_script_path}" | at now + {duration} minutes')

    ip_servidor = execute_shell_command("wget -qO- ifconfig.me")
    success_message = (f"✅ *Conta de Teste Criada!*\n\n"
                       f"🌐 *IP:* `{ip_servidor}`\n👤 *Usuário:* `{nome}`\n🔑 *Senha:* `{pasw}`\n"
                       f"📶 *Limite:* `{limit}`\n"
                       f"⏳ *Expira em:* `{duration} minutos`\n\n"
                       f"A conta será *automaticamente deletada* após o tempo expirar.")
    
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
        await menu_command(update, context, is_follow_up=True)
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
    await menu_command(update, context, is_follow_up=True)
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
    
    open("/root/usuarios.db", 'w').close()
    
    await query.edit_message_text("✅ Todos os usuários foram removidos com sucesso.")
    await menu_command(update, context, is_follow_up=True)
    return ConversationHandler.END

# --- Seção: Backup e Restauração ---

async def start_backup_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Exibe o menu de backup."""
    query = update.callback_query
    await query.answer()
    
    backup_exists = "✅" if os.path.exists(BACKUP_FILE_PATH) else "❌"
    
    keyboard = [
        [InlineKeyboardButton("➕ Criar Backup Agora", callback_data='backup_create')],
        [InlineKeyboardButton(f"🌐 Gerar Link de Download {backup_exists}", callback_data='backup_link')],
        [InlineKeyboardButton(f"🔄 Restaurar do Backup {backup_exists}", callback_data='backup_restore')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]
    ]
    await query.edit_message_text("🗄️ *Gerenciador de Backup*\n\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return BACKUP_MENU

async def backup_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'backup_create':
        await query.edit_message_text("⚙️ Criando backup... Isso pode levar um momento.")
        # Comprime os diretórios e arquivos essenciais
        command = f"tar --warning=no-file-changed -czf {BACKUP_FILE_PATH} /root/usuarios.db /etc/shadow /etc/passwd /etc/group /etc/gshadow /etc/SSHPlus/senha"
        execute_shell_command(command)
        if os.path.exists(BACKUP_FILE_PATH):
            await query.edit_message_text("✅ Backup criado com sucesso!\nSalvo em: `{}`".format(BACKUP_FILE_PATH), parse_mode=ParseMode.MARKDOWN)
        else:
            await query.edit_message_text("❌ Falha ao criar o backup.")
        return await start_backup_menu(update, context) # Volta para o menu de backup

    elif action == 'backup_link':
        if not os.path.exists(BACKUP_FILE_PATH):
            await query.message.reply_text("❌ Arquivo de backup não encontrado. Crie um primeiro.")
            return BACKUP_MENU
            
        web_dir = "/var/www/html"
        if not os.path.isdir(web_dir) or not execute_shell_command("pgrep -f 'apache2|nginx|lighttpd'"):
            await query.message.reply_text("❌ Nenhum servidor web (Apache, Nginx) parece estar ativo ou o diretório `/var/www/html` não existe. Não é possível gerar o link.")
            return BACKUP_MENU
            
        execute_shell_command(f"cp {BACKUP_FILE_PATH} {web_dir}/")
        ip = execute_shell_command("wget -qO- ifconfig.me")
        link = f"http://{ip}/backup.vps.tar.gz"
        await query.message.reply_text(f"✅ Link para download:\n`{link}`\n\n*AVISO:* Este link é público! Remova o arquivo do diretório web após o download por segurança.", parse_mode=ParseMode.MARKDOWN)
        return BACKUP_MENU

    elif action == 'backup_restore':
        if not os.path.exists(BACKUP_FILE_PATH):
            await query.message.reply_text("❌ Arquivo de backup não encontrado.")
            return BACKUP_MENU
        keyboard = [
            [InlineKeyboardButton("SIM, RESTAURAR AGORA", callback_data='confirm_restore')],
            [InlineKeyboardButton("NÃO, CANCELAR", callback_data='cancel_restore')]
        ]
        await query.edit_message_text("⚠️ *ATENÇÃO*\n\nRestaurar um backup irá sobrescrever todos os usuários e senhas atuais. Esta ação é irreversível. Deseja continuar?",
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_RESTORE

    return BACKUP_MENU

async def confirm_restore_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()

    if query.data == 'confirm_restore':
        await query.edit_message_text("⚙️ Restaurando backup... O sistema pode ficar instável por alguns momentos.")
        command = f"tar -xzf {BACKUP_FILE_PATH} -C /"
        execute_shell_command(command)
        await query.edit_message_text("✅ Backup restaurado com sucesso!")
    else: # cancel_restore
        await query.edit_message_text("Operação de restauração cancelada.")

    await menu_command(update, context, is_follow_up=True)
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

# --- Módulo: BadVPN --- 

def get_badvpn_status():
    udpgw_procs = execute_shell_command("ps x | grep -w 'badvpn-udpgw' | grep -v grep")
    tun2socks_procs = execute_shell_command("ps x | grep -w 'badvpn-tun2socks' | grep -v grep")
    if udpgw_procs or tun2socks_procs:
        status = "ATIVO"
        ports = execute_shell_command("netstat -npltu | grep 'badvpn-ud' | awk '{print $4}' | cut -d: -f2 | xargs") or "N/A"
    else:
        status = "INATIVO"
        ports = "Nenhuma"
    return status, ports

async def start_badvpn_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    status, ports = get_badvpn_status()
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
        status, _ = get_badvpn_status()
        if status == "ATIVO":
            await query.edit_message_text("⚙️ Desativando todos os serviços BadVPN...")
            execute_shell_command("screen -ls | grep -E '.udpvpn|.tun2socks' | awk '{print $1}' | xargs -I {} screen -S {} -X quit")
            await query.edit_message_text("✅ BadVPN desativado com sucesso!")
        else:
            await query.edit_message_text("⚙️ Ativando BadVPN (Porta 7300 e Tun2Socks)...")
            # Instala se não existir
            execute_shell_command("wget -O /bin/badvpn-udpgw https://bit.ly/3zV39hE -q && chmod +x /bin/badvpn-udpgw")
            execute_shell_command("wget -O /bin/badvpn-tun2socks https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/badvpn-tun2socks -q && chmod +x /bin/badvpn-tun2socks")
            
            # Inicia os serviços
            execute_shell_command("screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000")
            execute_shell_command("screen -dmS tun2socks /bin/badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.0.2 --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080")
            
            await query.edit_message_text("✅ BadVPN (UDPGW + TUN2SOCKS) ativado com sucesso!")
        return await start_badvpn_menu(update, context)

    elif action == 'badvpn_add_port':
        if get_badvpn_status()[0] == "INATIVO":
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
    execute_shell_command(f"screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:{port} --max-clients 10000")
    await sent.edit_text(f"✅ Porta UDP {port} ativada com sucesso!")
    
    await start_badvpn_menu(update, context)
    return ConversationHandler.END
    
# ... (O restante dos módulos como WebSocket, Rusty, etc., que já estavam bons, podem ser colados aqui sem alterações)
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
    execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit")
    
    cmd = f"{WEBSOCKET_BIN} -proxy_port 0.0.0.0:{port} -msg='{msg}'"
    if mode == 'ws_mode_tls': cmd += " -tls=true"
    
    execute_shell_command(f"screen -dmS ws {cmd}")
    
    if "ws" in execute_shell_command("screen -list"):
        await update.message.reply_text("✅ Serviço WebSocket iniciado com sucesso!")
    else:
        await update.message.reply_text("❌ Erro ao iniciar o serviço WebSocket.")
    
    await start_websocket_menu(update, context)
    return ConversationHandler.END

async def confirm_uninstall_ws(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o WebSocket...")
    execute_shell_command(f"pkill -f {WEBSOCKET_BIN}; screen -S ws -X quit; rm -f {WEBSOCKET_BIN}")
    await query.edit_message_text("✅ WebSocket desinstalado com sucesso.")
    return await start_websocket_menu(update, context)

# --- (Restante dos módulos aqui) ---
# --- Módulo: Rusty Proxy --- 
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
        output = execute_shell_command("rustyproxy") # O script rusty.sh usa 'rustyproxy' como comando principal
        await query.edit_message_text(f"✅ *Resultado da Instalação:*\n\n```\n{output or 'Instalação concluída.'}\n```", parse_mode=ParseMode.MARKDOWN)
        return await start_rusty_menu(update, context)

    elif action == 'rusty_uninstall':
        keyboard = [[InlineKeyboardButton("Sim, tenho certeza", callback_data='rusty_uninstall_confirm'), InlineKeyboardButton("Não, cancelar", callback_data='rusty_cancel_uninstall')]]
        await query.edit_message_text("⚠️ Tem certeza que deseja remover o Rusty Proxy?", reply_markup=InlineKeyboardMarkup(keyboard))
        return CONFIRM_UNINSTALL_RUSTY
    
    elif action == 'back_to_connection_menu':
        await menu_command(update, context, is_follow_up=True)
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
    # O script original não parece ter um comando direto para adicionar com status.
    # Vamos assumir que o comando é via o binário, como estava antes.
    output = execute_shell_command(f'/opt/rustyproxy/proxyrust --port {port} --status "{status}"')
    await update.message.reply_text(f"✅ *Resultado:*\n\n```\n{output}\n```", parse_mode=ParseMode.MARKDOWN)
    
    await start_rusty_menu(update, context)
    return ConversationHandler.END

async def get_rusty_del_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return GET_RUSTY_DEL_PORT
    await update.message.reply_text(f"⚙️ Fechando a porta {port}...")
    # Adaptação baseada no script rusty.sh
    execute_shell_command(f"systemctl stop proxyrust{port}.service && systemctl disable proxyrust{port}.service")
    await update.message.reply_text(f"✅ Porta {port} fechada com sucesso.")
    
    await start_rusty_menu(update, context)
    return ConversationHandler.END

async def confirm_uninstall_rusty(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.edit_message_text("⚙️ Desinstalando o Rusty Proxy...")
    # Lógica baseada em rusty.sh
    execute_shell_command("systemctl stop $(systemctl list-unit-files | grep proxyrust | awk '{print $1}')")
    execute_shell_command("systemctl disable $(systemctl list-unit-files | grep proxyrust | awk '{print $1}')")
    execute_shell_command("rm -rf /opt/rustyproxy /usr/local/bin/rustyproxy /etc/systemd/system/proxyrust*")
    await query.edit_message_text(f"✅ Rusty Proxy desinstalado.", parse_mode=ParseMode.MARKDOWN)
    return await start_rusty_menu(update, context)

# --- (Resto dos módulos aqui) ---
async def menu_command(update: Update, context: ContextTypes.DEFAULT_TYPE, is_follow_up=False) -> None:
    """Exibe o menu principal de ações."""
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
        # Se for um callback ou uma continuação, edita a mensagem existente
        if context.chat_data.get('last_message_id'):
            try:
                await context.bot.edit_message_text(
                    chat_id=message_carrier.chat_id,
                    message_id=context.chat_data['last_message_id'],
                    text=text,
                    reply_markup=InlineKeyboardMarkup(keyboard),
                    parse_mode=ParseMode.MARKDOWN
                )
            except BadRequest: # Se a mensagem não mudou, o Telegram pode dar erro
                pass
        else: # Fallback caso o ID da mensagem se perca
             sent_message = await message_carrier.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
             context.chat_data.update({'chat_id': sent_message.chat_id, 'last_message_id': sent_message.message_id})

    else:
        # Se for um comando /start ou /menu, envia uma nova mensagem
        await cleanup_last_message(context)
        sent_message = await message_carrier.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        context.chat_data.update({'chat_id': sent_message.chat_id, 'last_message_id': sent_message.message_id})


def main() -> None:
    """Inicia o bot e configura todos os handlers."""
    application = Application.builder().token(TELEGRAM_TOKEN).build()

    # --- Handlers de Conversação Aninhados para os Módulos de Conexão ---
    
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
    
    rusty_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_rusty_menu, pattern='^conn_rusty$')],
        states={
            RUSTY_MENU: [CallbackQueryHandler(rusty_menu_handler, pattern='^rusty_')],
            GET_RUSTY_ADD_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_rusty_add_port)],
            GET_RUSTY_ADD_STATUS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_rusty_add_status_and_run)],
            GET_RUSTY_DEL_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_rusty_del_port_and_run)],
            CONFIRM_UNINSTALL_RUSTY: [
                CallbackQueryHandler(confirm_uninstall_rusty, pattern='^rusty_uninstall_confirm$'),
                CallbackQueryHandler(start_rusty_menu, pattern='^rusty_cancel_uninstall$')
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

    # ... (outros conversation handlers de conexão)
    
    # --- Handlers de Conversação Principais ---
    
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
            GET_USER_TO_DELETE: [
                CallbackQueryHandler(get_user_to_delete, pattern='^del_'),
                CallbackQueryHandler(confirm_delete_all_users_prompt, pattern='^del_all$')
            ],
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

    connection_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_connection_menu, pattern='^start_connection_menu$')],
        states={
            CONNECTION_MENU: [
                websocket_conv, rusty_conv, badvpn_conv, # Adicionar outros aqui...
            ],
        },
        fallbacks=[CommandHandler('cancelar', cancel), CallbackQueryHandler(cancel, pattern='^back_to_main$')],
    )
    
    # Adicionando todos os handlers à aplicação
    application.add_handler(CommandHandler("start", menu_command))
    application.add_handler(CommandHandler("menu", menu_command))
    
    application.add_handler(create_user_conv)
    application.add_handler(create_test_user_conv)
    application.add_handler(delete_user_conv)
    application.add_handler(backup_conv)
    application.add_handler(connection_conv)

    # Handlers para botões que não iniciam uma conversa
    application.add_handler(CallbackQueryHandler(user_info_report, pattern='^user_info_report$'))
    application.add_handler(CallbackQueryHandler(online_users_monitor, pattern='^online_users_monitor$'))
    # Handler genérico para voltar ao menu
    application.add_handler(CallbackQueryHandler(cancel, pattern='^back_to_main$'))

    print("Bot iniciado! Pressione Ctrl+C para parar.")
    application.run_polling()

if __name__ == '__main__':
    main()