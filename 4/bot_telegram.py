from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ConversationHandler,
    MessageHandler,
    ContextTypes,
    filters,
)
import os
import time

# Configurações
CHAT_ID_ADMIN = "2022492515"  # Substitua pelo seu chat_id
TOKEN = "5443820220:AAExIzr8IgFXtzzOWvg4RZp1ip9WwW9ATMY"  # Substitua pelo token obtido do BotFather

# Estados do ConversationHandler para criar usuário
NOME, SENHA, VALIDADE, LIMITE = range(4)

def executarComando(comando):
    with open("bot_command.txt", "w") as f:
        f.write(comando)
    while not os.path.exists("bot_response.txt"):
        time.sleep(0.1)  # Aguarda resposta
    with open("bot_response.txt", "r") as f:
        resposta = f.read()
    os.remove("bot_response.txt")
    return resposta

# Função para criar o menu principal com botões
def criar_menu_principal():
    keyboard = [
        [InlineKeyboardButton("1. Gerenciar Usuários SSH", callback_data="menu_gerenciar_usuarios")],
        [InlineKeyboardButton("2. Gerenciar Conexões", callback_data="menu_gerenciar_conexoes")],
        [InlineKeyboardButton("3. Informações do Sistema", callback_data="menu_informacoes_sistema")]
    ]
    return InlineKeyboardMarkup(keyboard)

# Submenu para Gerenciar Usuários SSH
def criar_submenu_usuarios():
    keyboard = [
        [InlineKeyboardButton("1.1 Criar novo usuário", callback_data="criar_usuario")],
        [InlineKeyboardButton("1.2 Remover usuário", callback_data="remover_usuario")],
        [InlineKeyboardButton("1.3 Teste de conexão SSH", callback_data="teste_conexao_ssh")],
        [InlineKeyboardButton("1.4 Alterar limite de conexões", callback_data="alterar_limite")],
        [InlineKeyboardButton("1.5 Alterar validade", callback_data="alterar_validade")],
        [InlineKeyboardButton("1.6 Alterar senha", callback_data="alterar_senha")],
        [InlineKeyboardButton("1.7 Listar todos os usuários", callback_data="listar_usuarios")],
        [InlineKeyboardButton("1.8 Listar usuários expirados", callback_data="listar_expirados")],
        [InlineKeyboardButton("1.9 Listar usuários online", callback_data="listar_online")],
        [InlineKeyboardButton("1.10 Dados de um usuário", callback_data="dados_usuario")],
        [InlineKeyboardButton("Voltar", callback_data="voltar_menu")]
    ]
    return InlineKeyboardMarkup(keyboard)

# Submenu para Gerenciar Conexões
def criar_submenu_conexoes():
    keyboard = [
        [InlineKeyboardButton("2.1 Ver status do proxy", callback_data="ver_status_proxy")],
        [InlineKeyboardButton("2.2 Reiniciar proxy", callback_data="reiniciar_proxy")],
        [InlineKeyboardButton("2.3 Listar conexões ativas", callback_data="listar_conexoes")],
        [InlineKeyboardButton("2.4 Escolher porta dos serviços", callback_data="escolher_porta")],
        [InlineKeyboardButton("2.5 Fechar porta", callback_data="fechar_porta")],
        [InlineKeyboardButton("2.6 Modos de conexão", callback_data="modos_conexao")],
        [InlineKeyboardButton("Voltar", callback_data="voltar_menu")]
    ]
    return InlineKeyboardMarkup(keyboard)

# Submenu para Informações do Sistema
def criar_submenu_informacoes():
    keyboard = [
        [InlineKeyboardButton("3.1 Histórico UDP (Badvpn)", callback_data="historico_udp")],
        [InlineKeyboardButton("3.2 Uso de recursos (CPU, RAM)", callback_data="uso_recursos")],
        [InlineKeyboardButton("3.3 Logs gerais", callback_data="logs_gerais")],
        [InlineKeyboardButton("Voltar", callback_data="voltar_menu")]
    ]
    return InlineKeyboardMarkup(keyboard)

