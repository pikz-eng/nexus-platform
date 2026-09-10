import os
from http.server import HTTPServer, BaseHTTPRequestHandler

class SimpleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        secret_path = "/vault/secrets/db-creds"
        has_secret = os.path.exists(secret_path)
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        response = f'{{"status": "running", "environment": "production", "secrets_mounted": {str(has_secret).lower()}}}\n'
        self.wfile.write(response.encode())

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), SimpleHandler)
    print("Server running on port 8080...")
    server.serve_forever()
