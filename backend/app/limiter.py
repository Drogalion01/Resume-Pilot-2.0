from slowapi import Limiter
from slowapi.util import get_remote_address

# Singleton rate limiter — imported in main.py and route files
limiter = Limiter(key_func=get_remote_address)
