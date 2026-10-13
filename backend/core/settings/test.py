import os

os.environ["REDIS_URL"] = "memory://"

from .development import *

os.environ["REDIS_URL"] = "memory://"

TESTING = True
PAYMENT_METHODS = ["mock", "mercadopago", "stripe"]
PAYMENT_ALLOW_MOCK = True
PAYMENT_MOCK_AUTO_CONFIRM = True
SECRET_KEY = "django-insecure-test-key-with-more-than-thirty-two-characters-for-jwt"
PDL_DATA_ENCRYPTION_KEY = "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA="
DEBUG = False
LINEAGE_DB_ENABLED = False
# A configuração real da instalação não pode trocar o dialeto validado pela suíte.
LINEAGE_QUERY_MODULE = "l2jpremium"
# Nem os XMLs de uma instalação Journey podem alterar o catálogo de regressão Premium.
LINEAGE_ITEM_XML_DIR = str(BASE_DIR / "data" / "items")
LINEAGE_SKILL_XML_DIR = str(BASE_DIR / "data" / "skills")

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "test.sqlite3",
    }
}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "pdl-tests",
    }
}

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_BROKER_URL = "memory://"
CELERY_RESULT_BACKEND = "cache+memory://"

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

# Campos com armazenamento privado explícito escrevem em disco; cada teste que gera
# um pacote LGPD aponta PRIVATE_MEDIA_ROOT para o próprio tmp_path.
PRIVATE_MEDIA_ROOT = BASE_DIR / "test-private"

# Testes de geração habilitam explicitamente e simulam apenas o SDK externo.
DENKYNHO_LLM_ENABLED = False
