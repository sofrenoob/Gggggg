from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify, send_file
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import random
import datetime
import time
from apscheduler.schedulers.background import BackgroundScheduler
import mercadopago
import qrcode
from io import BytesIO
from PIL import Image

app = Flask(__name__)
app.config['SECRET_KEY'] = 'sua_chave_secreta_aqui'  # Mude para algo seguro
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///app.db'
db = SQLAlchemy(app)

# Mercado Pago SDK
sdk = mercadopago.SDK("YOUR_ACCESS_TOKEN")  # Substitua pelo seu access token

# Modelos do Banco de Dados
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    cpf = db.Column(db.String(11), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    balance = db.Column(db.Float, default=0.0)
    is_admin = db.Column(db.Boolean, default=False)

class Config(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    bet_price = db.Column(db.Float, default=1.0)  # Preço por número

class Round(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    start_time = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    status = db.Column(db.String(20), default='open')  # open, drawing, closed
    winners = db.Column(db.String(200))  # JSON com ganhadores

class Bet(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    round_id = db.Column(db.Integer, db.ForeignKey('round.id'))
    number = db.Column(db.Integer, nullable=False)

db.create_all()

# Config inicial
if not Config.query.first():
    db.session.add(Config())
    db.session.commit()

# Scheduler para sorteios
def start_new_round():
    current_round = Round.query.order_by(Round.id.desc()).first()
    if current_round and current_round.status == 'open':
        current_round.status = 'drawing'
        db.session.commit()
        perform_draw(current_round.id)
    new_round = Round()
    db.session.add(new_round)
    db.session.commit()

def perform_draw(round_id):
    round = Round.query.get(round_id)
    bets = Bet.query.filter_by(round_id=round_id).all()
    if not bets:
        round.status = 'closed'
        db.session.commit()
        return
    available_numbers = [bet.number for bet in bets]
    drawn = random.sample(available_numbers, min(3, len(available_numbers)))
    winners = []
    total_pot = len(bets) * Config.query.first().bet_price * 0.7  # 70% para prêmios
    prizes = [total_pot * 0.5, total_pot * 0.3, total_pot * 0.2]
    for i, num in enumerate(drawn[:3]):
        bet = next(b for b in bets if b.number == num)
        user = User.query.get(bet.user_id)
        user.balance += prizes[i]
        winners.append({'place': i+1, 'cpf_last6': user.cpf[-6:], 'prize': prizes[i]})
    round.winners = str(winners)  # Armazena como string por simplicidade
    round.status = 'closed'
    db.session.commit()

scheduler = BackgroundScheduler()
scheduler.add_job(func=start_new_round, trigger="interval", minutes=10)
scheduler.start()

# Rotas
@app.route('/')
def index():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    user = User.query.get(session['user_id'])
    current_round = Round.query.filter_by(status='open').order_by(Round.id.desc()).first()
    if not current_round:
        start_new_round()
        current_round = Round.query.order_by(Round.id.desc()).first()
    bets = Bet.query.filter_by(round_id=current_round.id).all()
    bought_numbers = [b.number for b in bets]
    user_bets = [b.number for b in bets if b.user_id == user.id]
    countdown = 600 - (time.time() - current_round.start_time.timestamp()) % 600  # 10 min
    participants = [{'cpf_last6': User.query.get(b.user_id).cpf[-6:], 'numbers': b.number} for b in bets]
    last_round = Round.query.filter_by(status='closed').order_by(Round.id.desc()).first()
    winners = eval(last_round.winners) if last_round else []
    return render_template('index.html', user=user, current_round=current_round, bought_numbers=bought_numbers,
                           user_bets=user_bets, countdown=countdown, participants=participants, winners=winners)

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        cpf = request.form['cpf']
        password = request.form['password']
        if User.query.filter_by(cpf=cpf).first():
            flash('CPF já cadastrado!')
            return redirect(url_for('register'))
        hash = generate_password_hash(password)
        user = User(cpf=cpf, password_hash=hash)
        if cpf == 'admin':  # Admin inicial
            user.is_admin = True
        db.session.add(user)
        db.session.commit()
        flash('Cadastro realizado!')
        return redirect(url_for('login'))
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        cpf = request.form['cpf']
        password = request.form['password']
        user = User.query.filter_by(cpf=cpf).first()
        if user and check_password_hash(user.password_hash, password):
            session['user_id'] = user.id
            return redirect(url_for('index'))
        flash('Login inválido!')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect(url_for('login'))

@app.route('/add_to_cart', methods=['POST'])
def add_to_cart():
    if 'user_id' not in session:
        return jsonify({'error': 'Não logado'})
    number = int(request.form['number'])
    current_round = Round.query.filter_by(status='open').first()
    if Bet.query.filter_by(round_id=current_round.id, number=number).first():
        return jsonify({'error': 'Número indisponível'})
    user_bets = Bet.query.filter_by(user_id=session['user_id'], round_id=current_round.id).count()
    if user_bets >= 5:
        return jsonify({'error': 'Limite de 5 números atingido'})
    bet = Bet(user_id=session['user_id'], round_id=current_round.id, number=number)
    db.session.add(bet)
    db.session.commit()
    return jsonify({'success': True})

@app.route('/checkout', methods=['POST'])
def checkout():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    user = User.query.get(session['user_id'])
    current_round = Round.query.filter_by(status='open').first()
    user_bets = Bet.query.filter_by(user_id=user.id, round_id=current_round.id).all()
    price = Config.query.first().bet_price
    total = len(user_bets) * price
    if user.balance < total:
        flash('Saldo insuficiente!')
        return redirect(url_for('index'))
    user.balance -= total
    db.session.commit()
    flash('Compra realizada!')
    return redirect(url_for('index'))

@app.route('/recharge', methods=['GET', 'POST'])
def recharge():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    if request.method == 'POST':
        amount = float(request.form['amount'])
        # Cria ordem para QR
        order_data = {
            "external_reference": f"recharge_{session['user_id']}_{int(time.time())}",
            "title": "Recarga de Saldo",
            "description": "Recarga para apostas",
            "notification_url": "https://seu-site.com/webhook",  # Substitua pelo seu URL de webhook
            "total_amount": amount,
            "items": [{"title": "Recarga", "quantity": 1, "unit_price": amount, "currency_id": "BRL"}]
        }
        response = sdk.instore_order().create(order_data)  # Use o endpoint correto para QR
        qr_data = response['response']['qr_data']
        # Gera imagem QR
        qr = qrcode.QRCode()
        qr.add_data(qr_data)
        qr.make(fit=True)
        img = qr.make_image(fill='black', back_color='white')
        img_io = BytesIO()
        img.save(img_io, 'PNG')
        img_io.seek(0)
        return send_file(img_io, mimetype='image/png')
    return render_template('recharge.html')

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    if data['type'] == 'payment':
        payment_id = data['data']['id']
        payment = sdk.payment().get(payment_id)
        if payment['status'] == 200 and payment['response']['status'] == 'approved':
            external_ref = payment['response']['external_reference']
            if external_ref.startswith('recharge_'):
                user_id = int(external_ref.split('_')[1])
                amount = payment['response']['transaction_amount']
                user = User.query.get(user_id)
                user.balance += amount
                db.session.commit()
    return '', 200

@app.route('/withdraw')
def withdraw():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    user = User.query.get(session['user_id'])
    if user.balance <= 0:
        flash('Saldo zero!')
        return redirect(url_for('index'))
    # Redireciona para WhatsApp (substitua pelo seu número)
    return redirect('https://wa.me/SeuNumeroAqui?text=Quero%20sacar%20meu%20saldo%20de%20R$' + str(user.balance))

@app.route('/admin', methods=['GET', 'POST'])
def admin():
    if 'user_id' not in session or not User.query.get(session['user_id']).is_admin:
        return redirect(url_for('index'))
    if request.method == 'POST':
        if 'bet_price' in request.form:
            config = Config.query.first()
            config.bet_price = float(request.form['bet_price'])
            db.session.commit()
            flash('Preço atualizado!')
        elif 'edit_balance' in request.form:
            cpf = request.form['cpf']
            new_balance = float(request.form['new_balance'])
            user = User.query.filter_by(cpf=cpf).first()
            if user:
                user.balance = new_balance
                db.session.commit()
                flash('Saldo atualizado!')
    users = User.query.all()
    config = Config.query.first()
    return render_template('admin.html', users=users, config=config)

if __name__ == '__main__':
    app.run(debug=True)