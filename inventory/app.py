from flask import Flask, render_template, request, jsonify, redirect, url_for
import sqlite3
import os
from datetime import datetime

app = Flask(__name__)
DB_PATH = os.path.join(os.path.dirname(__file__), 'inventory.db')


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with get_db() as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                quantity REAL NOT NULL DEFAULT 0,
                unit TEXT NOT NULL DEFAULT 'יחידות',
                min_quantity REAL NOT NULL DEFAULT 1,
                location TEXT,
                notes TEXT,
                expiry_date TEXT,
                updated_at TEXT NOT NULL
            )
        ''')
        conn.commit()


@app.route('/')
def index():
    with get_db() as conn:
        items = conn.execute(
            'SELECT * FROM items ORDER BY category, name'
        ).fetchall()
        low_stock = [i for i in items if i['quantity'] <= i['min_quantity']]
        categories = sorted(set(i['category'] for i in items))
    return render_template('index.html', items=items, low_stock=low_stock, categories=categories)


@app.route('/api/items', methods=['GET'])
def get_items():
    category = request.args.get('category')
    with get_db() as conn:
        if category:
            items = conn.execute(
                'SELECT * FROM items WHERE category=? ORDER BY name', (category,)
            ).fetchall()
        else:
            items = conn.execute('SELECT * FROM items ORDER BY category, name').fetchall()
    return jsonify([dict(i) for i in items])


@app.route('/api/items', methods=['POST'])
def add_item():
    data = request.json
    now = datetime.now().strftime('%Y-%m-%d %H:%M')
    with get_db() as conn:
        conn.execute('''
            INSERT INTO items (name, category, quantity, unit, min_quantity, location, notes, expiry_date, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['name'], data['category'], float(data.get('quantity', 0)),
            data.get('unit', 'יחידות'), float(data.get('min_quantity', 1)),
            data.get('location', ''), data.get('notes', ''),
            data.get('expiry_date', ''), now
        ))
        conn.commit()
    return jsonify({'status': 'ok'})


@app.route('/api/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    data = request.json
    now = datetime.now().strftime('%Y-%m-%d %H:%M')
    with get_db() as conn:
        conn.execute('''
            UPDATE items SET name=?, category=?, quantity=?, unit=?, min_quantity=?,
            location=?, notes=?, expiry_date=?, updated_at=?
            WHERE id=?
        ''', (
            data['name'], data['category'], float(data['quantity']),
            data.get('unit', 'יחידות'), float(data.get('min_quantity', 1)),
            data.get('location', ''), data.get('notes', ''),
            data.get('expiry_date', ''), now, item_id
        ))
        conn.commit()
    return jsonify({'status': 'ok'})


@app.route('/api/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    with get_db() as conn:
        conn.execute('DELETE FROM items WHERE id=?', (item_id,))
        conn.commit()
    return jsonify({'status': 'ok'})


@app.route('/api/items/<int:item_id>/adjust', methods=['POST'])
def adjust_quantity(item_id):
    data = request.json
    delta = float(data.get('delta', 0))
    now = datetime.now().strftime('%Y-%m-%d %H:%M')
    with get_db() as conn:
        conn.execute(
            'UPDATE items SET quantity=MAX(0, quantity+?), updated_at=? WHERE id=?',
            (delta, now, item_id)
        )
        conn.commit()
        item = conn.execute('SELECT * FROM items WHERE id=?', (item_id,)).fetchone()
    return jsonify(dict(item))


if __name__ == '__main__':
    init_db()
    app.run(debug=True, port=5000)
