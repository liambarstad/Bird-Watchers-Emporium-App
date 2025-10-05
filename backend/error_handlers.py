from flask import jsonify, request
import logging

logger = logging.getLogger(__name__)

def register_error_handlers(app):
    
    @app.errorhandler(400)
    def bad_request(error):
        logger.warning(f'Bad request: {request.method} {request.path} - {error.description}')
        return jsonify({
            'error': 'Bad Request',
            'message': 'The request was invalid or cannot be served',
            'path': request.path,
            'method': request.method
        }), 400

    @app.errorhandler(404)
    def not_found(error):
        logger.info(f'Not found: {request.method} {request.path} - {error.description}')
        return jsonify({
            'error': 'Not Found',
            'message': 'The requested resource was not found',
            'path': request.path,
            'method': request.method
        }), 404

    @app.errorhandler(405)
    def method_not_allowed(error):
        logger.warning(f'Method not allowed: {request.method} {request.path} - {error.description}')
        return jsonify({
            'error': 'Method Not Allowed',
            'message': f'The method {request.method} is not allowed for this resource',
            'path': request.path,
            'method': request.method
        }), 405

    @app.errorhandler(500)
    def internal_server_error(error):
        logger.error(f'Internal server error: {request.method} {request.path} - {str(error)}')
        return jsonify({
            'error': 'Internal Server Error',
            'message': 'An unexpected error occurred on the server',
            'path': request.path,
            'method': request.method
        }), 500

    @app.errorhandler(Exception)
    def handle_unexpected_error(error):
        logger.error(f'Unexpected error: {request.method} {request.path} - {str(error)}', exc_info=True)
        return jsonify({
            'error': 'Internal Server Error',
            'message': 'An unexpected error occurred',
            'path': request.path,
            'method': request.method
        }), 500
