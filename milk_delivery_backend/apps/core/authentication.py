from rest_framework.authentication import SessionAuthentication


class CsrfExemptSessionAuthentication(SessionAuthentication):
    """
    SessionAuthentication that skips CSRF validation.
    Used for REST API endpoints where authentication is token-based or CSRF is handled at gateway.
    """
    def enforce_csrf(self, request):
        return  # Bypass CSRF enforcement
