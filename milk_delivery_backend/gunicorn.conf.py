# Gunicorn production configuration for Railway
import os
import multiprocessing

port = os.environ.get("PORT", "8000")
bind = f"0.0.0.0:{port}"
workers = min(multiprocessing.cpu_count() * 2 + 1, 4)
threads = 4
worker_class = "gthread"
timeout = 120
keepalive = 5
max_requests = 1000
max_requests_jitter = 50

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)sµs'

# Security & Process
daemon = False
pidfile = None
umask = 0
user = None
group = None
tmp_upload_dir = None
