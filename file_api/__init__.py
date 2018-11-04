from flask import Flask
import os

def create_app(test_config=None):
    # create and configure the app
    app = Flask(__name__, instance_relative_config=True)

    # Health check path
    @app.route('/ping')
    def healthcheck():
        return 'pong'

    from file_api import api
    app.register_blueprint(api.bp)

    return app