import os
import logging
from flask import Flask, jsonify
from error_handlers import register_error_handlers
from request_logging import register_request_logging


def create_app():
    app = Flask(__name__)
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    register_error_handlers(app)
    register_request_logging(app)
    
    @app.route('/health')
    def health_check():
        return jsonify({
            'status': 'healthy',
            'environment': os.getenv('ENVIRONMENT', 'development')
        }), 200

    @app.route('/query')
    def query():
        return jsonify({'message': 'You have just queried Bird Watcher\'s Emportium'}), 200

    return app


app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)