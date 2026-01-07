from flask import Flask, jsonify

# THIS IS THE CRITICAL LINE. The variable MUST be named 'app'.
app = Flask(__name__)

@app.route('/api/data')
def get_data():
    """
    This is a simple API endpoint that returns a JSON object.
    """
    data = {
        'message': 'Hello from the Backend!',
        'status': 'success'
    }
    return jsonify(data)

if __name__ == '__main__':
    # This part is for local testing; Gunicorn does not use it.
    app.run(host='0.0.0.0', port=5000)
