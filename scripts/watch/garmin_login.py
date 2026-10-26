"""Garmin Connect login shared by the watch tools."""

from __future__ import annotations

import getpass

TOKEN_DIR = "~/.garminconnect"


def connect():
    """A logged-in Garmin client; asks for credentials only when no saved token works."""
    from garminconnect import Garmin

    try:
        api = Garmin()
        api.login(TOKEN_DIR)
        return api
    except Exception:
        pass
    print("Garmin Connect login (the token is saved in ~/.garminconnect; the password is not).")
    email = input("Email: ").strip()
    password = getpass.getpass("Password: ")
    api = Garmin(email, password, prompt_mfa=lambda: input("MFA code: ").strip())
    api.login(TOKEN_DIR)
    return api
