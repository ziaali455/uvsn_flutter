"""
Vercel serverless function entry point
"""
from analyze import app

# Vercel expects a variable named 'app' or 'handler'
handler = app

