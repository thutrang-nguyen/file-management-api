from flask import Flask, abort, make_response, jsonify
import werkzeug.exceptions as exceptions
import os

def create_app(test_config=None):
    # create and configure the app
    app = Flask(__name__, instance_relative_config=True)

    # Health check path
    @app.route('/ping')
    def healthcheck():
        return 'pong'

    @app.errorhandler(404)
    def not_found(e):
        return make_response(jsonify( { 'error': 'Not found' } ), 404)

    @app.errorhandler(500)
    def server_error(e):
        return make_response(jsonify( { 'error': 'Server error' } ), 500)

    from file_api import api
    app.register_blueprint(api.bp)

    return app