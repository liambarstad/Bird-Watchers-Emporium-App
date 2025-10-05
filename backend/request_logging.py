import logging
import time
from flask import request, g

logger = logging.getLogger(__name__)

def register_request_logging(app):
    
    @app.before_request
    def log_request_info():
        g.start_time = time.time()
        g.request_id = f'{int(time.time())}-{id(request)}'
        
        # Log request details
        logger.info(
            f'REQUEST [{g.request_id}] {request.method} {request.path} '
            f'- IP: {request.remote_addr} '
            f'- User-Agent: {request.headers.get('User-Agent', 'Unknown')}'
        )
        
        # Log request body for POST/PUT requests (be careful with sensitive data)
        if request.method in ['POST', 'PUT', 'PATCH'] and request.is_json:
            content_length = request.content_length or 0
            logger.info(f'REQUEST [{g.request_id}] Content-Length: {content_length} bytes')
    
    @app.after_request
    def log_response_info(response):
        if hasattr(g, 'start_time') and hasattr(g, 'request_id'):
            duration = (time.time() - g.start_time) * 1000  # Convert to milliseconds
            
            # Log response details
            logger.info(
                f'RESPONSE [{g.request_id}] {response.status_code} '
                f'- Duration: {duration:.2f}ms '
                f'- Content-Length: {response.content_length or 0} bytes'
            )
            
            # Add custom headers for debugging
            response.headers['X-Request-ID'] = g.request_id
            response.headers['X-Response-Time'] = f'{duration:.2f}ms'
        
        return response
    
    @app.before_request
    def log_request_headers():
        if logger.isEnabledFor(logging.DEBUG):
            important_headers = [
                'Content-Type', 'Accept', 'Authorization', 
                'X-Forwarded-For', 'X-Real-IP', 'Host'
            ]
            logged_headers = {
                header: request.headers.get(header, 'Not set')
                for header in important_headers
            }
            logger.debug(f'Headers: {logged_headers}')
