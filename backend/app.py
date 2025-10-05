import os
import logging
from flask import Flask, jsonify, request
from flask_cors import CORS
from error_handlers import register_error_handlers
from request_logging import register_request_logging

ENVIRONMENT = os.environ['ENVIRONMENT']

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def create_app():
    app = Flask(__name__)
    
    if ENVIRONMENT == 'development':
        CORS(app, origins="*")
    
    register_error_handlers(app)
    register_request_logging(app)
    
    @app.route('/health')
    def health_check():
        return jsonify({
            'status': 'healthy',
            'environment': os.getenv('ENVIRONMENT', 'development')
        }), 200

    @app.route('/query', methods=['POST'])
    def query():
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({'error': 'Message is required'}), 400
        
        user_message = data['message']
        
        return jsonify({
            'response': 'You have just queried Bird Watcher\'s Emportium',
            'user_message': user_message
        }), 200

    return app


app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)