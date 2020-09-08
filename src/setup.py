from setuptools import find_packages, setup

setup(
    name        = "todobackend",
    version     = "0.1.0",
    description = "Todobackend Django REST service",
    packages    = find_packages(),
    include_package_data = True,
    scripts     = ["manage.py"],
    install_requires = [
        "Django>=1.9,<=2.2.13",
        "django-cors-headers>=1.1.0",
        "djangorestframework>=3.3.0",
        "MySQL-python>=1.2.5",
        "uwsgi>=2.0"
    ],
    extras_require = {
        "test": [
            "colorama>=0.4.1",
            "coverage>=4.5.2",
            "django-nose>=1.4.6",
            "nose>=1.3.7",
            "pinocchio>=0.4.2"
        ]
    }
)
