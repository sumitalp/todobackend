import os
from base import *

# Database
# https://docs.djangoproject.com/en/1.9/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('MYSQL_TODO_DATABASE', 'todobackend'),
        'USER': os.environ.get('MYSQL_USER', 'root'),
        'PASSWORD': os.environ.get('MYSQL_PASSWORD', 'root1234'),
        'HOST': os.environ.get('MYSQL_HOST', 'localhost'),
        'PORT': os.environ.get('MYSQL_PORT', '3306'),
    }
}

# Installed Apps
INSTALLED_APPS += ('django_nose',)
TEST_RUNNER = 'django_nose.NoseTestSuiteRunner'
TEST_OUTPUT_DIR = os.environ.get('TEST_OUTPUT_DIR', '.')
NOSE_ARGS = [
    '--verbosity=2',
    '--nologcapture',
    '--with-coverage',
    '--cover-package=todo', # For multiple apps - separate them with ',' e.g. todo, corsheaders
    '--with-spec',
    '--spec-color',
    '--with-xunit',
    '--xunit-file={}/unittests.xml'.format(TEST_OUTPUT_DIR),
    '--cover-xml',
    '--cover-xml-file={}/coverage.xml'.format(TEST_OUTPUT_DIR)
]