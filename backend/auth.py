import json
import os
from google.auth.transport.requests import Request
from google.oauth2 import service_account
import time

class ServiceAccountAuth:
    def __init__(self, credentials_path=None, project_id=None):
        self.credentials_path = 'reviewtext-ad5c6-vertex-ai.json'
        self.project_id = project_id or os.getenv('GOOGLE_CLOUD_PROJECT_ID')
        self.credentials = None
        self.token = None
        self.token_expiry = None
        
        if not self.credentials_path:
            raise ValueError("Service account credentials path not provided")
        
        self._load_credentials()
    
    def _load_credentials(self):
        try:
            with open(self.credentials_path, 'r') as f:
                credentials_info = json.load(f)
            
            scopes = ['https://www.googleapis.com/auth/cloud-platform']
            self.credentials = service_account.Credentials.from_service_account_info(
                credentials_info, scopes=scopes
            )
        except FileNotFoundError:
            raise FileNotFoundError(f"Service account file not found: {self.credentials_path}")
        except json.JSONDecodeError:
            raise ValueError(f"Invalid JSON in service account file: {self.credentials_path}")
    
    def get_access_token(self):
        if self.token and self.token_expiry and time.time() < self.token_expiry:
            return self.token
        
        request = Request()
        self.credentials.refresh(request)
        self.token = self.credentials.token
        self.token_expiry = self.credentials.expiry.timestamp() if self.credentials.expiry else None
        
        return self.token
    
    def is_token_valid(self):
        return self.token and self.token_expiry and time.time() < self.token_expiry - 300  # 5 min buffer