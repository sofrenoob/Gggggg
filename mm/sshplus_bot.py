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
TELEGRAM_TOKEN = "SEU_TOKEN_AQUI" # COLOQUE SEU TOKEN AQUI
ADMIN_USER_ID = 123456789  # COLOQUE SEU ID NUMÉRICO AQUI
# ==========================================================


# --- Definição dos Estados (Método à prova de erros) ---
_states = [
    "GET_USER_USERNAME", "GET_USER_PASSWORD", "GET_USER_DAYS", "GET_USER_LIMIT",
    "GET_TEST_USERNAME", "GET_TEST_PASSWORD", "GET_TEST_LIMIT", "GET_TEST_DURATION",
    "GET_USER_TO_DELETE", "CONFIRM_DELETE_USER", "CONFIRM_DELETE_ALL",
    "BACKUP_MENU", "CONFIRM_RESTORE",
    "CONNECTION_MENU",
    "WEBSOCKET_MENU", "GET_WS_PORT", "GET_WS_MODE", "GET_WS_MSG", "CONFIRM_UNINSTALL_WS",
    "RUSTY_MENU", "GET_RUSTY_ADD_PORT", "GET_RUSTY_ADD_STATUS", "GET_RUSTY_DEL_PORT", "CONFIRM_UNINSTALL_RUSTY",
    "STUNNEL_MENU", "STUNNEL_INSTALL_MODE", "GET_STUNNEL_INSTALL_PORT", "STUNNEL_MANAGE_MENU", "GET_STUNNEL_CHANGE_PORT", "CONFIRM_UNINSTALL_STUNNEL",
    "BADVPN_MENU", "GET_BADVPN_NEW_PORT",
    "DRAGON_MENU", "GET_DRAGON_ADD_PORT", "GET_DRAGON_STOP_PORT", "GET_DRAGON_RESTART_PORT", "CONFIRM_UNINSTALL_DRAGON",
    "SLOWDNS_MENU", "SLOWDNS_INSTALL_MODE", "GET_SLOWDNS_NS", "GET_SLOWDNS_KEY_CHOICE", "CONFIRM_UNINSTALL_SLOWDNS"
]
for i, state_name in enumerate(_states):
    globals()[state_name] = i
# Fim da definição de estados


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

# --- Seção: ShellBot (Comando /shell) ---