# Comando /menu
async def menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    reply_markup = criar_menu_principal()
    await update.message.reply_text("=== Sistema de Gerenciamento de Rede ANYVPN ===\nEscolha uma opção:", reply_markup=reply_markup)

# Fluxo de criação de usuário
async def criar_usuario_inicio(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if query.message.chat_id != int(CHAT_ID_ADMIN):
        await query.message.reply_text("Acesso negado!")
        return ConversationHandler.END
    await query.message.reply_text("Digite o nome do usuário:")
    return NOME

async def criar_usuario_nome(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["nome"] = update.message.text
    await update.message.reply_text("Digite a senha do usuário:")
    return SENHA

async def criar_usuario_senha(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["senha"] = update.message.text
    await update.message.reply_text("Digite a validade (em dias):")
    return VALIDADE

async def criar_usuario_validade(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        context.user_data["validade"] = int(update.message.text)
        await update.message.reply_text("Digite o limite de conexões:")
        return LIMITE
    except ValueError:
        await update.message.reply_text("Por favor, digite um número válido para a validade (em dias):")
        return VALIDADE

async def criar_usuario_limite(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        context.user_data["limite"] = int(update.message.text)
        nome = context.user_data["nome"]
        senha = context.user_data["senha"]
        validade = context.user_data["validade"]
        limite = context.user_data["limite"]
        comando = f"/criarusuario {nome} {senha} {validade} {limite}"
        resposta = executarComando(comando)
        await update.message.reply_text(resposta)
        return ConversationHandler.END
    except ValueError:
        await update.message.reply_text("Por favor, digite um número válido para o limite de conexões:")
        return LIMITE

async def cancelar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Criação de usuário cancelada.")
    return ConversationHandler.END

# Manipulador de cliques nos botões
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    if query.data == "menu_gerenciar_usuarios":
        reply_markup = criar_submenu_usuarios()
        await query.edit_message_text("=== Gerenciar Usuários SSH ===\nEscolha uma opção:", reply_markup=reply_markup)
    elif query.data == "menu_gerenciar_conexoes":
        reply_markup = criar_submenu_conexoes()
        await query.edit_message_text("=== Gerenciar Conexões ===\nEscolha uma opção:", reply_markup=reply_markup)
    elif query.data == "menu_informacoes_sistema":
        reply_markup = criar_submenu_informacoes()
        await query.edit_message_text("=== Informações do Sistema ===\nEscolha uma opção:", reply_markup=reply_markup)
    elif query.data == "voltar_menu":
        reply_markup = criar_menu_principal()
        await query.edit_message_text("=== Sistema de Gerenciamento de Rede ANYVPN ===\nEscolha uma opção:", reply_markup=reply_markup)
    elif query.data == "criar_usuario":
        return await criar_usuario_inicio(update, context)
    elif query.data == "remover_usuario":
        await query.message.reply_text("Digite: /removerusuario <nome>")
    elif query.data == "teste_conexao_ssh":
        await query.message.reply_text("Digite: /testessh <minutos>")
    elif query.data == "alterar_limite":
        await query.message.reply_text("Digite: /alterarlimite <nome> <limite>")
    elif query.data == "alterar_validade":
        await query.message.reply_text("Digite: /alterarvalidade <nome> <dias>")
    elif query.data == "alterar_senha":
        await query.message.reply_text("Digite: /alterarsenha <nome> <nova_senha>")
    elif query.data == "listar_usuarios":
        resposta = executarComando("/listarusuarios")
        await query.message.reply_text(resposta)
    elif query.data == "listar_expirados":
        resposta = executarComando("/listarexpirados")
        await query.message.reply_text(resposta)
    elif query.data == "listar_online":
        resposta = executarComando("/listaronline")
        await query.message.reply_text(resposta)
    elif query.data == "dados_usuario":
        await query.message.reply_text("Digite: /dadosusuario <nome>")
    elif query.data == "ver_status_proxy":
        resposta = executarComando("/statusproxy")
        await query.message.reply_text(resposta)
    elif query.data == "reiniciar_proxy":
        resposta = executarComando("/reiniciarproxy")
        await query.message.reply_text(resposta)
    elif query.data == "listar_conexoes":
        resposta = executarComando("/listarconexoes")
        await query.message.reply_text(resposta)
    elif query.data == "escolher_porta":
        keyboard = [
            [InlineKeyboardButton("80", callback_data="escolher_porta_80")],
            [InlineKeyboardButton("443", callback_data="escolher_porta_443")],
            [InlineKeyboardButton("8080", callback_data="escolher_porta_8080")],
            [InlineKeyboardButton("Voltar", callback_data="voltar_menu")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await query.message.reply_text("Escolha a porta:", reply_markup=reply_markup)
    elif query.data == "fechar_porta":
        keyboard = [
            [InlineKeyboardButton("80", callback_data="fechar_porta_80")],
            [InlineKeyboardButton("443", callback_data="fechar_porta_443")],
            [InlineKeyboardButton("8080", callback_data="fechar_porta_8080")],
            [InlineKeyboardButton("Voltar", callback_data="voltar_menu")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await query.message.reply_text("Escolha a porta para fechar:", reply_markup=reply_markup)
    elif query.data.startswith("escolher_porta_"):
        porta = int(query.data.split("_")[2])
        comando = f"/escolherporta {porta}"
        resposta = executarComando(comando)
        await query.message.reply_text(resposta)
    elif query.data.startswith("fechar_porta_"):
        porta = int(query.data.split("_")[2])
        comando = f"/fecharporta {porta}"
        resposta = executarComando(comando)
        await query.message.reply_text(resposta)
    elif query.data == "modos_conexao":
        resposta = executarComando("/modosconexao")
        await query.message.reply_text(resposta)
    elif query.data == "historico_udp":
        resposta = executarComando("/historicoudp")
        await query.message.reply_text(resposta)
    elif query.data == "uso_recursos":
        resposta = executarComando("/usorecursos")
        await query.message.reply_text(resposta)
    elif query.data == "logs_gerais":
        resposta = executarComando("/logsgerais")
        await query.message.reply_text(resposta)

# Comandos de Gerenciar Usuários SSH
async def remover_usuario(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 1:
        await update.message.reply_text("Uso: /removerusuario <nome>")
        return
    comando = f"/removerusuario {context.args[0]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def teste_conexao_ssh(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 1:
        await update.message.reply_text("Uso: /testessh <minutos>")
        return
    comando = f"/testessh {context.args[0]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def alterar_limite(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 2:
        await update.message.reply_text("Uso: /alterarlimite <nome> <limite>")
        return
    comando = f"/alterarlimite {context.args[0]} {context.args[1]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def alterar_validade(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 2:
        await update.message.reply_text("Uso: /alterarvalidade <nome> <dias>")
        return
    comando = f"/alterarvalidade {context.args[0]} {context.args[1]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def alterar_senha(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 2:
        await update.message.reply_text("Uso: /alterarsenha <nome> <nova_senha>")
        return
    comando = f"/alterarsenha {context.args[0]} {context.args[1]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def listar_usuarios(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/listarusuarios")
    await update.message.reply_text(resposta)

async def listar_expirados(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/listarexpirados")
    await update.message.reply_text(resposta)

async def listar_online(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/listaronline")
    await update.message.reply_text(resposta)

async def dados_usuario(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 1:
        await update.message.reply_text("Uso: /dadosusuario <nome>")
        return
    comando = f"/dadosusuario {context.args[0]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

# Comandos de Gerenciar Conexões
async def ver_status_proxy(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/statusproxy")
    await update.message.reply_text(resposta)

async def reiniciar_proxy(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/reiniciarproxy")
    await update.message.reply_text(resposta)

async def listar_conexoes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/listarconexoes")
    await update.message.reply_text(resposta)

async def escolher_porta(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 1:
        await update.message.reply_text("Uso: /escolherporta <porta>")
        return
    comando = f"/escolherporta {context.args[0]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def fechar_porta(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    if len(context.args) != 1:
        await update.message.reply_text("Uso: /fecharporta <porta>")
        return
    comando = f"/fecharporta {context.args[0]}"
    resposta = executarComando(comando)
    await update.message.reply_text(resposta)

async def modos_conexao(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/modosconexao")
    await update.message.reply_text(resposta)

# Comandos de Informações do Sistema
async def historico_udp(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/historicoudp")
    await update.message.reply_text(resposta)

async def uso_recursos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/usorecursos")
    await update.message.reply_text(resposta)

async def logs_gerais(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat_id != int(CHAT_ID_ADMIN):
        await update.message.reply_text("Acesso negado!")
        return
    resposta = executarComando("/logsgerais")
    await update.message.reply_text(resposta)

def main():
    with open("bot_status.txt", "r") as f:
        status = f.read().split()
        if len(status) < 3 or status[0] != "ativo":
            print("Bot desativado. Ative via menu (opção 4.1).")
            return
        token, chat_id = status[1], status[2]

    app = Application.builder().token(token).build()

    # Comandos
    app.add_handler(CommandHandler("menu", menu))
    app.add_handler(CallbackQueryHandler(button_handler))

    # ConversationHandler para criar usuário
    conv_handler = ConversationHandler(
        entry_points=[CallbackQueryHandler(criar_usuario_inicio, pattern="^criar_usuario$")],
        states={
            NOME: [MessageHandler(filters.TEXT & ~filters.COMMAND, criar_usuario_nome)],
            SENHA: [MessageHandler(filters.TEXT & ~filters.COMMAND, criar_usuario_senha)],
            VALIDADE: [MessageHandler(filters.TEXT & ~filters.COMMAND, criar_usuario_validade)],
            LIMITE: [MessageHandler(filters.TEXT & ~filters.COMMAND, criar_usuario_limite)],
        },
        fallbacks=[CommandHandler("cancelar", cancelar)],
    )
    app.add_handler(conv_handler)

    # Gerenciar Usuários SSH
    app.add_handler(CommandHandler("removerusuario", remover_usuario))
    app.add_handler(CommandHandler("testessh", teste_conexao_ssh))
    app.add_handler(CommandHandler("alterarlimite", alterar_limite))
    app.add_handler(CommandHandler("alterarvalidade", alterar_validade))
    app.add_handler(CommandHandler("alterarsenha", alterar_senha))
    app.add_handler(CommandHandler("listarusuarios", listar_usuarios))
    app.add_handler(CommandHandler("listarexpirados", listar_expirados))
    app.add_handler(CommandHandler("listaronline", listar_online))
    app.add_handler(CommandHandler("dadosusuario", dados_usuario))

    # Gerenciar Conexões
    app.add_handler(CommandHandler("statusproxy", ver_status_proxy))
    app.add_handler(CommandHandler("reiniciarproxy", reiniciar_proxy))
    app.add_handler(CommandHandler("listarconexoes", listar_conexoes))
    app.add_handler(CommandHandler("escolherporta", escolher_porta))
    app.add_handler(CommandHandler("fecharporta", fechar_porta))
    app.add_handler(CommandHandler("modosconexao", modos_conexao))

    # Informações do Sistema
    app.add_handler(CommandHandler("historicoudp", historico_udp))
    app.add_handler(CommandHandler("usorecursos", uso_recursos))
    app.add_handler(CommandHandler("logsgerais", logs_gerais))

    app.run_polling()

if __name__ == "__main__":
    main()