async def shell_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Executa um comando de shell enviado pelo usuário."""
    if not await is_admin(update): return

    # O comando é o texto após /shell
    command = " ".join(context.args)
    
    if not command:
        await update.message.reply_text("❌ Por favor, forneça um comando para executar (ex: `/shell ls -la`).")
        return

    sent_message = await update.message.reply_text(f"⚙️ Executando comando: `{command}`...", parse_mode=ParseMode.MARKDOWN)
    
    # Executa o comando de shell
    raw_output = await execute_shell_command(command)
    
    # Formata a saída
    if raw_output:
        # Limpa caracteres de controle ANSI (cores, etc.)
        clean_output = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', raw_output)
        
        # Limita o tamanho da resposta para evitar erros do Telegram
        if len(clean_output) > 4000:
            clean_output = clean_output[:3900] + "\n... (saída truncada)"
            
        response = f"✅ *Saída do Comando:*\n\n```bash\n{clean_output}\n```"
    else:
        # Se não houver saída, verifica se houve erro (execute_shell_command retorna string vazia em caso de erro)
        # Como o execute_shell_command não retorna o stderr, vamos assumir que se não há output,
        # o comando pode ter falhado ou não ter produzido saída.
        response = f"✅ Comando executado. Nenhuma saída produzida ou falha na execução."

    try:
        await sent_message.edit_text(response, parse_mode=ParseMode.MARKDOWN)
    except BadRequest as e:
        # Se a edição falhar (ex: erro de formatação Markdown), envia como texto simples
        await sent_message.edit_text(f"✅ Comando executado. Saída:\n\n{raw_output}")

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Envia o menu principal como uma nova mensagem, limpando o estado anterior."""
    if not await is_admin(update): return
    
    chat_id = update.effective_chat.id
    
    # Limpa mensagens anteriores para evitar confusão
    if 'last_menu_id' in context.chat_data:
        try:
            await context.bot.delete_message(chat_id, context.chat_data['last_menu_id'])
        except BadRequest:
            pass # A mensagem pode já ter sido deletada

    keyboard = [
        [InlineKeyboardButton("➕ Criar Usuário", callback_data='start_create_user'), InlineKeyboardButton("⚡ Criar Teste", callback_data='start_create_test_user')],
        [InlineKeyboardButton("➖ Remover Usuário", callback_data='start_delete_user'), InlineKeyboardButton("🗄️ Backup/Restore", callback_data='start_backup')],
        [InlineKeyboardButton("ℹ️ Info Usuários", callback_data='user_info_report'), InlineKeyboardButton("📊 Online", callback_data='online_users_monitor')],
        [InlineKeyboardButton("🔌 Conexão", callback_data='start_connection_menu')]
    ]
    text = "🤖 *Gerenciador SSHPlus*\n\nSelecione uma opção:"
    
    # CORREÇÃO: Usar update.effective_message para garantir que a resposta seja enviada corretamente
    # independentemente de ser um comando /start ou um callback 'back_to_main'.
    message_carrier = update.effective_message
    if not message_carrier:
        # Se não houver effective_message (ex: após um delete), tenta usar o chat_id
        sent_message = await context.bot.send_message(chat_id, text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    else:
        sent_message = await message_carrier.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        
    context.chat_data['last_menu_id'] = sent_message.message_id

async def end_conversation(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Finaliza qualquer conversa ativa e mostra o menu principal."""
    query = update.callback_query
    if query:
        await query.answer()
        try:
            # CORREÇÃO: Deletar a mensagem do menu anterior antes de enviar o novo
            await query.message.delete()
        except BadRequest:
            logger.warning("Could not delete message, maybe it was already deleted.")
    
    # CORREÇÃO: Passar o objeto 'update' correto para start_command.
    # Se for um callback, o 'update' já está correto. Se for um fallback de texto,
    # o 'update' é o objeto Message.
    await start_command(update, context)
    return ConversationHandler.END


# --- Funções de Relatório ---

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
    if not await is_admin(update): return ConversationHandler.END # Adicionado check de admin
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

    # Limpa as mensagens de input
    try:
        await context.bot.delete_message(chat_id=update.effective_chat.id, message_id=update.message.message_id)
    except BadRequest: pass

    sent_message = await context.bot.send_message(chat_id=update.effective_chat.id, text="⚙️ Processando... Criando usuário.")

    nome = context.user_data['user_username']
    pasw = context.user_data['user_password']
    dias = int(context.user_data['user_days'])

    data_final = (datetime.now() + timedelta(days=dias)).strftime('%Y-%m-%d')
    
    # Lógica de criação de usuário (mantida a partir do código original)
    await execute_shell_command(f"useradd -M -s /bin/false -e {data_final} {nome}")
    await execute_shell_command(f'echo "{nome}:{pasw}" | chpasswd')
    os.makedirs("/etc/SSHPlus/senha", exist_ok=True)
    with open(f"/etc/SSHPlus/senha/{nome}", "w") as f: f.write(pasw)
    with open("/root/usuarios.db", "a") as f: f.write(f"{nome} {limit}\n")

    ip_servidor = await execute_shell_command("wget -qO- ifconfig.me")
    gui_data = (datetime.now() + timedelta(days=dias)).strftime('%d/%m/%Y')
    success_message = (f"✅ *Conta SSH Criada!*\n\n"
                       f"👤 *Usuário:* `{nome}`\n"
                       f"🔑 *Senha:* `{pasw}`\n"
                       f"🔗 *Limite:* `{limit}`\n"
                       f"🗓️ *Expira em:* `{gui_data}`\n"
                       f"🌐 *IP:* `{ip_servidor}`\n\n"
                       f"Use o comando /menu para voltar ao menu principal.")

    await sent_message.edit_text(success_message, parse_mode=ParseMode.MARKDOWN)
    
    # CORREÇÃO: Limpar user_data após a conclusão da conversa
    context.user_data.clear()
    
    return ConversationHandler.END

# --- Seção: Criação de Teste ---

async def start_create_test_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END # Adicionado check de admin
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("Qual o nome do usuário de teste?")
    return GET_TEST_USERNAME

async def get_test_user_username(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    username = update.message.text.strip()
    if not username or not username.isalnum() or not (2 <= len(username) <= 10):
        await update.message.reply_text("Nome inválido (2-10 letras/números). Tente novamente.")
        return GET_TEST_USERNAME
    if await execute_shell_command(f"id -u {username}"):
        await update.message.reply_text("❌ Este usuário já existe. Tente outro nome.")
        return GET_TEST_USERNAME
    context.user_data['test_username'] = username
    await update.message.reply_text("Ótimo. Agora, qual a senha (mínimo 4 caracteres)?")
    return GET_TEST_PASSWORD

async def get_test_user_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    password = update.message.text.strip()
    if not password or len(password) < 4:
        await update.message.reply_text("Senha inválida (mínimo 4 caracteres). Tente novamente.")
        return GET_TEST_PASSWORD
    context.user_data['test_password'] = password
    await update.message.reply_text("Qual o limite de conexões simultâneas para o teste?")
    return GET_TEST_LIMIT

async def get_test_user_limit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    limit = update.message.text.strip()
    if not limit.isdigit() or int(limit) < 1:
        await update.message.reply_text("Limite inválido. Insira um número > 0.")
        return GET_TEST_LIMIT
    context.user_data['test_limit'] = limit
    await update.message.reply_text("Qual a duração do teste em horas?")
    return GET_TEST_DURATION

async def get_test_duration_and_create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    duration_hours = update.message.text.strip()
    if not duration_hours.isdigit() or int(duration_hours) < 1:
        await update.message.reply_text("Duração inválida. Insira um número de horas > 0.")
        return GET_TEST_DURATION

    # Limpa as mensagens de input
    try:
        await context.bot.delete_message(chat_id=update.effective_chat.id, message_id=update.message.message_id)
    except BadRequest: pass

    sent_message = await context.bot.send_message(chat_id=update.effective_chat.id, text="⚙️ Processando... Criando usuário de teste.")

    nome = context.user_data['test_username']
    pasw = context.user_data['test_password']
    limit = context.user_data['test_limit']
    duration = int(duration_hours)

    # Data de expiração em horas
    data_final = (datetime.now() + timedelta(hours=duration)).strftime('%Y-%m-%d')
    
    # Lógica de criação de usuário de teste (mantida a partir do código original)
    await execute_shell_command(f"useradd -M -s /bin/false -e {data_final} {nome}")
    await execute_shell_command(f'echo "{nome}:{pasw}" | chpasswd')
    os.makedirs("/etc/SSHPlus/senha", exist_ok=True)
    with open(f"/etc/SSHPlus/senha/{nome}", "w") as f: f.write(pasw)
    with open("/root/usuarios.db", "a") as f: f.write(f"{nome} {limit}\n")

    ip_servidor = await execute_shell_command("wget -qO- ifconfig.me")
    gui_data = (datetime.now() + timedelta(hours=duration)).strftime('%d/%m/%Y %H:%M')
    success_message = (f"✅ *Conta SSH de Teste Criada!*\n\n"
                       f"👤 *Usuário:* `{nome}`\n"
                       f"🔑 *Senha:* `{pasw}`\n"
                       f"🔗 *Limite:* `{limit}`\n"
                       f"⏱️ *Duração:* `{duration}` horas\n"
                       f"🗓️ *Expira em:* `{gui_data}`\n"
                       f"🌐 *IP:* `{ip_servidor}`\n\n"
                       f"Use o comando /menu para voltar ao menu principal.")

    await sent_message.edit_text(success_message, parse_mode=ParseMode.MARKDOWN)
    
    # CORREÇÃO: Limpar user_data após a conclusão da conversa
    context.user_data.clear()
    
    return ConversationHandler.END

# --- Seção: Remoção de Usuário ---

async def get_users_list():
    """Retorna uma lista de usuários SSH criados pelo bot."""
    user_list_raw = await execute_shell_command("cat /etc/passwd | grep -E ':/bin/(false|nologin)$' | cut -d: -f1")
    # Filtra usuários do sistema
    users = [u for u in user_list_raw.split('\n') if u and u not in ['root', 'daemon', 'bin', 'sys', 'sync', 'games', 'man', 'lp', 'mail', 'news', 'uucp', 'proxy', 'www-data', 'backup', 'list', 'irc', 'gnats', 'nobody', 'systemd-network', 'systemd-resolve', 'systemd-timesync', 'messagebus', 'syslog', 'netdata', 'sshd']]
    return users

async def start_delete_user_convo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    
    users = await get_users_list()
    
    keyboard = []
    for user in users:
        keyboard.append([InlineKeyboardButton(f"🗑️ {user}", callback_data=f'delete_user_{user}')])
    
    keyboard.append([InlineKeyboardButton("❌ Excluir Todos", callback_data='delete_all_users_prompt')])
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')])
    
    text = "👤 *Remover Usuário*\n\nSelecione o usuário para remover ou uma opção:"
    
    await query.message.edit_text(text, parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_USER_TO_DELETE

async def get_user_to_delete(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    username = query.data.replace('delete_user_', '')
    context.user_data['user_to_delete'] = username
    
    keyboard = [
        [InlineKeyboardButton("✅ Confirmar Exclusão", callback_data='confirm_delete')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_delete_menu')]
    ]
    
    await query.message.edit_text(f"Tem certeza que deseja excluir o usuário *{username}*?", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(keyboard))
    return CONFIRM_DELETE_USER

async def confirm_delete_single_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    username = context.user_data.get('user_to_delete')
    
    if not username:
        await query.message.edit_text("❌ Erro: Usuário não especificado. Voltando ao menu principal.", reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]]))
        return ConversationHandler.END
        
    await query.message.edit_text(f"⚙️ Excluindo usuário *{username}*...", parse_mode=ParseMode.MARKDOWN)
    
    # Lógica de exclusão (mantida a partir do código original)
    await execute_shell_command(f"userdel --force {username}")
    await execute_shell_command(f"rm -f /etc/SSHPlus/senha/{username}")
    
    # Lógica para remover do usuarios.db (simplificada)
    await execute_shell_command(f"sed -i '/^{username} /d' /root/usuarios.db")
    
    await query.message.edit_text(f"✅ Usuário *{username}* excluído com sucesso!", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]]))
    
    context.user_data.clear()
    return ConversationHandler.END

async def delete_all_users_prompt(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    keyboard = [
        [InlineKeyboardButton("⚠️ SIM, Excluir TODOS", callback_data='confirm_delete_all')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='restart_delete_menu')]
    ]
    
    await query.message.edit_text("⚠️ *ATENÇÃO!* Esta ação excluirá *TODOS* os usuários SSH criados pelo bot. Tem certeza?", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup(keyboard))
    return CONFIRM_DELETE_ALL

async def execute_delete_all_users(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    await query.message.edit_text("⚙️ Excluindo *TODOS* os usuários...", parse_mode=ParseMode.MARKDOWN)
    
    # Lógica para listar e excluir todos os usuários (mantida a partir do código original)
    users_to_delete = await get_users_list()
    
    deleted_count = 0
    for user in users_to_delete:
        await execute_shell_command(f"userdel --force {user}")
        await execute_shell_command(f"rm -f /etc/SSHPlus/senha/{user}")
        deleted_count += 1
        
    # Limpa o arquivo de limite de conexões
    await execute_shell_command("> /root/usuarios.db")
    
    await query.message.edit_text(f"✅ *{deleted_count}* usuários excluídos com sucesso!", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')]]))
    
    context.user_data.clear()
    return ConversationHandler.END

# --- Seção: Backup/Restore ---

async def start_backup_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END # Adicionado check de admin
    query = update.callback_query
    await query.answer()
    
    backup_exists = os.path.exists(BACKUP_FILE_PATH)
    
    keyboard = [
        [InlineKeyboardButton("💾 Fazer Backup", callback_data='backup_create')],
    ]
    
    if backup_exists:
        keyboard.append([InlineKeyboardButton("🔄 Restaurar Backup", callback_data='backup_restore_prompt')])
        
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_main')])
    
    status_text = "Backup existente" if backup_exists else "Nenhum backup encontrado"
    
    await query.message.edit_text(f"🗄️ *Menu de Backup/Restore*\n\nStatus: *{status_text}*", 
                                  reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return BACKUP_MENU

async def backup_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'backup_create':
        await query.message.edit_text("⚙️ Criando backup... Isso pode levar alguns minutos.")
        
        # Comando de backup (mantido a partir do código original)
        backup_command = (
            f"tar -czf {BACKUP_FILE_PATH} "
            f"--exclude='{BACKUP_FILE_PATH}' "
            f"/etc/passwd /etc/shadow /etc/group /etc/gshadow "
            f"/etc/SSHPlus/senha /root/usuarios.db "
            f"/etc/stunnel/stunnel.conf 2>/dev/null"
        )
        await execute_shell_command(backup_command)
        
        if os.path.exists(BACKUP_FILE_PATH):
            await query.message.edit_text("✅ Backup criado com sucesso! Use /menu para voltar.")
        else:
            await query.message.edit_text("❌ Falha ao criar o backup. Verifique os logs.")
            
        return ConversationHandler.END
    
    elif action == 'backup_restore_prompt':
        keyboard = [
            [InlineKeyboardButton("🔥 Sim, Restaurar", callback_data='confirm_restore')],
            [InlineKeyboardButton("↩️ Cancelar", callback_data='back_to_main')]
        ]
        await query.message.edit_text("⚠️ *ATENÇÃO!* A restauração irá sobrescrever as configurações atuais. Continuar?", 
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_RESTORE
    
    return BACKUP_MENU

async def confirm_restore_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'confirm_restore':
        await query.message.edit_text("⚙️ Restaurando backup... Isso pode levar alguns minutos.")
        
        # Comando de restauração (mantido a partir do código original)
        restore_command = f"tar -xzf {BACKUP_FILE_PATH} -C / --overwrite 2>/dev/null"
        await execute_shell_command(restore_command)
        
        # Forçar a atualização dos limites de conexão
        await execute_shell_command("chattr -i /etc/passwd /etc/shadow /etc/group /etc/gshadow")
        await execute_shell_command("chmod 640 /etc/shadow /etc/gshadow")
        
        await query.message.edit_text("✅ Backup restaurado com sucesso! Use /menu para voltar.")
        return ConversationHandler.END
    
    return BACKUP_MENU

# --- Seção: Menu de Conexão ---

async def start_connection_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END # Adicionado check de admin
    query = update.callback_query
    await query.answer()

    # CORREÇÃO: Usar execute_shell_command com 'await' e 'asyncio.gather' para não bloquear o bot
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
    if not await is_admin(update): return ConversationHandler.END # Adicionado check de admin
    query = update.callback_query
    await query.answer()
    
    status, ports = await get_badvpn_status()
    status_text = f"Status: 🟢 *{status}* | Portas: *{ports}*" if status == "ATIVO" else f"Status: 🔴 *{status}*"

    keyboard = [
        [InlineKeyboardButton("🚀 Ativar/Desativar (Padrão 7300)", callback_data='badvpn_toggle_default')],
        [InlineKeyboardButton("➕ Abrir Nova Porta UDP", callback_data='badvpn_add_port')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.message.edit_text(text=f"🔌 *Gerenciador BadVPN PRO*\n\n{status_text}\n\nSelecione uma opção:", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return BADVPN_MENU

async def badvpn_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'badvpn_toggle_default':
        status, _ = await get_badvpn_status()
        if status == "ATIVO":
            await query.message.edit_text("⚙️ Desativando todos os serviços BadVPN...")
            # Comando de desativação (mantido a partir do código original)
            await execute_shell_command("screen -ls | grep -E '.udpvpn|.tun2socks' | awk '{print $1}' | xargs -I {} screen -S {} -X quit")
            await query.message.edit_text("✅ BadVPN desativado com sucesso!")
        else:
            await query.message.edit_text("⚙️ Ativando BadVPN (Porta 7300 e Tun2Socks)...")
            # Comandos de instalação e ativação (mantidos a partir do código original)
            await execute_shell_command("wget -O /bin/badvpn-udpgw https://bit.ly/3zV39hE -q && chmod +x /bin/badvpn-udpgw")
            await execute_shell_command("wget -O /bin/badvpn-tun2socks https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/badvpn-tun2socks -q && chmod +x /bin/badvpn-tun2socks")
            
            await execute_shell_command("screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000")
            await execute_shell_command("screen -dmS tun2socks /bin/badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.0.2 --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080")
            
            await query.message.edit_text("✅ BadVPN (UDPGW + TUN2SOCKS) ativado com sucesso!")
        
        # CORREÇÃO: Chamar start_badvpn_menu para atualizar o menu
        return await start_badvpn_menu(update, context)

    elif action == 'badvpn_add_port':
        status, _ = await get_badvpn_status()
        if status == "INATIVO":
            await query.message.reply_text("❌ Ative o BadVPN Padrão primeiro.")
            return BADVPN_MENU
        await query.message.edit_text("Digite a nova porta UDP a ser aberta:")
        return GET_BADVPN_NEW_PORT
    
    elif action == 'back_to_connection_menu':
        # CORREÇÃO: Chamar start_connection_menu para voltar ao menu anterior
        return await start_connection_menu(update, context)

async def get_badvpn_new_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit():
        await update.message.reply_text("Porta inválida.")
        return GET_BADVPN_NEW_PORT
    
    await update.message.reply_text(f"⚙️ Abrindo porta UDP {port}...")
    
    # Comando para abrir nova porta (mantido a partir do código original)
    await execute_shell_command(f"screen -dmS udpvpn_{port} /bin/badvpn-udpgw --listen-addr 127.0.0.1:{port} --max-clients 10000")
    
    await update.message.reply_text(f"✅ Porta UDP {port} aberta com sucesso!")
    
    # CORREÇÃO: Chamar start_badvpn_menu para atualizar o menu
    return await start_badvpn_menu(update, context)

# --- Módulo: WebSocket ---

async def get_websocket_status():
    if os.path.exists(WEBSOCKET_BIN):
        status = await execute_shell_command("ps x | grep -w 'WebSocket' | grep -v grep")
        if status:
            return "ATIVO"
        return "INATIVO"
    return "NÃO INSTALADO"

async def start_websocket_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    
    status = await get_websocket_status()
    status_text = f"Status: 🟢 *{status}*" if status == "ATIVO" else f"Status: 🔴 *{status}*"

    keyboard = [
        [InlineKeyboardButton("📥 Instalar / Configurar", callback_data='ws_install_prompt')],
    ]
    
    if status == "ATIVO":
        keyboard.append([InlineKeyboardButton("📝 Alterar Mensagem", callback_data='ws_change_msg_prompt')])
        
    if status != "NÃO INSTALADO":
        keyboard.append([InlineKeyboardButton("🗑️ Desinstalar", callback_data='ws_uninstall_prompt')])
        
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')])
    
    await query.message.edit_text(
        text=f"🔌 *Gerenciador WebSocket*\n\n{status_text}\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return WEBSOCKET_MENU

async def websocket_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'ws_install_prompt':
        await query.message.edit_text("Digite a porta do WebSocket (ex: 80, 443, 8080):")
        return GET_WS_PORT
    
    elif action == 'ws_change_msg_prompt':
        await query.message.edit_text("Digite a nova mensagem de conexão (ex: HTTP/1.1 200 OK):")
        return GET_WS_MSG
    
    elif action == 'ws_uninstall_prompt':
        keyboard = [
            [InlineKeyboardButton("✅ Confirmar Desinstalação", callback_data='confirm_uninstall_ws')],
            [InlineKeyboardButton("↩️ Cancelar", callback_data='back_to_websocket_menu')]
        ]
        await query.message.edit_text("⚠️ *ATENÇÃO!* Deseja realmente desinstalar o WebSocket?", 
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_UNINSTALL_WS
    
    elif action == 'back_to_connection_menu':
        return await start_connection_menu(update, context)
    
    return WEBSOCKET_MENU

async def get_ws_port(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_WS_PORT
    
    context.user_data['ws_port'] = port
    
    keyboard = [
        [InlineKeyboardButton("Modo Padrão (HTTP)", callback_data='ws_mode_http')],
        [InlineKeyboardButton("Modo SSL (HTTPS)", callback_data='ws_mode_ssl')]
    ]
    await update.message.reply_text("Selecione o modo de operação:", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_WS_MODE

async def get_ws_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    mode = query.data.replace('ws_mode_', '')
    context.user_data['ws_mode'] = mode
    
    await query.message.edit_text("Digite a mensagem de conexão (ex: HTTP/1.1 200 OK):")
    return GET_WS_MSG

async def get_ws_msg_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    msg = update.message.text.strip()
    context.user_data['ws_msg'] = msg
    
    await update.message.reply_text("⚙️ Processando instalação/configuração...")
    
    port = context.user_data.get('ws_port', '80')
    mode = context.user_data.get('ws_mode', 'http')
    
    # Comando de instalação/configuração (mantido a partir do código original)
    await execute_shell_command("wget -O /tmp/install_ws.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/install_ws.sh -q && chmod +x /tmp/install_ws.sh && /tmp/install_ws.sh")
    
    # Comando de configuração (mantido a partir do código original)
    await execute_shell_command(f"wget -O /tmp/config_ws.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/config_ws.sh -q && chmod +x /tmp/config_ws.sh && /tmp/config_ws.sh {port} {mode} '{msg}'")
    
    await update.message.reply_text(f"✅ WebSocket configurado na porta *{port}* ({mode.upper()}) com sucesso!", parse_mode=ParseMode.MARKDOWN)
    
    context.user_data.clear()
    return ConversationHandler.END

async def confirm_uninstall_ws(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'confirm_uninstall_ws':
        await query.message.edit_text("⚙️ Desinstalando WebSocket...")
        # Comando de desinstalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/uninstall_ws.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/uninstall_ws.sh -q && chmod +x /tmp/uninstall_ws.sh && /tmp/uninstall_ws.sh")
        await query.message.edit_text("✅ WebSocket desinstalado com sucesso!")
        return ConversationHandler.END
    
    elif action == 'back_to_websocket_menu':
        return await start_websocket_menu(update, context)
    
    return CONFIRM_UNINSTALL_WS

# --- Módulo: Rusty Proxy ---

async def get_rusty_status():
    if os.path.exists(RUSTY_PORTS_FILE):
        status = await execute_shell_command("ps x | grep -w 'rustyproxy' | grep -v grep")
        if status:
            return "ATIVO"
        return "INATIVO"
    return "NÃO INSTALADO"

async def start_rusty_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    
    status = await get_rusty_status()
    status_text = f"Status: 🟢 *{status}*" if status == "ATIVO" else f"Status: 🔴 *{status}*"

    keyboard = [
        [InlineKeyboardButton("📥 Instalar / Adicionar Porta", callback_data='rusty_add_port_prompt')],
    ]
    
    if status == "ATIVO":
        keyboard.append([InlineKeyboardButton("🗑️ Remover Porta", callback_data='rusty_del_port_prompt')])
        
    if status != "NÃO INSTALADO":
        keyboard.append([InlineKeyboardButton("❌ Desinstalar", callback_data='rusty_uninstall_prompt')])
        
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')])
    
    await query.message.edit_text(
        text=f"🔌 *Gerenciador Rusty Proxy*\n\n{status_text}\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return RUSTY_MENU

async def rusty_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'rusty_add_port_prompt':
        await query.message.edit_text("Digite a porta a ser adicionada (ex: 80, 443, 8080):")
        return GET_RUSTY_ADD_PORT
    
    elif action == 'rusty_del_port_prompt':
        ports_content = await execute_shell_command(f"cat {RUSTY_PORTS_FILE}")
        ports = [p.strip() for p in ports_content.split('\n') if p.strip()]
        
        if not ports:
            await query.message.edit_text("❌ Nenhuma porta Rusty Proxy ativa para remover.")
            return RUSTY_MENU
            
        keyboard = []
        for port in ports:
            keyboard.append([InlineKeyboardButton(f"🗑️ Porta {port}", callback_data=f'rusty_del_{port}')])
            
        keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_rusty_menu')])
        
        await query.message.edit_text("Selecione a porta a ser removida:", reply_markup=InlineKeyboardMarkup(keyboard))
        return GET_RUSTY_DEL_PORT
    
    elif action == 'rusty_uninstall_prompt':
        keyboard = [
            [InlineKeyboardButton("✅ Confirmar Desinstalação", callback_data='confirm_uninstall_rusty')],
            [InlineKeyboardButton("↩️ Cancelar", callback_data='back_to_rusty_menu')]
        ]
        await query.message.edit_text("⚠️ *ATENÇÃO!* Deseja realmente desinstalar o Rusty Proxy?", 
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_UNINSTALL_RUSTY
    
    elif action == 'back_to_connection_menu':
        return await start_connection_menu(update, context)
    
    return RUSTY_MENU

async def get_rusty_add_port(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_RUSTY_ADD_PORT
    
    context.user_data['rusty_port'] = port
    
    keyboard = [
        [InlineKeyboardButton("Ativar", callback_data='rusty_status_on')],
        [InlineKeyboardButton("Desativar", callback_data='rusty_status_off')]
    ]
    await update.message.reply_text("Deseja ativar o Rusty Proxy após a configuração?", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_RUSTY_ADD_STATUS

async def get_rusty_add_status_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    status = query.data.replace('rusty_status_', '')
    
    await query.message.edit_text("⚙️ Processando instalação/configuração...")
    
    port = context.user_data['rusty_port']
    
    # Comando de instalação/configuração (mantido a partir do código original)
    await execute_shell_command("wget -O /tmp/install_rusty.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/install_rusty.sh -q && chmod +x /tmp/install_rusty.sh && /tmp/install_rusty.sh")
    
    # Comando de configuração (mantido a partir do código original)
    await execute_shell_command(f"wget -O /tmp/config_rusty.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/config_rusty.sh -q && chmod +x /tmp/config_rusty.sh && /tmp/config_rusty.sh {port} {status}")
    
    await query.message.edit_text(f"✅ Rusty Proxy configurado na porta *{port}* com sucesso!", parse_mode=ParseMode.MARKDOWN)
    
    context.user_data.clear()
    return ConversationHandler.END

async def get_rusty_del_port(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    port = query.data.replace('rusty_del_', '')
    
    await query.message.edit_text(f"⚙️ Removendo porta {port} do Rusty Proxy...")
    
    # Comando de remoção de porta (mantido a partir do código original)
    await execute_shell_command(f"sed -i '/{port}/d' {RUSTY_PORTS_FILE}")
    await execute_shell_command("systemctl restart rustyproxy")
    
    await query.message.edit_text(f"✅ Porta {port} removida com sucesso!")
    
    return await start_rusty_menu(update, context)

async def confirm_uninstall_rusty(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'confirm_uninstall_rusty':
        await query.message.edit_text("⚙️ Desinstalando Rusty Proxy...")
        # Comando de desinstalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/uninstall_rusty.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/uninstall_rusty.sh -q && chmod +x /tmp/uninstall_rusty.sh && /tmp/uninstall_rusty.sh")
        await query.message.edit_text("✅ Rusty Proxy desinstalado com sucesso!")
        return ConversationHandler.END
    
    elif action == 'back_to_rusty_menu':
        return await start_rusty_menu(update, context)
    
    return CONFIRM_UNINSTALL_RUSTY

# --- Módulo: Stunnel ---

async def get_stunnel_status():
    if os.path.exists("/etc/stunnel/stunnel.conf"):
        status = await execute_shell_command("ps x | grep -w 'stunnel4' | grep -v grep")
        port_raw = await execute_shell_command("grep 'accept' /etc/stunnel/stunnel.conf | awk '{print $3}'")
        port = port_raw.strip() if port_raw else "N/A"
        if status:
            return "ATIVO", port
        return "INATIVO", port
    return "NÃO INSTALADO", "N/A"

async def start_stunnel_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    
    status, port = await get_stunnel_status()
    status_text = f"Status: 🟢 *{status}* | Porta: *{port}*" if status == "ATIVO" else "Status: 🔴 *INATIVO*"

    keyboard = [
        [InlineKeyboardButton("📥 Instalar / Configurar", callback_data='stunnel_install_prompt')],
    ]
    
    if status == "ATIVO":
        keyboard.append([InlineKeyboardButton("⚙️ Gerenciar", callback_data='stunnel_manage_menu')])
        
    if status != "NÃO INSTALADO":
        keyboard.append([InlineKeyboardButton("🗑️ Desinstalar", callback_data='stunnel_uninstall_prompt')])
        
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')])
    
    await query.message.edit_text(
        text=f"🔌 *Gerenciador SSL Tunnel (Stunnel)*\n\n{status_text}\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return STUNNEL_MENU

async def stunnel_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'stunnel_install_prompt':
        keyboard = [
            [InlineKeyboardButton("Instalar/Reinstalar", callback_data='stunnel_install_mode_install')],
            [InlineKeyboardButton("Apenas Configurar", callback_data='stunnel_install_mode_config')]
        ]
        await query.message.edit_text("Selecione o modo de instalação:", reply_markup=InlineKeyboardMarkup(keyboard))
        return STUNNEL_INSTALL_MODE
    
    elif action == 'stunnel_manage_menu':
        keyboard = [
            [InlineKeyboardButton("🔄 Reiniciar", callback_data='stunnel_restart')],
            [InlineKeyboardButton("🛑 Parar", callback_data='stunnel_stop')],
            [InlineKeyboardButton("📝 Alterar Porta", callback_data='stunnel_change_port_prompt')],
            [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_stunnel_menu')]
        ]
        await query.message.edit_text("⚙️ *Gerenciar Stunnel*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return STUNNEL_MANAGE_MENU
    
    elif action == 'stunnel_uninstall_prompt':
        keyboard = [
            [InlineKeyboardButton("✅ Confirmar Desinstalação", callback_data='confirm_uninstall_stunnel')],
            [InlineKeyboardButton("↩️ Cancelar", callback_data='back_to_stunnel_menu')]
        ]
        await query.message.edit_text("⚠️ *ATENÇÃO!* Deseja realmente desinstalar o Stunnel?", 
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_UNINSTALL_STUNNEL
    
    elif action == 'back_to_connection_menu':
        return await start_connection_menu(update, context)
    
    return STUNNEL_MENU

async def stunnel_install_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    mode = query.data.replace('stunnel_install_mode_', '')
    context.user_data['stunnel_install_mode'] = mode
    
    await query.message.edit_text("Digite a porta SSL (ex: 443, 8443):")
    return GET_STUNNEL_INSTALL_PORT

async def get_stunnel_install_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_STUNNEL_INSTALL_PORT
    
    await update.message.reply_text("⚙️ Processando instalação/configuração...")
    
    mode = context.user_data['stunnel_install_mode']
    
    if mode == 'install':
        # Comando de instalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/install_stunnel.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/install_stunnel.sh -q && chmod +x /tmp/install_stunnel.sh && /tmp/install_stunnel.sh")
    
    # Comando de configuração (mantido a partir do código original)
    await execute_shell_command(f"wget -O /tmp/stunnel_config.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/stunnel_config.sh -q && chmod +x /tmp/stunnel_config.sh && /tmp/stunnel_config.sh {port}")
    
    await execute_shell_command("service stunnel4 restart")
    
    await update.message.reply_text(f"✅ Stunnel instalado/configurado na porta *{port}* com sucesso!", parse_mode=ParseMode.MARKDOWN)
    
    # CORREÇÃO: Limpar user_data após a conclusão da conversa
    context.user_data.clear()
    
    return ConversationHandler.END

async def stunnel_manage_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'stunnel_restart':
        await query.message.edit_text("⚙️ Reiniciando Stunnel...")
        # Comando de reinício (mantido a partir do código original)
        await execute_shell_command("service stunnel4 restart")
        await query.message.edit_text("✅ Stunnel reiniciado com sucesso!")
        return await start_stunnel_menu(update, context)
    
    elif action == 'stunnel_stop':
        await query.message.edit_text("⚙️ Parando Stunnel...")
        # Comando de parada (mantido a partir do código original)
        await execute_shell_command("service stunnel4 stop")
        await query.message.edit_text("✅ Stunnel parado com sucesso!")
        return await start_stunnel_menu(update, context)
    
    elif action == 'stunnel_change_port_prompt':
        await query.message.edit_text("Digite a nova porta SSL (ex: 443, 8443):")
        return GET_STUNNEL_CHANGE_PORT
    
    elif action == 'back_to_stunnel_menu':
        return await start_stunnel_menu(update, context)
    
    return STUNNEL_MANAGE_MENU

async def get_stunnel_change_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_STUNNEL_CHANGE_PORT
    
    await update.message.reply_text("⚙️ Alterando porta e reiniciando Stunnel...")
    
    # Comando para alterar a porta no stunnel.conf (mantido a partir do código original)
    await execute_shell_command(f"sed -i 's/accept = .*/accept = {port}/g' /etc/stunnel/stunnel.conf")
    await execute_shell_command("service stunnel4 restart")
    
    await update.message.reply_text(f"✅ Porta Stunnel alterada para *{port}* com sucesso!", parse_mode=ParseMode.MARKDOWN)
    
    return ConversationHandler.END

async def confirm_uninstall_stunnel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'confirm_uninstall_stunnel':
        await query.message.edit_text("⚙️ Desinstalando Stunnel...")
        # Comando de desinstalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/uninstall_stunnel.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/uninstall_stunnel.sh -q && chmod +x /tmp/uninstall_stunnel.sh && /tmp/uninstall_stunnel.sh")
        await query.message.edit_text("✅ Stunnel desinstalado com sucesso!")
        return ConversationHandler.END
    
    elif action == 'back_to_stunnel_menu':
        return await start_stunnel_menu(update, context)
    
    return CONFIRM_UNINSTALL_STUNNEL

# --- Módulo: Proxy Dragon ---

async def get_dragon_status():
    # A lógica do DragonX no script externo usa systemd services.
    # Vamos verificar se o diretório de instalação existe e se há serviços ativos.
    if os.path.exists(DRAGON_INSTALL_DIR):
        # Verifica se há algum serviço DragonX ativo
        active_services = await execute_shell_command("systemctl list-units --type=service --state=active | grep 'dragonx_' | awk '{print $1}'")
        
        if active_services:
            status = "ATIVO"
        else:
            status = "INATIVO"
            
        # Obtém as portas configuradas
        ports_content = await execute_shell_command(f"cat {DRAGON_PORTS_FILE}")
        ports = ports_content.replace('\n', ', ') if ports_content else "Nenhuma"
        return status, ports
    return "NÃO INSTALADO", "Nenhuma"

async def start_dragon_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END # Adicionado check de admin
    query = update.callback_query
    await query.answer()
    
    status, ports = await get_dragon_status()
    status_text = f"Status: 🟢 *{status}* | Portas: *{ports}*" if status == "ATIVO" else "Status: 🔴 *INATIVO*"

    keyboard = [
        [InlineKeyboardButton("➕ Adicionar Porta", callback_data='dragon_add_port_prompt')],
        [InlineKeyboardButton("🔄 Reiniciar Porta", callback_data='dragon_restart_port_prompt')],
        [InlineKeyboardButton("🛑 Parar Porta", callback_data='dragon_stop_port_prompt')],
        [InlineKeyboardButton("📥 Instalar / Atualizar", callback_data='dragon_install')],
        [InlineKeyboardButton("🗑️ Desinstalar", callback_data='dragon_uninstall_prompt')],
        [InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')],
    ]
    await query.message.edit_text(
        text=f"🔌 *Gerenciador Proxy DragonX*\n\n{status_text}\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return DRAGON_MENU

async def dragon_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data

    if action == 'dragon_add_port_prompt':
        await query.message.edit_text("Digite a porta a ser adicionada (ex: 80, 443):")
        return GET_DRAGON_ADD_PORT
    
    elif action == 'dragon_restart_port_prompt':
        await query.message.edit_text("Digite a porta a ser reiniciada:")
        return GET_DRAGON_RESTART_PORT
    
    elif action == 'dragon_stop_port_prompt':
        await query.message.edit_text("Digite a porta a ser parada:")
        return GET_DRAGON_STOP_PORT
    
    elif action == 'dragon_install':
        await query.message.edit_text("⚙️ Instalando/Atualizando Proxy DragonX...")
        # Comando de instalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/install_dragon.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/install_dragon.sh -q && chmod +x /tmp/install_dragon.sh && /tmp/install_dragon.sh")
        await query.message.edit_text("✅ Proxy DragonX instalado/atualizado com sucesso!")
        return await start_dragon_menu(update, context)
    
    elif action == 'dragon_uninstall_prompt':
        keyboard = [
            [InlineKeyboardButton("✅ Confirmar Desinstalação", callback_data='confirm_uninstall_dragon')],
            [InlineKeyboardButton("↩️ Cancelar", callback_data='back_to_dragon_menu')]
        ]
        await query.message.edit_text("⚠️ *ATENÇÃO!* Deseja realmente desinstalar o Proxy DragonX?", 
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_UNINSTALL_DRAGON
    
    elif action == 'back_to_connection_menu':
        return await start_connection_menu(update, context)
    
    return DRAGON_MENU

async def get_dragon_add_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_DRAGON_ADD_PORT
    
    await update.message.reply_text(f"⚙️ Adicionando porta {port} ao Proxy DragonX...")
    
    # Comando para adicionar porta (mantido a partir do código original)
    await execute_shell_command(f"wget -O /tmp/add_port_dragon.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/add_port_dragon.sh -q && chmod +x /tmp/add_port_dragon.sh && /tmp/add_port_dragon.sh {port}")
    
    await update.message.reply_text(f"✅ Porta {port} adicionada com sucesso!")
    
    return await start_dragon_menu(update, context)

async def get_dragon_restart_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_DRAGON_RESTART_PORT
    
    await update.message.reply_text(f"⚙️ Reiniciando serviço da porta {port}...")
    
    # Comando para reiniciar porta (mantido a partir do código original)
    await execute_shell_command(f"systemctl restart dragonx_{port}")
    
    await update.message.reply_text(f"✅ Serviço da porta {port} reiniciado com sucesso!")
    
    return await start_dragon_menu(update, context)

async def get_dragon_stop_port_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    port = update.message.text.strip()
    if not port.isdigit() or not (1 <= int(port) <= 65535):
        await update.message.reply_text("Porta inválida. Insira um número entre 1 e 65535.")
        return GET_DRAGON_STOP_PORT
    
    await update.message.reply_text(f"⚙️ Parando serviço da porta {port}...")
    
    # Comando para parar porta (mantido a partir do código original)
    await execute_shell_command(f"systemctl stop dragonx_{port}")
    
    await update.message.reply_text(f"✅ Serviço da porta {port} parado com sucesso!")
    
    return await start_dragon_menu(update, context)

async def confirm_uninstall_dragon(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'confirm_uninstall_dragon':
        await query.message.edit_text("⚙️ Desinstalando Proxy DragonX...")
        # Comando de desinstalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/uninstall_dragon.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/uninstall_dragon.sh -q && chmod +x /tmp/uninstall_dragon.sh && /tmp/uninstall_dragon.sh")
        await query.message.edit_text("✅ Proxy DragonX desinstalado com sucesso!")
        return ConversationHandler.END
    
    elif action == 'back_to_dragon_menu':
        return await start_dragon_menu(update, context)
    
    return CONFIRM_UNINSTALL_DRAGON

# --- Módulo: SlowDNS ---

async def get_slowdns_status():
    if os.path.exists("/etc/slowdns/dns-server"):
        status = await execute_shell_command("ps x | grep -w 'dns-server' | grep -v grep")
        if status:
            return "ATIVO"
        return "INATIVO"
    return "NÃO INSTALADO"

async def start_slowdns_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not await is_admin(update): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    
    status = await get_slowdns_status()
    status_text = f"Status: 🟢 *{status}*" if status == "ATIVO" else f"Status: 🔴 *{status}*"

    keyboard = [
        [InlineKeyboardButton("📥 Instalar / Configurar", callback_data='slowdns_install_prompt')],
    ]
    
    if status != "NÃO INSTALADO":
        keyboard.append([InlineKeyboardButton("🗑️ Desinstalar", callback_data='slowdns_uninstall_prompt')])
        
    keyboard.append([InlineKeyboardButton("↩️ Voltar", callback_data='back_to_connection_menu')])
    
    await query.message.edit_text(
        text=f"🔌 *Gerenciador SlowDNS*\n\n{status_text}\n\nSelecione uma opção:",
        reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN
    )
    return SLOWDNS_MENU

async def slowdns_menu_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'slowdns_install_prompt':
        keyboard = [
            [InlineKeyboardButton("Instalar/Reinstalar", callback_data='slowdns_install_mode_install')],
            [InlineKeyboardButton("Apenas Configurar", callback_data='slowdns_install_mode_config')]
        ]
        await query.message.edit_text("Selecione o modo de instalação:", reply_markup=InlineKeyboardMarkup(keyboard))
        return SLOWDNS_INSTALL_MODE
    
    elif action == 'slowdns_uninstall_prompt':
        keyboard = [
            [InlineKeyboardButton("✅ Confirmar Desinstalação", callback_data='confirm_uninstall_slowdns')],
            [InlineKeyboardButton("↩️ Cancelar", callback_data='back_to_slowdns_menu')]
        ]
        await query.message.edit_text("⚠️ *ATENÇÃO!* Deseja realmente desinstalar o SlowDNS?", 
                                      reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return CONFIRM_UNINSTALL_SLOWDNS
    
    elif action == 'back_to_connection_menu':
        return await start_connection_menu(update, context)
    
    return SLOWDNS_MENU

async def slowdns_install_mode(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    mode = query.data.replace('slowdns_install_mode_', '')
    context.user_data['slowdns_install_mode'] = mode
    
    await query.message.edit_text("Digite o NS (Nameserver) que você irá usar (ex: ns.seudominio.com):")
    return GET_SLOWDNS_NS

async def get_slowdns_ns(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    ns = update.message.text.strip()
    if not ns:
        await update.message.reply_text("NS inválido. Tente novamente.")
        return GET_SLOWDNS_NS
    
    context.user_data['slowdns_ns'] = ns
    
    keyboard = [
        [InlineKeyboardButton("Gerar Chave Aleatória", callback_data='slowdns_key_generate')],
        [InlineKeyboardButton("Usar Chave Existente", callback_data='slowdns_key_existing')]
    ]
    await update.message.reply_text("Selecione como obter a chave:", reply_markup=InlineKeyboardMarkup(keyboard))
    return GET_SLOWDNS_KEY_CHOICE

async def get_slowdns_key_choice_and_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    choice = query.data.replace('slowdns_key_', '')
    
    await query.message.edit_text("⚙️ Processando instalação/configuração...")
    
    mode = context.user_data['slowdns_install_mode']
    ns = context.user_data['slowdns_ns']
    
    if mode == 'install':
        # Comando de instalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/install_slowdns.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/install_slowdns.sh -q && chmod +x /tmp/install_slowdns.sh && /tmp/install_slowdns.sh")
    
    # Comando de configuração (mantido a partir do código original)
    if choice == 'generate':
        # Gera a chave e configura
        await execute_shell_command(f"wget -O /tmp/config_slowdns.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/config_slowdns.sh -q && chmod +x /tmp/config_slowdns.sh && /tmp/config_slowdns.sh {ns} generate")
    else:
        # Usa a chave existente (assumindo que o script de configuração lida com isso)
        await execute_shell_command(f"wget -O /tmp/config_slowdns.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/config_slowdns.sh -q && chmod +x /tmp/config_slowdns.sh && /tmp/config_slowdns.sh {ns} existing")
        
    await query.message.edit_text(f"✅ SlowDNS configurado com sucesso no NS: *{ns}*!", parse_mode=ParseMode.MARKDOWN)
    
    context.user_data.clear()
    return ConversationHandler.END

async def confirm_uninstall_slowdns(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data
    
    if action == 'confirm_uninstall_slowdns':
        await query.message.edit_text("⚙️ Desinstalando SlowDNS...")
        # Comando de desinstalação (mantido a partir do código original)
        await execute_shell_command("wget -O /tmp/uninstall_slowdns.sh https://bitbucket.org/alfalemos/sshplus/raw/f57bd164e7c89c10c87f58b8431ad2d2ef2ad039/Modulos/uninstall_slowdns.sh -q && chmod +x /tmp/uninstall_slowdns.sh && /tmp/uninstall_slowdns.sh")
        await query.message.edit_text("✅ SlowDNS desinstalado com sucesso!")
        return ConversationHandler.END
    
    elif action == 'back_to_slowdns_menu':
        return await start_slowdns_menu(update, context)
    
    return CONFIRM_UNINSTALL_SLOWDNS

# --- Funções de Fallback (CORREÇÃO PRINCIPAL) ---

async def fallback_to_main_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """
    Função de fallback para mensagens de texto que não são comandos e não estão em uma conversa.
    Envia uma mensagem de erro e retorna ao menu principal.
    """
    if not await is_admin(update): return ConversationHandler.END
    
    # Verifica se a mensagem é um texto
    if update.message and update.message.text:
        await update.message.reply_text("❌ Comando ou resposta inválida. Use o /menu para voltar ao menu principal ou selecione uma opção válida.")
        
    return ConversationHandler.END

async def fallback_conversation_end(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """
    Fallback para conversas que não reconhecem o input.
    """
    # Verifica se é um callback (botão)
    if update.callback_query:
        await update.callback_query.answer("❌ Opção inválida. Voltando ao menu principal.", show_alert=True)
        
    # Verifica se é uma mensagem de texto
    elif update.message:
        await update.message.reply_text("❌ Resposta inválida. Voltando ao menu principal.")
        
    # Chama a função para finalizar a conversa e mostrar o menu principal
    await end_conversation(update, context)
    return ConversationHandler.END

# --- Função Principal ---

def main() -> None:
    """Inicia o bot."""
    # CORREÇÃO: Usar o token do Telegram
    application = Application.builder().token(TELEGRAM_TOKEN).build()

    # Handlers de fallback para conversas
    fallback_handlers = [
        CallbackQueryHandler(end_conversation, pattern='^back_to_main$'),
        MessageHandler(filters.COMMAND, end_conversation), # Qualquer comando dentro da conversa finaliza
        MessageHandler(filters.ALL, fallback_conversation_end) # Qualquer outra coisa dentro da conversa
    ]
    
    # Handlers de sub-conversas (para o menu de conexão)
    badvpn_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_badvpn_menu, pattern='^conn_badvpn$')],
        states={
            BADVPN_MENU: [CallbackQueryHandler(badvpn_menu_handler)],
            GET_BADVPN_NEW_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_badvpn_new_port_and_run)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')] # Fallback para voltar ao menu de conexão
    )
    
    websocket_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_websocket_menu, pattern='^conn_websocket$')],
        states={
            WEBSOCKET_MENU: [CallbackQueryHandler(websocket_menu_handler)],
            GET_WS_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ws_port)],
            GET_WS_MODE: [CallbackQueryHandler(get_ws_mode, pattern='^ws_mode_')],
            GET_WS_MSG: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ws_msg_and_run)],
            CONFIRM_UNINSTALL_WS: [CallbackQueryHandler(confirm_uninstall_ws)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')]
    )
    
    rusty_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_rusty_menu, pattern='^conn_rusty$')],
        states={
            RUSTY_MENU: [CallbackQueryHandler(rusty_menu_handler)],
            GET_RUSTY_ADD_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_rusty_add_port)],
            GET_RUSTY_ADD_STATUS: [CallbackQueryHandler(get_rusty_add_status_and_run, pattern='^rusty_status_')],
            GET_RUSTY_DEL_PORT: [CallbackQueryHandler(get_rusty_del_port, pattern='^rusty_del_')],
            CONFIRM_UNINSTALL_RUSTY: [CallbackQueryHandler(confirm_uninstall_rusty)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')]
    )
    
    stunnel_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_stunnel_menu, pattern='^conn_stunnel$')],
        states={
            STUNNEL_MENU: [CallbackQueryHandler(stunnel_menu_handler)],
            STUNNEL_INSTALL_MODE: [CallbackQueryHandler(stunnel_install_mode, pattern='^stunnel_install_mode_')],
            GET_STUNNEL_INSTALL_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_stunnel_install_port_and_run)],
            STUNNEL_MANAGE_MENU: [CallbackQueryHandler(stunnel_manage_menu_handler)],
            GET_STUNNEL_CHANGE_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_stunnel_change_port_and_run)],
            CONFIRM_UNINSTALL_STUNNEL: [CallbackQueryHandler(confirm_uninstall_stunnel)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')]
    )
    
    dragon_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_dragon_menu, pattern='^conn_dragon$')],
        states={
            DRAGON_MENU: [CallbackQueryHandler(dragon_menu_handler)],
            GET_DRAGON_ADD_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_dragon_add_port_and_run)],
            GET_DRAGON_RESTART_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_dragon_restart_port_and_run)],
            GET_DRAGON_STOP_PORT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_dragon_stop_port_and_run)],
            CONFIRM_UNINSTALL_DRAGON: [CallbackQueryHandler(confirm_uninstall_dragon)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')]
    )
    
    slowdns_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(start_slowdns_menu, pattern='^conn_slowdns$')],
        states={
            SLOWDNS_MENU: [CallbackQueryHandler(slowdns_menu_handler)],
            SLOWDNS_INSTALL_MODE: [CallbackQueryHandler(slowdns_install_mode, pattern='^slowdns_install_mode_')],
            GET_SLOWDNS_NS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_slowdns_ns)],
            GET_SLOWDNS_KEY_CHOICE: [CallbackQueryHandler(get_slowdns_key_choice_and_run, pattern='^slowdns_key_')],
            CONFIRM_UNINSTALL_SLOWDNS: [CallbackQueryHandler(confirm_uninstall_slowdns)],
        },
        fallbacks=[CallbackQueryHandler(start_connection_menu, pattern='^back_to_connection_menu$')]
    )

    conv_handlers = [
        ConversationHandler(
            entry_points=[CommandHandler("menu", start_command), CommandHandler("start", start_command)],
            states={},
            fallbacks=[]
        ),
        ConversationHandler(
            entry_points=[CallbackQueryHandler(start_create_user_convo, pattern='^start_create_user$')],
            states={
                GET_USER_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_username)],
                GET_USER_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_password)],
                GET_USER_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_days)],
                GET_USER_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_user_limit_and_create)],
            },
            fallbacks=fallback_handlers
        ),
        ConversationHandler(
            entry_points=[CallbackQueryHandler(start_create_test_user_convo, pattern='^start_create_test_user$')],
            states={
                GET_TEST_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_user_username)],
                GET_TEST_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_user_password)],
                GET_TEST_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_user_limit)],
                GET_TEST_DURATION: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_test_duration_and_create)],
            },
            fallbacks=fallback_handlers
        ),
        ConversationHandler(
            entry_points=[CallbackQueryHandler(start_delete_user_convo, pattern='^start_delete_user$')],
            states={
                GET_USER_TO_DELETE: [
                    CallbackQueryHandler(delete_all_users_prompt, pattern='^delete_all_users_prompt$'),
                    CallbackQueryHandler(get_user_to_delete, pattern='^delete_user_') # Pega apenas callbacks de deleção de usuário
                ],
                CONFIRM_DELETE_USER: [
                    CallbackQueryHandler(confirm_delete_single_user, pattern='^confirm_delete$'),
                    CallbackQueryHandler(start_delete_user_convo, pattern='^back_to_delete_menu$')
                ],
                CONFIRM_DELETE_ALL: [
                    CallbackQueryHandler(execute_delete_all_users, pattern='^confirm_delete_all$'),
                    CallbackQueryHandler(start_delete_user_convo, pattern='^restart_delete_menu$')
                ],
            },
            fallbacks=fallback_handlers
        ),
        ConversationHandler(
            entry_points=[CallbackQueryHandler(start_backup_menu, pattern='^start_backup$')],
            states={
                BACKUP_MENU: [CallbackQueryHandler(backup_menu_handler)],
                CONFIRM_RESTORE: [CallbackQueryHandler(confirm_restore_handler)],
            },
            fallbacks=fallback_handlers
        ),
        ConversationHandler(
            entry_points=[CallbackQueryHandler(start_connection_menu, pattern='^start_connection_menu$')],
            states={ 
                CONNECTION_MENU: [
                    badvpn_conv, 
                    websocket_conv,
                    rusty_conv,
                    stunnel_conv,
                    dragon_conv,
                    slowdns_conv,
                    CallbackQueryHandler(start_badvpn_menu, pattern='^conn_badvpn$'), # Adicionado para re-entrar
                    CallbackQueryHandler(start_websocket_menu, pattern='^conn_websocket$'), # Adicionado para re-entrar
                    CallbackQueryHandler(start_rusty_menu, pattern='^conn_rusty$'), # Adicionado para re-entrar
                    CallbackQueryHandler(start_stunnel_menu, pattern='^conn_stunnel$'), # Adicionado para re-entrar
                    CallbackQueryHandler(start_dragon_menu, pattern='^conn_dragon$'), # Adicionado para re-entrar
                    CallbackQueryHandler(start_slowdns_menu, pattern='^conn_slowdns$'), # Adicionado para re-entrar
                ]
            },
            fallbacks=fallback_handlers
        ),
    ]

    # CORREÇÃO: Adicionar os handlers de comando e os ConversationHandlers
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("menu", start_command))
    
    # Adicionar o handler do shellbot
    application.add_handler(CommandHandler("shell", shell_command))
    
    # Adicionar todos os ConversationHandlers
    for handler in conv_handlers:
        application.add_handler(handler)

    # Handlers de clique único (fora de conversas)
    application.add_handler(CallbackQueryHandler(user_info_report, pattern='^user_info_report$'))
    application.add_handler(CallbackQueryHandler(online_users_monitor, pattern='^online_users_monitor$'))
    application.add_handler(CallbackQueryHandler(back_to_main_from_report, pattern='^back_to_main_special$'))
    
    # Handler de fallback global para garantir que o menu principal possa ser alcançado
    application.add_handler(CallbackQueryHandler(end_conversation, pattern='^back_to_main$'))
    
    # CORREÇÃO: Adicionar um fallback para mensagens de texto que não são comandos e não estão em conversa
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, fallback_to_main_menu))


    print("Bot iniciado! Pressione Ctrl+C para parar.")
    application.run_polling()

if __name__ == '__main__':
    main()
